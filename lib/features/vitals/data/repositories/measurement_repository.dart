import 'dart:async';

import '../../../../core/api/list_pull_support.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_profile_query_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/vitals_remote_data_source.dart';
import '../models/measurement_model.dart';

/// MeasurementRepository manages profile-scoped body vitals and metrics with offline-first synchronization.
class MeasurementRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final VitalsRemoteDataSource? remoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal (Phase 3): invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  /// Whether the last completed pull retrieved the full server dataset
  /// (`received >= data.total`). Exposed for tests.
  bool lastPullComplete = true;

  MeasurementRepository({
    required this.hiveService,
    this.syncService,
    this.remoteDataSource,
    this.connectivityService,
    this.onPullMerged,
  });

  /// Normalize local measurement storage key.
  String _normalizeId(String rawId) {
    if (rawId.startsWith('measurement_')) return rawId;
    return 'measurement_$rawId';
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
  Future<List<MeasurementModel>> getMeasurementModels(String profileId) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (remoteDataSource != null) {
      unawaited(pullMeasurements(profileId));
    }

    // 2. Return local Hive records immediately
    final rawList = await getMeasurements(profileId);
    final models = rawList.map((map) => MeasurementModel.fromMap(map)).toList();
    models.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return models;
  }

  /// Performs background pull-sync for measurements belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullMeasurements(String profileId) {
    if (remoteDataSource == null) return Future.value();
    final existing = _inFlightPulls[profileId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullMeasurements(profileId);
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullMeasurements(String profileId) async {
    try {
      final numericProfileId = IdUtils.resolveServerProfileId(
        profileBox: hiveService.profileBox,
        profileId: profileId,
      );
      if (numericProfileId == null) return;

      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (!isOnline) return;

      final remoteList = await fetchCompleteList(
        (limit, onTotal) => remoteDataSource!.fetchVitals(
          profileId: numericProfileId,
          limit: limit,
          onTotal: onTotal,
        ),
        onComplete: (c) => lastPullComplete = c,
      );
      if (remoteList.isNotEmpty) {
        final box = hiveService.userBox;
        var pulledChanged = false;
        for (final map in remoteList) {
          final model = MeasurementModel.fromMap(map);
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
    } catch (_) {
      // Fallback to local cache on network or parsing failure
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Get single measurement by ID with strict profile ownership validation.
  Future<MeasurementModel?> getMeasurementById(
    String profileId,
    String measurementId,
  ) async {
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

    if (connectivityService != null && remoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          final cleanId = IdUtils.unprefix(measurementId);
          if (IdUtils.toServerIntId(cleanId) != null) {
            final remoteMap = await remoteDataSource!.getVital(cleanId);
            if (remoteMap.isNotEmpty) {
              final model = MeasurementModel.fromMap(remoteMap);
              final key = _normalizeId(model.id);

              // Guard against overwriting pending local mutations (I2-C2)
              if (!PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'measurement',
                profileId: profileId,
                remoteId: key,
                clientUuid: model.clientUuid,
              )) {
                await box.put(key, model.toMap());
                return model;
              }
            }
          }
        } catch (_) {}
      }
    }

    final rawList = await getMeasurements(profileId);
    final models = rawList.map((map) => MeasurementModel.fromMap(map)).toList();
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
    Map<String, dynamic> data,
  ) async {
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

    // Check if existing record has a client_uuid to preserve during updates
    final existingRaw = box.get(id) ?? box.get(rawId);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    // Preserve existing UUID or generate exactly once for new records
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

    return payload;
  }

  /// Save a MeasurementModel into Hive storage, Sync Queue, and synchronize with remote API when online.
  Future<MeasurementModel> saveMeasurementModel(MeasurementModel model) async {
    final rawId = model.id;
    final id = rawId.isNotEmpty
        ? _normalizeId(rawId)
        : 'measurement_${DateTime.now().microsecondsSinceEpoch}_${model.type}';

    final box = hiveService.userBox;
    final isNew =
        rawId.isEmpty || (!box.containsKey(id) && !box.containsKey(rawId));

    final existingRaw = box.get(id) ?? box.get(rawId);
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
      id: id,
      profileId: model.profileId,
      clientUuid: clientUuid,
    );
    final map = modelToSave.toMap();
    await saveMeasurement(model.profileId, map);

    final cleanId = IdUtils.unprefix(modelToSave.id);
    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    if (connectivityService != null && remoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          final serverProfileId = IdUtils.resolveServerProfileId(
            profileBox: hiveService.profileBox,
            profileId: model.profileId,
          );
          if (serverProfileId != null) {
            Map<String, dynamic> remoteResponse;
            if (isNumericServerId) {
              remoteResponse = await remoteDataSource!.updateVital(
                serverIntId.toString(),
                modelToSave.toApiJson(serverProfileId: serverProfileId),
              );
            } else {
              remoteResponse = await remoteDataSource!.addVital(
                modelToSave.toApiJson(serverProfileId: serverProfileId),
              );
            }
            return await synchronizeVitalRecord(modelToSave, remoteResponse);
          }
        } catch (_) {
          return modelToSave;
        }
      }
    }

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
            if ((clientUuid != null && pUuid == clientUuid) ||
                (pId != null &&
                    (pId == localVital.id || pId == synchronized.id))) {
              keysToDelete.add(entry.key);
            }
          }
        }
      }
      for (final k in keysToDelete) {
        await syncBox.delete(k);
      }
    } catch (_) {}

    return synchronized;
  }

  /// Delete measurement from Hive with profile ownership validation and remote sync.
  Future<void> deleteMeasurement(String profileId, String measurementId) async {
    final existing = await getMeasurementById(profileId, measurementId);
    if (existing == null) {
      // Direct cross-profile deletion rejection safeguard
      return;
    }

    // 1. Delete from local Hive first
    final box = hiveService.userBox;
    final key = _normalizeId(measurementId);
    await box.delete(key);
    await box.delete(measurementId);

    final cleanId = IdUtils.unprefix(measurementId);
    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    bool deletedRemotely = false;
    if (connectivityService != null &&
        remoteDataSource != null &&
        isNumericServerId) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          await remoteDataSource!.deleteVital(serverIntId.toString());
          deletedRemotely = true;
        } catch (_) {
          deletedRemotely = false;
        }
      }
    }

    if (!deletedRemotely && isNumericServerId) {
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

    // If local-only vital is deleted, remove any pending create/update queue items
    if (!isNumericServerId) {
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
              final pId = p['id']?.toString();
              if (pId == key ||
                  pId == measurementId ||
                  (val['id']?.toString() == measurementId)) {
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
  }
}
