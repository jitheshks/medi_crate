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
import '../datasources/remote/supabase_medicine_remote_data_source.dart';
import '../models/medicine_model.dart';

/// MedicineRepository manages profile-scoped medication schedules and prescriptions
/// with offline-first Hive caching and native Supabase / PostgreSQL RLS integration.
class MedicineRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final SupabaseMedicineRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal: invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  MedicineRepository({
    required this.hiveService,
    this.syncService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    this.onPullMerged,
    dynamic remoteDataSource,
  });

  String _normalizeId(dynamic rawId) {
    final str = rawId?.toString() ?? '';
    if (str.startsWith('medicine_')) return str;
    return 'medicine_$str';
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
        if (entity == 'medicines' || entity == 'medicine') {
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
  Future<List<MedicineModel>> getMedicineModels(
    String profileId, {
    String? explicitOwnerUserId,
  }) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (supabaseRemoteDataSource != null) {
      unawaited(
        pullMedicines(profileId, explicitOwnerUserId: explicitOwnerUserId),
      );
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
  Future<void> pullMedicines(
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

    final future = _executePullMedicines(
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

  Future<void> _executePullMedicines(
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

        final remoteList = await supabaseRemoteDataSource!.fetchMedicines(
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
              id: key,
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
        return;
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
    String medicineId, {
    String? explicitOwnerUserId,
  }) async {
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
            final remoteModel = await supabaseRemoteDataSource!.getMedicineById(
              medicineId: IdUtils.unprefix(medicineId),
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            if (remoteModel != null) {
              final remoteKey = _normalizeId(remoteModel.id);
              if (!PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'medicine',
                profileId: profileId,
                remoteId: remoteKey,
                clientUuid: remoteModel.clientUuid,
              )) {
                await box.put(
                  remoteKey,
                  remoteModel.copyWith(id: remoteKey).toJson(),
                );
                return remoteModel;
              }
            }
          } catch (_) {}
        }
      }
      return null;
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

  /// Saves a medicine record locally and synchronizes with the backend (M2 / M4).
  Future<Map<String, dynamic>> saveMedicine(
    String profileId,
    Map<String, dynamic> data, {
    String? explicitOwnerUserId,
  }) async {
    final model = MedicineModel.fromJson(data);
    final savedModel = await saveMedicineModel(
      profileId,
      model,
      explicitOwnerUserId: explicitOwnerUserId,
    );
    return savedModel.toJson();
  }

  Future<MedicineModel> saveMedicineModel(
    String profileId,
    MedicineModel model, {
    String? explicitOwnerUserId,
  }) async {
    var rawId = model.id;
    final cleanId = IdUtils.unprefix(rawId).trim();
    final isNew = rawId.isEmpty || rawId.startsWith('temp_');

    final localKey = rawId.isEmpty
        ? 'medicine_${DateTime.now().microsecondsSinceEpoch}'
        : _normalizeId(rawId);

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
      profileId: profileId,
      clientUuid: clientUuid,
    );

    await box.put(localKey, modelToSave.toJson());

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;

      final isExistingUuid = !isNew && UuidUtils.isValidUuid(cleanId);

      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            MedicineModel remoteResult;
            if (isExistingUuid) {
              remoteResult = await supabaseRemoteDataSource!.updateMedicine(
                medicine: modelToSave.copyWith(
                  id: cleanId,
                  profileId: profileUuid,
                ),
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
              final normKey = _normalizeId(remoteResult.id);
              final synced = remoteResult.copyWith(
                id: normKey,
                profileId: profileId,
                clientUuid: clientUuid,
              );
              await box.put(normKey, synced.toJson());
              await _cleanupSyncQueue(normKey, rawId, clientUuid);
              return synced;
            } else {
              remoteResult = await supabaseRemoteDataSource!.createMedicine(
                medicine: modelToSave.copyWith(
                  id: cleanId,
                  profileId: profileUuid,
                ),
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
              final serverKey = _normalizeId(remoteResult.id);
              final synced = remoteResult.copyWith(
                id: serverKey,
                profileId: profileId,
                clientUuid: clientUuid,
              );
              await box.delete(rawId);
              await box.delete('medicine_$rawId');
              await box.delete(localKey);
              if (cleanId.isNotEmpty) await box.delete(cleanId);
              await box.put(serverKey, synced.toJson());
              await _cleanupSyncQueue(serverKey, rawId, clientUuid);
              return synced;
            }
          } catch (_) {
            // Fall back to queueing offline mutation
          }
        }

        // Offline or network error: enqueue mutation
        await syncService?.addToQueue(
          SyncQueueItem(
            id: 'sync_medicine_${DateTime.now().microsecondsSinceEpoch}',
            entity: 'medicines',
            operation: isExistingUuid ? 'update' : 'create',
            payload: modelToSave.toJson(),
          ),
        );
        return modelToSave;
      }
    }

    final isExistingUuid = !isNew && UuidUtils.isValidUuid(cleanId);
    await syncService?.addToQueue(
      SyncQueueItem(
        id: 'sync_medicine_${DateTime.now().microsecondsSinceEpoch}',
        entity: 'medicines',
        operation: isExistingUuid ? 'update' : 'create',
        payload: modelToSave.toJson(),
      ),
    );

    return modelToSave;
  }

  /// Deletes a medicine record locally and remotely (M5).
  Future<void> deleteMedicine(
    String profileId,
    String medicineId, {
    String? explicitOwnerUserId,
  }) async {
    final box = hiveService.userBox;
    final key = _normalizeId(medicineId);
    final cleanId = IdUtils.unprefix(medicineId).trim();
    await box.delete(key);
    await box.delete(medicineId);
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
            await supabaseRemoteDataSource!.deleteMedicine(
              medicineId: cleanId,
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
            id: 'sync_delete_medicine_${DateTime.now().microsecondsSinceEpoch}',
            entity: 'medicines',
            operation: 'delete',
            payload: {'id': key, 'profile_id': profileId},
          ),
        );
      }

      if (!isUuid) {
        await _cleanupSyncQueue(key, medicineId, null);
      }
      return;
    }

    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    if (isNumericServerId) {
      await syncService?.addToQueue(
        SyncQueueItem(
          id: 'sync_delete_medicine_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'medicines',
          operation: 'delete',
          payload: {'id': key, 'profile_id': profileId},
        ),
      );
    }

    if (!isNumericServerId) {
      await _cleanupSyncQueue(key, medicineId, null);
    }
  }
}
