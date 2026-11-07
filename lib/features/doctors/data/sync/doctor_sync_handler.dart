import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/doctor_remote_data_source.dart';

/// DoctorSyncHandler manages payload preparation, remote dispatch, local Hive re-keying,
/// and cross-domain Consultation reference propagation for Doctors (D1 - D5).
class DoctorSyncHandler {
  DoctorSyncHandler._();

  /// Converts a raw local Doctor JSON map into a canonical server-compliant payload (D2 / D4).
  static Map<String, dynamic> toServerPayload(
    Map<String, dynamic> raw, {
    int? serverProfileId,
  }) {
    final rawProf = raw['profile_id'] ?? raw['profileId'];
    final resolvedProfileId =
        serverProfileId ??
        IdUtils.toServerIntId(rawProf) ??
        int.tryParse(IdUtils.unprefix(rawProf?.toString())) ??
        rawProf;

    return <String, dynamic>{
      'profile_id': resolvedProfileId,
      'name': raw['name'] ?? '',
      if (raw['specialty'] != null &&
          raw['specialty'].toString().isNotEmpty)
        'specialty': raw['specialty'],
      if (raw['phone'] != null && raw['phone'].toString().isNotEmpty)
        'phone': raw['phone'],
      if (raw['email'] != null && raw['email'].toString().isNotEmpty)
        'email': raw['email'],
      if (raw['hospital_name'] != null &&
          raw['hospital_name'].toString().isNotEmpty)
        'hospital_name': raw['hospital_name'],
      if (raw['client_uuid'] != null)
        'client_uuid': raw['client_uuid'],
    };
  }

  /// Handles synchronization of a single doctor mutation with the remote API,
  /// updates local Hive storage upon successful response, and propagates the newly
  /// resolved server ID to any pending consultations in the sync queue.
  static Future<bool> process({
    required SyncQueueItem item,
    required DoctorRemoteDataSource remoteDataSource,
    required Box userBox,
    required Box profileBox,
    required Box syncQueueBox,
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
                  ? resolveDeleteServerId('doctor_', payload)
                  : _resolveDeleteServerIdFallback('doctor_', payload, userBox));
        if (serverId != null) {
          await remoteDataSource.deleteDoctor(serverId.toString());
        } else if (payload['_needs_server_id'] == true) {
          // Reached the server but its id is not resolvable locally yet ->
          // defer without consuming the retry budget (F2 / P2-F5).
          item.status = 'deferred';
          return false;
        }
        await userBox.delete('doctor_$cleanId');
        await userBox.delete(localId);
        return true;
      }

      // 2. Resolve Profile Server ID from Hive
      final rawProfileId = payload['profile_id'] ?? payload['profileId'];
      final cleanProfileId = IdUtils.resolveServerProfileId(
        profileBox: profileBox,
        profileId: rawProfileId?.toString(),
      );
      if (cleanProfileId == null) {
        debugPrint(
          '[DoctorSyncHandler] Cannot sync Doctor: profile_id ($rawProfileId) not resolved to server ID yet. Deferring sync.',
        );
        // Dependency not ready -> defer without consuming the retry budget (F2).
        item.status = 'deferred';
        return false;
      }

      // 3. Construct API payload
      final apiPayload = toServerPayload(
        payload,
        serverProfileId: cleanProfileId,
      );

      // 4. Dispatch API call (D4 update or D2 add)
      Map<String, dynamic> res;
      if (operation == 'update' && isServerNumericId) {
        res = await remoteDataSource.updateDoctor(serverIntId.toString(), apiPayload);
      } else {
        res = await remoteDataSource.addDoctor(apiPayload);
      }

      // 5. Server ID Reconciliation and Consultation Queue Reference Propagation
      final serverId = res['id']?.toString() ?? '';
      if (serverId.isNotEmpty) {
        final oldId = payload['id']?.toString() ?? '';
        final oldKey = 'doctor_${IdUtils.unprefix(oldId)}';
        final newKey = 'doctor_$serverId';

        final localRaw = userBox.get(oldKey) ?? userBox.get(oldId);
        String? localProfId;
        if (localRaw is Map) {
          localProfId = (localRaw['profile_id'] ?? localRaw['profileId'])
              ?.toString();
        }

        if (oldKey != newKey) {
          await userBox.delete(oldKey);
          await userBox.delete(oldId);
        }
        final updatedPayload = Map<String, dynamic>.from(payload);
        updatedPayload['id'] = newKey;
        if (localProfId != null && localProfId.isNotEmpty) {
          updatedPayload['profile_id'] = localProfId;
        }
        await userBox.put(newKey, updatedPayload);

        // Propagate newly resolved server ID to all dependent consultations in syncQueueBox
        final resolvedServerIntId = int.tryParse(serverId);
        if (resolvedServerIntId != null) {
          for (final entry in syncQueueBox.toMap().entries) {
            final val = entry.value;
            final entity = val['entity']?.toString();
            if (entity == 'consultations' || entity == 'consultation') {
              final cPayload = val['payload'];
              if (cPayload is Map) {
                final cDocId =
                    cPayload['doctor_id']?.toString() ??
                    cPayload['doctorId']?.toString();
                final cDocName =
                    cPayload['doctor_name']?.toString() ??
                    cPayload['doctorName']?.toString();
                final docName = payload['name']?.toString();
                if ((cDocId != null &&
                        (cDocId == oldId ||
                            cDocId == oldKey ||
                            IdUtils.matches(cDocId, oldId))) ||
                    (docName != null &&
                        cDocName != null &&
                        cDocName.trim().toLowerCase() ==
                            docName.trim().toLowerCase())) {
                  final updatedConsultPayload = Map<String, dynamic>.from(
                    cPayload,
                  );
                  updatedConsultPayload['doctor_id'] = resolvedServerIntId;
                  final updatedItem = Map<String, dynamic>.from(val);
                  updatedItem['payload'] = updatedConsultPayload;
                  await syncQueueBox.put(entry.key, updatedItem);
                }
              }
            }
          }
        }
      }
      return true;
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      debugPrint(
        '[DoctorSyncHandler] Doctor sync DioException: HTTP $statusCode - ${dioErr.message}',
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
      debugPrint('[DoctorSyncHandler] Error processing doctor sync: $err');
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
