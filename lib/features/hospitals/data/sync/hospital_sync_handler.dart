import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/hospital_remote_data_source.dart';

/// HospitalSyncHandler manages payload preparation, remote dispatch, local Hive re-keying,
/// comprehensive userBox cross-domain backfill (Doctors, Consultations, Appointments, Reports),
/// and syncQueueBox reference propagation for Hospitals (H1 - H5).
class HospitalSyncHandler {
  HospitalSyncHandler._();

  /// Converts a raw local Hospital JSON map into a canonical server-compliant payload (H2 / H4).
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
      if (raw['type'] != null && raw['type'].toString().isNotEmpty)
        'type': raw['type'],
      if (raw['address'] != null && raw['address'].toString().isNotEmpty)
        'address': raw['address'],
      if (raw['phone'] != null && raw['phone'].toString().isNotEmpty)
        'phone': raw['phone'],
      if (raw['email'] != null && raw['email'].toString().isNotEmpty)
        'email': raw['email'],
      if (raw['city'] != null && raw['city'].toString().isNotEmpty)
        'city': raw['city'],
      if (raw['client_uuid'] != null) 'client_uuid': raw['client_uuid'],
    };
  }

  /// Handles synchronization of a single hospital mutation with the remote API,
  /// updates local Hive storage upon successful response, executes 4-way cross-domain
  /// userBox backfill, and propagates the newly resolved server ID to any pending
  /// consultations and doctors in the sync queue.
  static Future<bool> process({
    required SyncQueueItem item,
    required HospitalRemoteDataSource remoteDataSource,
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
                  ? resolveDeleteServerId('hospital_', payload)
                  : _resolveDeleteServerIdFallback(
                      'hospital_',
                      payload,
                      userBox,
                    ));
        if (serverId != null) {
          await remoteDataSource.deleteHospital(serverId.toString());
        } else if (payload['_needs_server_id'] == true) {
          // Reached the server but its id is not resolvable locally yet ->
          // defer without consuming the retry budget (F2 / P2-F5).
          item.status = 'deferred';
          return false;
        }
        await userBox.delete('hospital_$cleanId');
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
          '[HospitalSyncHandler] Cannot sync Hospital: profile_id ($rawProfileId) not resolved to server ID yet. Deferring sync.',
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

      // 4. Dispatch API call (H4 update or H2 add)
      Map<String, dynamic> res;
      if (operation == 'update' && isServerNumericId) {
        res = await remoteDataSource.updateHospital(
          serverIntId.toString(),
          apiPayload,
        );
      } else {
        res = await remoteDataSource.addHospital(apiPayload);
      }

      // 5. Server ID Reconciliation & Cross-Domain Propagation
      final serverId = res['id']?.toString() ?? '';
      if (serverId.isNotEmpty) {
        final oldId = payload['id']?.toString() ?? '';
        final oldKey = 'hospital_${IdUtils.unprefix(oldId)}';
        final newKey = 'hospital_$serverId';

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

        // Propagate newly resolved server ID to all dependent records in userBox
        final resolvedServerIntId = int.tryParse(serverId);
        final resolvedHospId = resolvedServerIntId ?? newKey;

        for (final k in userBox.keys) {
          final kStr = k.toString();
          if (kStr.startsWith('doctor_')) {
            final dVal = userBox.get(k);
            if (dVal is Map) {
              final dMap = Map<String, dynamic>.from(dVal);
              final hIds = dMap['hospital_ids'] ?? dMap['hospitalIds'];
              if (hIds is List) {
                bool docChanged = false;
                final updatedHIds = hIds.map((h) {
                  final hStr = h.toString();
                  if (hStr == oldId ||
                      hStr == oldKey ||
                      IdUtils.matches(hStr, oldId)) {
                    docChanged = true;
                    return newKey;
                  }
                  return hStr;
                }).toList();
                if (docChanged) {
                  dMap['hospital_ids'] = updatedHIds;
                  await userBox.put(k, dMap);
                }
              }
            }
          } else if (kStr.startsWith('consultation_') ||
              kStr.startsWith('con_')) {
            final cVal = userBox.get(k);
            if (cVal is Map) {
              final cMap = Map<String, dynamic>.from(cVal);
              final cHospId =
                  cMap['hospital_id']?.toString() ??
                  cMap['hospitalId']?.toString();
              if (cHospId != null &&
                  (cHospId == oldId ||
                      cHospId == oldKey ||
                      IdUtils.matches(cHospId, oldId))) {
                cMap['hospital_id'] = resolvedHospId;
                await userBox.put(k, cMap);
              }
            }
          } else if (kStr.startsWith('appointment_') ||
              kStr.startsWith('apt_')) {
            final aVal = userBox.get(k);
            if (aVal is Map) {
              final aMap = Map<String, dynamic>.from(aVal);
              final aHospId =
                  aMap['hospital_id']?.toString() ??
                  aMap['hospitalId']?.toString();
              if (aHospId != null &&
                  (aHospId == oldId ||
                      aHospId == oldKey ||
                      IdUtils.matches(aHospId, oldId))) {
                aMap['hospital_id'] = resolvedHospId;
                await userBox.put(k, aMap);
              }
            }
          } else if (kStr.startsWith('report_') || kStr.startsWith('rep_')) {
            final rVal = userBox.get(k);
            if (rVal is Map) {
              final rMap = Map<String, dynamic>.from(rVal);
              final rHospId =
                  rMap['hospital_id']?.toString() ??
                  rMap['hospitalId']?.toString();
              if (rHospId != null &&
                  (rHospId == oldId ||
                      rHospId == oldKey ||
                      IdUtils.matches(rHospId, oldId))) {
                rMap['hospital_id'] = resolvedHospId;
                await userBox.put(k, rMap);
              }
            }
          }
        }

        // Propagate newly resolved server ID to all dependent items in syncQueueBox
        if (resolvedServerIntId != null) {
          for (final entry in syncQueueBox.toMap().entries) {
            final val = entry.value;
            final entity = val['entity']?.toString().toLowerCase();
            final itemPayload = val['payload'];

            if (itemPayload is Map) {
              if (entity == 'consultations' || entity == 'consultation') {
                final cHospId =
                    itemPayload['hospital_id']?.toString() ??
                    itemPayload['hospitalId']?.toString();
                final cHospName =
                    itemPayload['hospital_name']?.toString() ??
                    itemPayload['hospitalName']?.toString();
                final hospName = payload['name']?.toString();
                if ((cHospId != null &&
                        (cHospId == oldId ||
                            cHospId == oldKey ||
                            IdUtils.matches(cHospId, oldId))) ||
                    (hospName != null &&
                        cHospName != null &&
                        cHospName.trim().toLowerCase() ==
                            hospName.trim().toLowerCase())) {
                  final updatedConsultPayload = Map<String, dynamic>.from(
                    itemPayload,
                  );
                  updatedConsultPayload['hospital_id'] = resolvedServerIntId;
                  final updatedItem = Map<String, dynamic>.from(val);
                  updatedItem['payload'] = updatedConsultPayload;
                  await syncQueueBox.put(entry.key, updatedItem);
                }
              } else if (entity == 'doctors' || entity == 'doctor') {
                final hIds =
                    itemPayload['hospital_ids'] ?? itemPayload['hospitalIds'];
                if (hIds is List) {
                  bool docChanged = false;
                  final updatedHIds = hIds.map((h) {
                    final hStr = h.toString();
                    if (hStr == oldId ||
                        hStr == oldKey ||
                        IdUtils.matches(hStr, oldId)) {
                      docChanged = true;
                      return resolvedServerIntId;
                    }
                    return h;
                  }).toList();
                  if (docChanged) {
                    final updatedDocPayload = Map<String, dynamic>.from(
                      itemPayload,
                    );
                    updatedDocPayload['hospital_ids'] = updatedHIds;
                    final updatedItem = Map<String, dynamic>.from(val);
                    updatedItem['payload'] = updatedDocPayload;
                    await syncQueueBox.put(entry.key, updatedItem);
                  }
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
        '[HospitalSyncHandler] Hospital sync DioException: HTTP $statusCode - ${dioErr.message}',
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
      debugPrint('[HospitalSyncHandler] Error processing hospital sync: $err');
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
