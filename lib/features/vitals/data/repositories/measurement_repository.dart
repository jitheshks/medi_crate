import 'dart:async';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_profile_query_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/pulled_record_comparison.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/supabase_vitals_remote_data_source.dart';
import '../models/measurement_model.dart';

/// MeasurementRepository manages profile-scoped body vitals and metrics with offline-first synchronization.
class MeasurementRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final SupabaseVitalsRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal: invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  MeasurementRepository({
    required this.hiveService,
    this.syncService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    this.onPullMerged,
    dynamic remoteDataSource,
  });

  /// Normalize local measurement storage key.
  String _normalizeId(String rawId) {
    if (rawId.startsWith('measurement_')) return rawId;
    return 'measurement_$rawId';
  }

  String? _resolveCurrentUserId([String? explicitOwnerUserId]) {
    if (explicitOwnerUserId != null && explicitOwnerUserId.trim().isNotEmpty) {
      return explicitOwnerUserId.trim();
    }
    try {
      if (SupabaseConfig.isInitialized) {
        final sessionUid = SupabaseConfig.client.auth.currentUser?.id;
        if (sessionUid != null && sessionUid.trim().isNotEmpty) {
          return sessionUid.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String? _resolveProfileUuid(String profileId, String ownerUserId) {
    final clean = IdUtils.unprefix(profileId).trim();
    try {
      final box = hiveService.profileBox;
      final raw =
          box.get(profileId) ?? box.get(clean) ?? box.get('prof_$clean');
      Map? direct;
      if (raw is Map) {
        direct = raw;
      } else {
        for (final val in box.values) {
          final pId =
              (val['profile_id'] ?? val['profileId'] ?? val['id'])?.toString();
          if (pId != null &&
              (IdUtils.matches(pId, profileId) || IdUtils.matches(pId, clean))) {
            direct = val;
            break;
          }
        }
      }
      if (direct != null) {
        final profOwner = (direct['owner_user_id'] ??
                direct['ownerUserId'] ??
                direct['user_id'])
            ?.toString();
        if (profOwner != null &&
            profOwner.isNotEmpty &&
            !IdUtils.matches(profOwner, ownerUserId)) {
          return null;
        }

        final id =
            (direct['profile_id'] ?? direct['profileId'] ?? direct['id'])?.toString();
        if (id != null && UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
          return IdUtils.unprefix(id).trim();
        }
        final cUuid =
            (direct['client_uuid'] ?? direct['clientUuid'])?.toString();
        if (cUuid != null && UuidUtils.isValidUuid(cUuid)) {
          return cUuid.trim();
        }
      }
    } catch (_) {}

    if (UuidUtils.isValidUuid(clean)) return clean;
    return null;
  }

  Future<void> _cleanupSyncQueue(
    String key,
    String? rawId,
    String? clientUuid,
  ) async {
    try {
      final syncBox = hiveService.syncQueueBox;
      final keysToDelete = <dynamic>[];
      for (final entry in syncBox.toMap().entries) {
        final val = entry.value;
        final entity = val['entity']?.toString().toLowerCase();
        if (entity == 'measurement' ||
            entity == 'measurements' ||
            entity == 'vital' ||
            entity == 'vitals') {
          final p = val['payload'];
          if (p is Map) {
            final pUuid =
                p['client_uuid']?.toString() ?? p['clientUuid']?.toString();
            final pId = p['id']?.toString();
            if ((clientUuid != null &&
                    clientUuid.isNotEmpty &&
                    pUuid == clientUuid) ||
                (pId != null &&
                    (pId == key ||
                        pId == rawId ||
                        pId == IdUtils.unprefix(key) ||
                        (rawId != null && pId == IdUtils.unprefix(rawId))))) {
              keysToDelete.add(entry.key);
            }
          }
        }
      }
      for (final k in keysToDelete) {
        await syncBox.delete(k);
      }
    } catch (_) {}
  }

  /// Fetch raw measurements map for a specific profile (backwards compatible).
  Future<List<Map<String, dynamic>>> getMeasurements(String profileId) async {
    return HiveProfileQueryHelper.getRecordsForProfile(
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      keyPrefix: 'measurement_',
      profileId: profileId,
    );
  }

  /// Fetch typed MeasurementModel instances for a specific profile immediately from local Hive cache,
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<MeasurementModel>> getMeasurementModels(
    String profileId, {
    String? explicitOwnerUserId,
  }) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (supabaseRemoteDataSource != null) {
      unawaited(
        pullMeasurements(profileId, explicitOwnerUserId: explicitOwnerUserId),
      );
    }

    // 2. Return local Hive records immediately
    final rawList = await getMeasurements(profileId);
    final models =
        rawList.map((map) => MeasurementModel.fromMap(map)).toList();
    models.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return models;
  }

  /// Performs background pull-sync for measurements belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullMeasurements(
    String profileId, {
    String? explicitOwnerUserId,
  }) {
    if (supabaseRemoteDataSource == null) {
      return Future.value();
    }
    final existing = _inFlightPulls[profileId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullMeasurements(
      profileId,
      explicitOwnerUserId: explicitOwnerUserId,
    );
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullMeasurements(
    String profileId, {
    String? explicitOwnerUserId,
  }) async {
    try {
      if (supabaseRemoteDataSource != null) {
        final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
        if (ownerUserId == null || ownerUserId.isEmpty) return;

        final profileUuid = _resolveProfileUuid(profileId, ownerUserId);
        if (profileUuid == null || profileUuid.isEmpty) return;

        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (!isOnline) return;

        final remoteList = await supabaseRemoteDataSource!.fetchMeasurements(
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );

        if (remoteList.isNotEmpty) {
          final box = hiveService.userBox;
          var pulledChanged = false;
          for (final model in remoteList) {
            final key = _normalizeId(model.id);

            // Guard against overwriting pending local mutations (I2-C2)
            if (PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'measurement',
              profileId: profileId,
              remoteId: key,
              clientUuid: model.clientUuid,
            )) {
              continue;
            }

            final existingRaw = box.get(key) ?? box.get(model.id);
            String? existingUuid;
            if (existingRaw is Map) {
              existingUuid =
                  existingRaw['client_uuid']?.toString() ??
                  existingRaw['clientUuid']?.toString();
            }

            final merged = model.copyWith(
              id: key,
              profileId: profileId,
              clientUuid: existingUuid ?? model.clientUuid,
            );
            final encoded = merged.toMap();
            if (pulledRecordChanged(box.get(key), encoded)) pulledChanged = true;
            await box.put(key, encoded);
          }

          if (pulledChanged) {
            try {
              onPullMerged?.call();
            } catch (_) {}
          }
        }
        return;
      }
    } catch (_) {
      // Fallback to local cache on network or parsing failure
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Get single measurement by ID with strict profile ownership validation.
  Future<MeasurementModel?> getMeasurementById(
    String profileId,
    String measurementId, {
    String? explicitOwnerUserId,
  }) async {
    final key = _normalizeId(measurementId);
    final box = hiveService.userBox;
    var val =
        box.get(key) ??
        box.get(measurementId) ??
        box.get(IdUtils.unprefix(measurementId));

    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return MeasurementModel.fromMap(map);
      }
    }

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;
      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            final remoteModel =
                await supabaseRemoteDataSource!.getMeasurementById(
              measurementId: IdUtils.unprefix(measurementId),
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            if (remoteModel != null) {
              final remoteKey = _normalizeId(remoteModel.id);
              if (!PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'measurement',
                profileId: profileId,
                remoteId: remoteKey,
                clientUuid: remoteModel.clientUuid,
              )) {
                await box.put(
                  remoteKey,
                  remoteModel.copyWith(id: remoteKey).toMap(),
                );
                return remoteModel;
              }
            }
          } catch (_) {}
        }
      }
      return null;
    }

    final rawList = await getMeasurements(profileId);
    final models =
        rawList.map((map) => MeasurementModel.fromMap(map)).toList();
    try {
      return models.firstWhere(
        (m) => IdUtils.matches(m.id, measurementId) || m.id == key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Save raw measurement Map into Hive storage and Sync Queue.
  Future<Map<String, dynamic>> saveMeasurement(
    String profileId,
    Map<String, dynamic> data, {
    String? explicitOwnerUserId,
  }) async {
    final rawId = data['id']?.toString() ?? '';
    final id = rawId.isEmpty
        ? 'measurement_${DateTime.now().microsecondsSinceEpoch}_${data['type'] ?? 'metric'}'
        : _normalizeId(rawId);

    final box = hiveService.userBox;
    final isNew =
        rawId.isEmpty || (!box.containsKey(id) && !box.containsKey(rawId));

    final payload = Map<String, dynamic>.from(data);
    payload['id'] = id;
    payload['profile_id'] = profileId;

    final existingRaw = box.get(id) ?? box.get(rawId);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    final clientUuid =
        payload['client_uuid']?.toString() ??
        payload['clientUuid']?.toString() ??
        existingUuid ??
        (isNew ? UuidUtils.generateV4() : null);

    if (clientUuid != null && clientUuid.isNotEmpty) {
      payload['client_uuid'] = clientUuid;
    }

    if (payload['created_at'] == null) {
      payload['created_at'] = DateTime.now().toIso8601String();
    }

    await box.put(id, payload);

    if (supabaseRemoteDataSource == null) {
      final isNumericServerId =
          IdUtils.toServerIntId(IdUtils.unprefix(id)) != null;

      await syncService?.addToQueue(
        SyncQueueItem(
          id: 'sync_vital_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'measurement',
          operation: isNumericServerId ? 'update' : 'create',
          payload: payload,
        ),
      );
    }

    return payload;
  }

  /// Save a MeasurementModel into Hive storage, Sync Queue, and synchronize with remote API when online.
  Future<MeasurementModel> saveMeasurementModel(
    MeasurementModel model, {
    String? explicitOwnerUserId,
  }) async {
    final rawId = model.id;
    final cleanId = IdUtils.unprefix(rawId).trim();
    final isNew = rawId.isEmpty || rawId.startsWith('temp_');

    final localKey = rawId.isNotEmpty
        ? _normalizeId(rawId)
        : 'measurement_${DateTime.now().microsecondsSinceEpoch}_${model.type}';

    final box = hiveService.userBox;
    final existingRaw =
        box.get(localKey) ??
        box.get(rawId) ??
        (cleanId.isNotEmpty ? box.get(cleanId) : null);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    final clientUuid =
        (model.clientUuid != null && model.clientUuid!.trim().isNotEmpty)
            ? model.clientUuid!.trim()
            : (existingUuid ?? (isNew ? UuidUtils.generateV4() : null));

    final modelToSave = model.copyWith(
      id: localKey,
      profileId: model.profileId,
      clientUuid: clientUuid,
    );

    await box.put(localKey, modelToSave.toMap());

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(model.profileId, ownerUserId)
          : null;

      final isExistingUuid = !isNew && UuidUtils.isValidUuid(cleanId);

      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            MeasurementModel remoteResult;
            if (isExistingUuid) {
              remoteResult = await supabaseRemoteDataSource!.updateMeasurement(
                measurement: modelToSave.copyWith(
                  id: cleanId,
                  profileId: profileUuid,
                ),
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
              final normKey = _normalizeId(remoteResult.id);
              final serverUuid = IdUtils.unprefix(remoteResult.id);
              final synced = remoteResult.copyWith(
                id: serverUuid,
                profileId: model.profileId,
                clientUuid: clientUuid,
              );
              await box.put(normKey, synced.toMap());
              await _cleanupSyncQueue(normKey, rawId, clientUuid);
              return synced;
            } else {
              remoteResult = await supabaseRemoteDataSource!.createMeasurement(
                measurement: modelToSave.copyWith(
                  id: cleanId,
                  profileId: profileUuid,
                ),
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
              final serverUuid = IdUtils.unprefix(remoteResult.id);
              final normKey = 'measurement_$serverUuid';
              final synced = remoteResult.copyWith(
                id: serverUuid,
                profileId: model.profileId,
                clientUuid: clientUuid,
              );
              await box.delete(rawId);
              await box.delete('measurement_$rawId');
              await box.delete(localKey);
              if (cleanId.isNotEmpty) await box.delete(cleanId);
              await box.put(normKey, synced.toMap());
              await _cleanupSyncQueue(normKey, localKey, clientUuid);
              return synced;
            }
          } catch (_) {
            // Fall back to queueing offline mutation
          }
        }

        // Offline or network error: enqueue mutation
        await syncService?.addToQueue(
          SyncQueueItem(
            id: 'sync_vital_${DateTime.now().microsecondsSinceEpoch}',
            entity: 'measurement',
            operation: isExistingUuid ? 'update' : 'create',
            payload: modelToSave.toMap(),
          ),
        );
        return modelToSave;
      }
    }

    final isExistingUuid = !isNew && UuidUtils.isValidUuid(cleanId);
    await syncService?.addToQueue(
      SyncQueueItem(
        id: 'sync_vital_${DateTime.now().microsecondsSinceEpoch}',
        entity: 'measurement',
        operation: isExistingUuid ? 'update' : 'create',
        payload: modelToSave.toMap(),
      ),
    );

    return modelToSave;
  }

  /// Associates a server-returned vital with the local Hive record.
  Future<MeasurementModel> synchronizeVitalRecord(
    MeasurementModel localVital,
    Map<String, dynamic> serverResponse,
  ) async {
    final serverId = serverResponse['id']?.toString() ?? '';
    final serverVital = MeasurementModel.fromMap(serverResponse);

    // Preserve local clientUuid and profileId
    final clientUuid =
        (localVital.clientUuid != null && localVital.clientUuid!.isNotEmpty)
            ? localVital.clientUuid
            : serverVital.clientUuid;

    final synchronized = serverVital.copyWith(
      id: serverId.isNotEmpty ? serverId : localVital.id,
      profileId: localVital.profileId,
      clientUuid: clientUuid,
    );

    final box = hiveService.userBox;
    // If backend assigned a new server ID, remove the temporary local ID entry
    if (serverId.isNotEmpty && serverId != localVital.id) {
      final oldKey = _normalizeId(localVital.id);
      await box.delete(oldKey);
      await box.delete(localVital.id);
    }

    final newKey = _normalizeId(synchronized.id);
    await box.put(newKey, synchronized.toMap());

    // Clean up any pending SyncQueueItem for this vital to prevent duplicate replay
    await _cleanupSyncQueue(newKey, localVital.id, clientUuid);

    return synchronized;
  }

  /// Delete measurement from Hive with profile ownership validation and remote sync.
  Future<void> deleteMeasurement(
    String profileId,
    String measurementId, {
    String? explicitOwnerUserId,
  }) async {
    final existing = await getMeasurementById(
      profileId,
      measurementId,
      explicitOwnerUserId: explicitOwnerUserId,
    );
    if (existing == null) {
      // Direct cross-profile deletion rejection safeguard
      return;
    }

    // 1. Delete from local Hive first
    final box = hiveService.userBox;
    final key = _normalizeId(measurementId);
    final cleanId = IdUtils.unprefix(measurementId).trim();
    await box.delete(key);
    await box.delete(measurementId);
    if (cleanId.isNotEmpty) await box.delete(cleanId);

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;
      final isUuid = UuidUtils.isValidUuid(cleanId);

      bool deletedRemotely = false;
      if (ownerUserId != null && profileUuid != null && isUuid) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            await supabaseRemoteDataSource!.deleteMeasurement(
              measurementId: cleanId,
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            deletedRemotely = true;
          } catch (_) {
            deletedRemotely = false;
          }
        }
      }

      if (!deletedRemotely &&
          isUuid &&
          ownerUserId != null &&
          profileUuid != null) {
        await syncService?.addToQueue(
          SyncQueueItem(
            id: 'sync_vital_delete_${DateTime.now().microsecondsSinceEpoch}',
            entity: 'measurement',
            operation: 'delete',
            payload: {
              'id': measurementId,
              'profile_id': profileId,
              if (existing.clientUuid != null) 'client_uuid': existing.clientUuid,
            },
          ),
        );
      }

      if (!isUuid) {
        await _cleanupSyncQueue(key, measurementId, null);
      }
      return;
    }

    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    if (isNumericServerId) {
      await syncService?.addToQueue(
        SyncQueueItem(
          id: 'sync_vital_delete_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'measurement',
          operation: 'delete',
          payload: {
            'id': measurementId,
            'profile_id': profileId,
            if (existing.clientUuid != null) 'client_uuid': existing.clientUuid,
          },
        ),
      );
    }

    if (!isNumericServerId) {
      await _cleanupSyncQueue(key, measurementId, null);
    }
  }
}
