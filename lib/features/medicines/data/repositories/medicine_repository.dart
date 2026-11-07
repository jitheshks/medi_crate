import 'dart:async';
import '../../../../core/api/list_pull_support.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_profile_query_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/medicine_remote_data_source.dart';
import '../models/medicine_model.dart';

/// MedicineRepository manages profile-scoped medication schedules and prescriptions
/// with offline-first Hive caching and Laravel REST API synchronization (M1 - M5).
class MedicineRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final MedicineRemoteDataSource? remoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal (Phase 3): invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  /// Whether the last completed pull retrieved the full server dataset
  /// (`received >= data.total`). Exposed for tests.
  bool lastPullComplete = true;

  MedicineRepository({
    required this.hiveService,
    this.syncService,
    this.remoteDataSource,
    this.connectivityService,
    this.onPullMerged,
  });

  String _normalizeId(dynamic rawId) {
    final str = rawId?.toString() ?? '';
    if (str.startsWith('medicine_')) return str;
    return 'medicine_$str';
  }

  String _cleanServerId(String id) {
    return id.replaceFirst('medicine_', '');
  }

  /// Retrieves raw maps for medicines belonging to [profileId] from local Hive.
  Future<List<Map<String, dynamic>>> getMedicines(String profileId) async {
    return HiveProfileQueryHelper.getRecordsForProfile(
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      keyPrefix: 'medicine_',
      profileId: profileId,
    );
  }

  /// Fetches medicine models for active [profileId] immediately from local Hive cache (M1),
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<MedicineModel>> getMedicineModels(String profileId) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (remoteDataSource != null) {
      unawaited(pullMedicines(profileId));
    }

    // 2. Return local Hive records immediately
    final rawMedicines = await getMedicines(profileId);
    final models = rawMedicines.map((m) => MedicineModel.fromJson(m)).toList();
    models.sort((a, b) {
      final aDate = a.createdAt ?? a.startDate;
      final bDate = b.createdAt ?? b.startDate;
      return bDate.compareTo(aDate);
    });
    return models;
  }

  /// Performs background pull-sync for medicines belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullMedicines(String profileId) {
    if (remoteDataSource == null) return Future.value();
    final existing = _inFlightPulls[profileId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullMedicines(profileId);
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullMedicines(String profileId) async {
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
        (limit, onTotal) => remoteDataSource!.fetchMedicines(
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
          final model = MedicineModel.fromJson(map);
          final key = _normalizeId(model.id);

          // Guard against overwriting pending local mutations (I2-C2)
          if (PendingMutationGuard.hasPendingMutation(
            syncQueueBox: hiveService.syncQueueBox,
            profileBox: hiveService.profileBox,
            entity: 'medicine',
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
          final encoded = merged.toJson();
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
      // Fallback to local cache on network or server failure
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Fetches single medicine details by ID (M3).
  Future<MedicineModel?> getMedicineById(
    String profileId,
    String medicineId,
  ) async {
    final key = _normalizeId(medicineId);
    final box = hiveService.userBox;
    var val =
        box.get(key) ??
        box.get(medicineId) ??
        box.get(IdUtils.unprefix(medicineId));

    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return MedicineModel.fromJson(map);
      }
    }

    if (connectivityService != null && remoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          final cleanId = _cleanServerId(medicineId);
          if (IdUtils.toServerIntId(cleanId) != null) {
            final remoteData = await remoteDataSource!.getMedicine(cleanId);
            final model = MedicineModel.fromJson(remoteData);
            final key = _normalizeId(model.id);

            // Guard against overwriting pending local mutations (I2-C2)
            if (!PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'medicine',
              profileId: profileId,
              remoteId: key,
              clientUuid: model.clientUuid,
            )) {
              await box.put(key, model.toJson());
              return model;
            }
          }
        } catch (_) {}
      }
    }

    final rawMedicines = await getMedicines(profileId);
    final models = rawMedicines.map((m) => MedicineModel.fromJson(m)).toList();
    try {
      return models.firstWhere(
        (m) => IdUtils.matches(m.id, medicineId) || m.id == key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves a medicine record locally and synchronizes with the backend REST API (M2 / M4).
  Future<Map<String, dynamic>> saveMedicine(
    String profileId,
    Map<String, dynamic> data,
  ) async {
    var id = data['id']?.toString() ?? '';
    final isNew = id.isEmpty || id.startsWith('temp_');

    if (id.isEmpty) {
      id = 'medicine_${DateTime.now().microsecondsSinceEpoch}';
    } else if (!id.startsWith('medicine_')) {
      id = 'medicine_$id';
    }

    final box = hiveService.userBox;
    final existingRaw = box.get(id) ?? box.get(data['id']);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    final payload = Map<String, dynamic>.from(data);
    payload['id'] = id;
    payload['profile_id'] = profileId;

    final clientUuid =
        payload['client_uuid']?.toString() ??
        payload['clientUuid']?.toString() ??
        existingUuid ??
        UuidUtils.generateV4();
    payload['client_uuid'] = clientUuid;

    await box.put(id, payload);

    // Online synchronization
    if (connectivityService != null && remoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          final serverProfileId = IdUtils.resolveServerProfileId(
            profileBox: hiveService.profileBox,
            profileId: profileId,
          );
          if (serverProfileId != null) {
            final model = MedicineModel.fromJson(payload);
            final serverPayload = model.toServerMetadataJson(
              serverProfileId: serverProfileId,
            );

            final serverIntId = IdUtils.toServerIntId(_cleanServerId(id));
            if (isNew || serverIntId == null) {
              // M2: POST /medicines
              final remoteResult = await remoteDataSource!.addMedicine(
                serverPayload,
              );
              final serverId = remoteResult['id']?.toString();
              if (serverId != null && serverId.isNotEmpty) {
                await box.delete(id); // Delete temporary local key
                final serverKey = _normalizeId(serverId);
                final updatedPayload = Map<String, dynamic>.from(remoteResult);
                updatedPayload['id'] = serverKey;
                updatedPayload['profile_id'] = profileId;
                if (payload['client_uuid'] != null) {
                  updatedPayload['client_uuid'] = payload['client_uuid'];
                }
                await box.put(serverKey, updatedPayload);
                return updatedPayload;
              }
            } else {
              // M4: PUT /medicines/{id}
              final remoteResult = await remoteDataSource!.updateMedicine(
                serverIntId.toString(),
                serverPayload,
              );
              final updatedPayload = Map<String, dynamic>.from(remoteResult);
              updatedPayload['id'] = id;
              updatedPayload['profile_id'] = profileId;
              await box.put(id, updatedPayload);
              return updatedPayload;
            }
          }
        } catch (_) {
          // Fall back to queueing offline mutation on network / server error
        }
      }
    }

    final isNumericServerId = IdUtils.toServerIntId(_cleanServerId(id)) != null;

    // Offline mutation enqueueing
    await syncService?.addToQueue(
      SyncQueueItem(
        id: 'sync_medicine_${DateTime.now().microsecondsSinceEpoch}',
        entity: 'medicines',
        operation: isNumericServerId ? 'update' : 'create',
        payload: payload,
      ),
    );

    return payload;
  }

  Future<MedicineModel> saveMedicineModel(
    String profileId,
    MedicineModel model,
  ) async {
    final savedData = await saveMedicine(profileId, model.toJson());
    return MedicineModel.fromJson(savedData);
  }

  /// Deletes a medicine record locally and remotely (M5).
  Future<void> deleteMedicine(String profileId, String medicineId) async {
    final box = hiveService.userBox;
    final key = _normalizeId(medicineId);
    await box.delete(key);
    await box.delete(medicineId);

    final cleanId = _cleanServerId(medicineId);
    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    bool deletedRemotely = false;
    if (connectivityService != null &&
        remoteDataSource != null &&
        isNumericServerId) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          await remoteDataSource!.deleteMedicine(serverIntId.toString());
          deletedRemotely = true;
        } catch (_) {
          deletedRemotely = false;
        }
      }
    }

    if (!deletedRemotely && isNumericServerId) {
      await syncService?.addToQueue(
        SyncQueueItem(
          id: 'sync_delete_medicine_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'medicines',
          operation: 'delete',
          payload: {'id': key, 'profile_id': profileId},
        ),
      );
    }

    // If local-only medicine is deleted, remove any pending create/update queue items
    if (!isNumericServerId) {
      try {
        final syncBox = hiveService.syncQueueBox;
        final keysToDelete = <dynamic>[];
        for (final entry in syncBox.toMap().entries) {
          final val = entry.value;
          final entity = val['entity']?.toString().toLowerCase();
          if (entity == 'medicines' || entity == 'medicine') {
            final p = val['payload'];
            if (p is Map) {
              final pId = p['id']?.toString();
              if (pId == key ||
                  pId == medicineId ||
                  (val['id']?.toString() == medicineId)) {
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
