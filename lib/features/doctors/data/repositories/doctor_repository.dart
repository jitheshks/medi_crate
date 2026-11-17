import 'dart:async';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/pulled_record_comparison.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../hospitals/data/repositories/hospital_repository.dart';
import '../datasources/remote/supabase_doctor_remote_data_source.dart';
import '../models/doctor_hospital_relation.dart';
import '../models/doctor_model.dart';
import 'doctor_dependency_helper.dart';

/// DoctorRepository manages profile-associated doctor directories with offline-first Hive caching
/// and Supabase synchronization.
class DoctorRepository {
  final HiveService hiveService;
  final SupabaseDoctorRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;
  final SyncService? syncService;

  /// Post-pull freshness signal: invoked once, after the Hive merge,
  /// only when a pull actually changed local state. Wired by the repository
  /// provider to bump `clinicalCacheRevisionProvider`.
  final void Function()? onPullMerged;

  late final DoctorDependencyHelper _dependencyHelper;
  final Map<String, Future<void>> _inFlightPulls = {};

  DoctorRepository({
    required this.hiveService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    this.syncService,
    this.onPullMerged,
    dynamic remoteDataSource,
  }) {
    _dependencyHelper = DoctorDependencyHelper(hiveService: hiveService);
  }

  /// Normalizes doctor ID to ensure Hive key prefix.
  String _normalizeDoctorId(String rawId) {
    if (rawId.startsWith('doctor_')) return rawId;
    return 'doctor_$rawId';
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
    try {
      final userMap = hiveService.authBox.get('current_user');
      if (userMap is Map) {
        final id = (userMap['id'] ?? userMap['user_id'] ?? userMap['userId'])
            ?.toString();
        if (id != null && id.trim().isNotEmpty) {
          return id.trim();
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
          final pid = (val['profile_id'] ?? val['id'])?.toString();
          if (pid != null &&
              (pid == profileId ||
                  pid == clean ||
                  IdUtils.matchesProfileId(pid, profileId))) {
            direct = val;
            break;
          }
        }
      }
      if (direct != null) {
        final profileOwner = (direct['owner_user_id'] ??
                direct['user_id'] ??
                direct['userId'])
            ?.toString();
        if (profileOwner != null && profileOwner != ownerUserId) {
          return null;
        }
        final resolvedUuid =
            (direct['id'] ?? direct['profile_id'])?.toString();
        if (resolvedUuid != null &&
            UuidUtils.isValidUuid(IdUtils.unprefix(resolvedUuid))) {
          return IdUtils.unprefix(resolvedUuid);
        }
      }
    } catch (_) {}
    if (UuidUtils.isValidUuid(clean)) {
      return clean;
    }
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
        if (entity == 'doctors' || entity == 'doctor') {
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

  /// Retrieves raw maps for doctors belonging to [profileId].
  Future<List<Map<String, dynamic>>> getDoctorsRaw(String profileId) async {
    final box = hiveService.userBox;
    final doctors = <Map<String, dynamic>>[];
    final seenUuids = <String, Map<String, dynamic>>{};
    final seenNames = <String, Map<String, dynamic>>{};
    final staleKeysToDelete = <dynamic>[];

    for (final key in box.keys) {
      if (key.toString().startsWith('doctor_')) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          final storedProfId = (map['profile_id'] ?? map['profileId'])
              ?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final dId = map['id']?.toString() ?? key.toString();
            final uuid =
                map['client_uuid']?.toString() ?? map['clientUuid']?.toString();
            final name = (map['name']?.toString() ?? '').trim().toLowerCase();
            final isServerId =
                IdUtils.toServerIntId(IdUtils.unprefix(dId)) != null;

            if (uuid != null &&
                uuid.isNotEmpty &&
                seenUuids.containsKey(uuid)) {
              final existing = seenUuids[uuid]!;
              final existingId = existing['id']?.toString() ?? '';
              final existingIsServer =
                  IdUtils.toServerIntId(IdUtils.unprefix(existingId)) != null;
              if (isServerId && !existingIsServer) {
                staleKeysToDelete.add(existingId);
                doctors.remove(existing);
                seenUuids[uuid] = map;
                doctors.add(map);
              } else {
                staleKeysToDelete.add(key);
              }
              continue;
            }

            if (name.isNotEmpty && seenNames.containsKey(name)) {
              final existing = seenNames[name]!;
              final existingId = existing['id']?.toString() ?? '';
              final existingIsServer =
                  IdUtils.toServerIntId(IdUtils.unprefix(existingId)) != null;
              if (isServerId && !existingIsServer) {
                staleKeysToDelete.add(existingId);
                doctors.remove(existing);
                seenNames[name] = map;
                if (uuid != null && uuid.isNotEmpty) seenUuids[uuid] = map;
                doctors.add(map);
                continue;
              } else if (!isServerId && existingIsServer) {
                staleKeysToDelete.add(key);
                continue;
              }
            }

            if (uuid != null && uuid.isNotEmpty) {
              seenUuids[uuid] = map;
            }
            if (name.isNotEmpty) {
              seenNames[name] = map;
            }
            doctors.add(map);
          }
        }
      }
    }

    for (final k in staleKeysToDelete) {
      await box.delete(k);
      await box.delete(IdUtils.unprefix(k.toString()));
    }

    return doctors;
  }

  /// Backward-compatible getDoctors returning raw maps.
  Future<List<Map<String, dynamic>>> getDoctors(String profileId) async {
    return getDoctorsRaw(profileId);
  }

  /// Fetches typed [DoctorModel] records for [profileId] immediately from local Hive cache (D1),
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<DoctorModel>> getDoctorModels(String profileId) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (supabaseRemoteDataSource != null) {
      unawaited(pullDoctors(profileId));
    }

    // 2. Return local Hive records immediately
    final rawList = await getDoctorsRaw(profileId);
    return rawList.map((m) => DoctorModel.fromJson(m)).toList();
  }

  /// Performs background pull-sync for doctors belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullDoctors(
    String profileId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) {
    if (supabaseRemoteDataSource == null) {
      return Future.value();
    }
    final existing = _inFlightPulls[profileId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullDoctors(
      profileId,
      ownerUserId: ownerUserId,
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

  Future<void> _executePullDoctors(
    String profileId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    if (supabaseRemoteDataSource != null) {
      final effectiveOwnerUserId =
          _resolveCurrentUserId(ownerUserId ?? explicitOwnerUserId);
      if (effectiveOwnerUserId == null || effectiveOwnerUserId.isEmpty) return;

      final profileUuid = _resolveProfileUuid(profileId, effectiveOwnerUserId);
      if (profileUuid == null || profileUuid.isEmpty) return;

      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;
      if (!isOnline) return;

      try {
        final remoteList = await supabaseRemoteDataSource!.fetchDoctors(
          ownerUserId: effectiveOwnerUserId,
          profileId: profileUuid,
        );

        if (remoteList.isNotEmpty) {
          final box = hiveService.userBox;
          var pulledChanged = false;
          for (final model in remoteList) {
            final key = _normalizeDoctorId(model.id);

            if (PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'doctor',
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
      } catch (_) {
        // Fallback gracefully without calling legacy
      } finally {
        _inFlightPulls.remove(profileId);
      }
    }
  }

  /// Strictly profile-scoped doctor lookup by [doctorId] (D3).
  /// Returns null if doctor does not exist or belongs to another profile.
  Future<DoctorModel?> getDoctorById(
    String profileId,
    String doctorId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final key = _normalizeDoctorId(doctorId);
    final box = hiveService.userBox;
    var val =
        box.get(key) ??
        box.get(doctorId) ??
        box.get(IdUtils.unprefix(doctorId));
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return DoctorModel.fromJson(map);
      }
    }

    if (supabaseRemoteDataSource != null) {
      final effectiveOwnerUserId =
          _resolveCurrentUserId(ownerUserId ?? explicitOwnerUserId);
      if (effectiveOwnerUserId != null && effectiveOwnerUserId.isNotEmpty) {
        final profileUuid =
            _resolveProfileUuid(profileId, effectiveOwnerUserId);
        if (profileUuid != null && profileUuid.isNotEmpty) {
          try {
            final remoteDoc = await supabaseRemoteDataSource!.getDoctorById(
              doctorId: IdUtils.unprefix(doctorId),
              ownerUserId: effectiveOwnerUserId,
              profileId: profileUuid,
            );
            if (remoteDoc != null) {
              final cachedModel = remoteDoc.copyWith(
                id: key,
                profileId: profileId,
              );
              await box.put(key, cachedModel.toJson());
              return cachedModel;
            }
          } catch (_) {}
        }
      }
    }

    final rawList = await getDoctorsRaw(profileId);
    final all = rawList.map((m) => DoctorModel.fromJson(m)).toList();
    try {
      return all.firstWhere(
        (d) => IdUtils.matches(d.id, doctorId) || d.id == key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves a doctor map into Hive for [profileId].
  Future<Map<String, dynamic>> saveDoctor(
    String profileId,
    Map<String, dynamic> data, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final rawId =
        data['id'] ?? 'doctor_${DateTime.now().microsecondsSinceEpoch}';
    final id = _normalizeDoctorId(rawId.toString());

    final box = hiveService.userBox;
    final existingRaw = box.get(id) ?? box.get(rawId);
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
    return payload;
  }

  /// Saves a typed [DoctorModel] into Hive for [profileId] and syncs with backend (D2 / D4).
  /// Strictly filters [hospitalIds] to prevent cross-profile hospital linkage.
  Future<DoctorModel> saveDoctorModel(
    String profileId,
    DoctorModel doctor, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final rawId = doctor.id.isNotEmpty
        ? doctor.id
        : 'doctor_${DateTime.now().microsecondsSinceEpoch}';
    final id = _normalizeDoctorId(rawId);

    final box = hiveService.userBox;
    final existingRaw = box.get(id) ?? box.get(rawId);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    // Validate and filter hospitalIds so Profile A doctor cannot link to Profile B hospital
    final hospitalRepo = HospitalRepository(hiveService: hiveService);
    final validHospitals = await hospitalRepo.getHospitalModels(profileId);
    final validKeys = <String>{};
    for (final h in validHospitals) {
      validKeys.add(h.id);
      validKeys.add(IdUtils.unprefix(h.id));
    }

    final sanitizedHospitalIds = doctor.hospitalIds.where((hId) {
      return IdUtils.contains(validKeys, hId);
    }).toList();

    // Resolve hospital name from linked hospital or existing name
    String? resolvedHospitalName = doctor.hospitalName;
    if ((resolvedHospitalName == null || resolvedHospitalName.isEmpty) &&
        sanitizedHospitalIds.isNotEmpty) {
      try {
        final targetHospId = sanitizedHospitalIds.first;
        final matchedHospital = validHospitals.firstWhere(
          (h) => IdUtils.matches(h.id, targetHospId),
        );
        resolvedHospitalName = matchedHospital.name;
      } catch (_) {}
    }

    final clientUuid =
        (doctor.clientUuid != null && doctor.clientUuid!.trim().isNotEmpty)
        ? doctor.clientUuid!.trim()
        : (existingUuid ?? UuidUtils.generateV4());

    var updated = doctor.copyWith(
      id: id,
      profileId: profileId,
      hospitalIds: sanitizedHospitalIds,
      hospitalName: resolvedHospitalName,
      clientUuid: clientUuid,
    );
    final payload = updated.toJson();

    await box.put(id, payload);

    final cleanId = IdUtils.unprefix(doctor.id).trim();
    final isNew = cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId);

    if (supabaseRemoteDataSource != null) {
      final effectiveOwnerUserId =
          _resolveCurrentUserId(ownerUserId ?? explicitOwnerUserId);
      final profileUuid = effectiveOwnerUserId != null
          ? _resolveProfileUuid(profileId, effectiveOwnerUserId)
          : null;

      if (effectiveOwnerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;

        if (isOnline) {
          try {
            if (isNew) {
              final created = await supabaseRemoteDataSource!.createDoctor(
                doctor: updated.copyWith(profileId: profileUuid),
                ownerUserId: effectiveOwnerUserId,
                profileId: profileUuid,
              );
              final newKey = _normalizeDoctorId(created.id);
              if (newKey != id) {
                await box.delete(id);
                await box.delete(rawId);
              }
              final savedModel = created.copyWith(
                id: newKey,
                profileId: profileId,
                clientUuid: clientUuid,
                hospitalIds: sanitizedHospitalIds,
                hospitalName: resolvedHospitalName,
              );
              await box.put(newKey, savedModel.toJson());
              await _cleanupSyncQueue(newKey, created.id, clientUuid);
              return savedModel;
            } else {
              final updatedRemote = await supabaseRemoteDataSource!.updateDoctor(
                doctor: updated.copyWith(id: cleanId, profileId: profileUuid),
                ownerUserId: effectiveOwnerUserId,
                profileId: profileUuid,
              );
              final savedModel = updatedRemote.copyWith(
                id: id,
                profileId: profileId,
                clientUuid: clientUuid,
                hospitalIds: sanitizedHospitalIds,
                hospitalName: resolvedHospitalName,
              );
              await box.put(id, savedModel.toJson());
              await _cleanupSyncQueue(id, cleanId, clientUuid);
              return savedModel;
            }
          } catch (e) {
            if (syncService != null) {
              await syncService!.addToQueue(
                SyncQueueItem(
                  id: 'sync_doc_${DateTime.now().microsecondsSinceEpoch}',
                  entity: 'doctor',
                  operation: isNew ? 'create' : 'update',
                  payload: updated.toJson(),
                ),
              );
            }
          }
        } else {
          if (syncService != null) {
            await syncService!.addToQueue(
              SyncQueueItem(
                id: 'sync_doc_${DateTime.now().microsecondsSinceEpoch}',
                entity: 'doctor',
                operation: isNew ? 'create' : 'update',
                payload: updated.toJson(),
              ),
            );
          }
        }
      }
      return updated;
    }

    if (syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_doc_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'doctor',
          operation: isNew ? 'create' : 'update',
          payload: updated.toJson(),
        ),
      );
    }

    return updated;
  }

  /// Calculates all dependent records linked to [doctorId] for [profileId].
  Future<EntityDependencies> getDoctorDependencies(
    String profileId,
    String doctorId,
  ) async {
    final doctor = await getDoctorById(profileId, doctorId);
    return _dependencyHelper.getDoctorDependencies(
      profileId: profileId,
      doctor: doctor,
      doctorId: doctorId,
    );
  }

  /// Returns all practicing hospitals for [doctor], deriving both explicit
  /// links and consultation relationships.
  Future<List<PracticingHospitalInfo>> getPracticingHospitals(
    String profileId,
    DoctorModel doctor,
  ) async {
    return _dependencyHelper.getPracticingHospitals(profileId, doctor);
  }

  /// Deletes a doctor by [doctorId] for [profileId] if there are no dependencies (D5).
  /// Throws [ResourceHasDependenciesException] if dependencies exist.
  Future<void> deleteDoctor(
    String profileId,
    String doctorId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final key = _normalizeDoctorId(doctorId);
    final box = hiveService.userBox;
    final val = box.get(key) ?? box.get(doctorId);
    if (val == null) return;

    final deps = await getDoctorDependencies(profileId, doctorId);
    if (deps.hasDependencies) {
      throw ResourceHasDependenciesException(
        'Cannot delete this doctor. This doctor has linked records and cannot be permanently deleted until they are removed or reassigned.',
        dependencyCounts: {
          'hospitals': deps.hospitals,
          'consultations': deps.consultations,
          'reports': deps.reports,
          'appointments': deps.appointments,
        },
      );
    }

    // 1. Delete from local Hive first
    await box.delete(key);
    await box.delete(doctorId);
    final cleanId = IdUtils.unprefix(doctorId).trim();
    await box.delete(cleanId);
    final isNumericServerId = IdUtils.toServerIntId(cleanId) != null;

    if (supabaseRemoteDataSource != null) {
      final effectiveOwnerUserId =
          _resolveCurrentUserId(ownerUserId ?? explicitOwnerUserId);
      final profileUuid = effectiveOwnerUserId != null
          ? _resolveProfileUuid(profileId, effectiveOwnerUserId)
          : null;

      if (effectiveOwnerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;

        if (isOnline) {
          try {
            await supabaseRemoteDataSource!.deleteDoctor(
              doctorId: cleanId,
              ownerUserId: effectiveOwnerUserId,
              profileId: profileUuid,
            );
          } catch (_) {}
        } else {
          if (syncService != null) {
            await syncService!.addToQueue(
              SyncQueueItem(
                id: 'sync_doc_del_${DateTime.now().microsecondsSinceEpoch}',
                entity: 'doctor',
                operation: 'delete',
                payload: {'id': cleanId, 'profile_id': profileId},
              ),
            );
          }
        }
      }
      await _cleanupSyncQueue(key, cleanId, null);
      return;
    }

    if (syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_doc_del_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'doctor',
          operation: 'delete',
          payload: {'id': cleanId, 'profile_id': profileId},
        ),
      );
    }
    await _cleanupSyncQueue(key, cleanId, null);

    // If local-only entity is deleted, remove any pending create/update queue items
    if (!isNumericServerId) {
      try {
        final syncBox = hiveService.syncQueueBox;
        final keysToDelete = <dynamic>[];
        for (final entry in syncBox.toMap().entries) {
          final val = entry.value;
          final entity = val['entity']?.toString().toLowerCase();
          if (entity == 'doctors' || entity == 'doctor') {
            final p = val['payload'];
            if (p is Map) {
              final pId = p['id']?.toString();
              if (pId == key ||
                  pId == doctorId ||
                  (val['id']?.toString() == doctorId)) {
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
