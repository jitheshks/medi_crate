import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/medicine_remote_data_source.dart';
import '../models/medicine_model.dart';

/// MedicineSyncHandler manages serialization, API dispatch, linked consultation
/// resolution, and Hive ID reconciliation for Medicines (M1 - M5).
class MedicineSyncHandler {
  MedicineSyncHandler._();

  /// Converts a raw local Medicine JSON map into a canonical server-compliant payload (M2/M4).
  static Map<String, dynamic> toServerPayload(
    Map<String, dynamic> localPayload, {
    int? serverProfileId,
  }) {
    final model = MedicineModel.fromJson(localPayload);
    return model.toServerMetadataJson(serverProfileId: serverProfileId);
  }

  /// Handles synchronization of a single medicine mutation with the remote API
  /// and updates local Hive storage upon successful response.
  static Future<bool> process({
    required SyncQueueItem item,
    required MedicineRemoteDataSource remoteDataSource,
    required Box userBox,
    required Box profileBox,
    int? Function(String prefix, Map<String, dynamic> payload)?
    resolveDeleteServerId,
  }) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final localId = payload['id']?.toString() ?? item.id;
    final cleanId = IdUtils.unprefix(localId);
    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isServerNumericId = serverIntId != null;

    try {
      // 1. Handle DELETE operation
      if (operation == 'delete') {
        final serverId = isServerNumericId
            ? serverIntId
            : (resolveDeleteServerId != null
                  ? resolveDeleteServerId('medicine_', payload)
                  : _resolveDeleteServerIdFallback(
                      'medicine_',
                      payload,
                      userBox,
                    ));
        if (serverId != null) {
          await remoteDataSource.deleteMedicine(serverId.toString());
        } else if (payload['_needs_server_id'] == true) {
          item.status = 'deferred';
          return false;
        }
        await userBox.delete('medicine_$cleanId');
        await userBox.delete(localId);
        return true;
      }

      // Resolve Profile Server ID from Hive
      var rawProfileId = payload['profile_id'] ?? payload['profileId'];
      if (rawProfileId == null) {
        final existing =
            userBox.get(localId) ?? userBox.get('medicine_$cleanId');
        if (existing is Map) {
          rawProfileId = existing['profile_id'] ?? existing['profileId'];
        }
      }
      final cleanProfileId = IdUtils.resolveServerProfileId(
        profileBox: profileBox,
        profileId: rawProfileId?.toString(),
      );
      if (cleanProfileId == null) {
        debugPrint(
          '[MedicineSyncHandler] Cannot sync Medicine: profile_id ($rawProfileId) not resolved to server ID yet. Deferring sync.',
        );
        // Dependency not ready -> defer without consuming the retry budget (F2).
        item.status = 'deferred';
        return false;
      }
      payload['profile_id'] = cleanProfileId;

      // 2. Resolve Consultation Server ID if locally linked
      final rawConsultId =
          payload['linked_consultation_id'] ??
          payload['consultation_id'] ??
          payload['linkedConsultationId'];
      if (rawConsultId != null) {
        var resolvedConsultId = IdUtils.toServerIntId(rawConsultId);
        if (resolvedConsultId == null) {
          final consultKey =
              'consultation_${IdUtils.unprefix(rawConsultId.toString())}';
          final consultData =
              userBox.get(consultKey) ?? userBox.get(rawConsultId.toString());
          if (consultData is Map) {
            resolvedConsultId = IdUtils.toServerIntId(consultData['id']);
          }
        }
        if (resolvedConsultId != null) {
          payload['linked_consultation_id'] = resolvedConsultId;
        }
      }

      // 3. Ensure client_uuid is preserved
      final oldKey = localId.startsWith('medicine_')
          ? localId
          : 'medicine_$localId';
      final existingLocal = userBox.get(oldKey) ?? userBox.get(localId);
      String? existingUuid;
      if (existingLocal is Map) {
        existingUuid =
            existingLocal['client_uuid']?.toString() ??
            existingLocal['clientUuid']?.toString();
      }

      final clientUuid =
          payload['client_uuid']?.toString() ??
          payload['clientUuid']?.toString() ??
          existingUuid ??
          UuidUtils.generateV4();
      payload['client_uuid'] = clientUuid;

      // 4. Construct server payload
      final model = MedicineModel.fromJson(payload);
      final apiPayload = model.toServerMetadataJson();

      Map<String, dynamic> responseData;

      // 5. Dispatch API call (M4 update or M2 add)
      if (operation == 'update' && isServerNumericId) {
        responseData = await remoteDataSource.updateMedicine(
          serverIntId.toString(),
          apiPayload,
        );
      } else {
        responseData = await remoteDataSource.addMedicine(apiPayload);
      }

      // 6. Server ID Reconciliation
      final serverId = responseData['id']?.toString() ?? '';
      if (serverId.isNotEmpty) {
        final localRaw = userBox.get(oldKey) ?? userBox.get(localId);
        MedicineModel? localModel;
        if (localRaw is Map) {
          localModel = MedicineModel.fromJson(
            Map<String, dynamic>.from(localRaw),
          );
        }
        final serverModel = MedicineModel.fromJson(responseData);
        final rawProfId = payload['profile_id'] ?? payload['profileId'];
        final synchronized = serverModel.copyWith(
          id: 'medicine_$serverId',
          profileId:
              localModel?.profileId ??
              rawProfId?.toString() ??
              serverModel.profileId,
          clientUuid: clientUuid,
        );

        if (oldKey != 'medicine_$serverId') {
          await userBox.delete(oldKey);
          await userBox.delete(localId);
        }
        await userBox.put('medicine_$serverId', synchronized.toJson());
      }

      return true;
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      debugPrint(
        '[MedicineSyncHandler] Medicine sync DioException: HTTP $statusCode - ${dioErr.message}',
      );

      // Classify error:
      // 400, 404, 422 are permanent client/validation errors (dead-letter)
      if (statusCode != null &&
          (statusCode == 400 || statusCode == 404 || statusCode == 422)) {
        item.status = 'failed';
        item.retryCount = 99; // Mark dead-letter; do not retry automatically
        item.errorMessage =
            'Validation/Client error ($statusCode): ${dioErr.response?.data}';
      } else if (statusCode == 401) {
        // 401 Unauthorized: Recoverable authentication failure
        item.status = 'auth_required';
        item.errorMessage =
            'Authentication required ($statusCode): Session unauthenticated';
      } else if (statusCode == 403) {
        // 403 Forbidden: Authorization issue
        item.status = 'failed';
        item.errorMessage = 'Forbidden ($statusCode): ${dioErr.response?.data}';
      } else {
        item.errorMessage = 'Network error ($statusCode): ${dioErr.message}';
      }
      return false;
    } catch (err) {
      debugPrint('[MedicineSyncHandler] Error processing medicine sync: $err');
      item.errorMessage = err.toString();
      return false;
    }
  }

  /// Fallback resolver for delete server ID if not provided by caller.
  static int? _resolveDeleteServerIdFallback(
    String prefix,
    Map<String, dynamic> payload,
    Box userBox,
  ) {
    final direct = IdUtils.toServerIntId(payload['id']);
    if (direct != null) return direct;
    final uuid = (payload['client_uuid'] ?? payload['clientUuid'])
        ?.toString()
        .trim();
    if (uuid == null || uuid.isEmpty) return null;
    for (final key in userBox.keys) {
      if (!key.toString().startsWith(prefix)) continue;
      final raw = userBox.get(key);
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final cu = (m['client_uuid'] ?? m['clientUuid'])?.toString().trim();
      if (cu != uuid) continue;
      return IdUtils.toServerIntId(m['id']) ??
          IdUtils.toServerIntId(key.toString());
    }
    return null;
  }
}
