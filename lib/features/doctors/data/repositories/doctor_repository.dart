import 'dart:async';

import '../../../../core/api/list_pull_support.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../hospitals/data/repositories/hospital_repository.dart';
import '../datasources/remote/doctor_remote_data_source.dart';
import '../models/doctor_hospital_relation.dart';
import '../models/doctor_model.dart';
import 'doctor_dependency_helper.dart';

/// DoctorRepository manages profile-associated doctor directories with offline-first Hive caching
/// and REST API synchronization (D1 - D5).
class DoctorRepository {
  final HiveService hiveService;
  final DoctorRemoteDataSource? remoteDataSource;
  final ConnectivityService? connectivityService;
  final SyncService? syncService;

  /// Post-pull freshness signal (Phase 3): invoked once, after the Hive merge,
  /// only when a pull actually changed local state. Wired by the repository
  /// provider to bump `clinicalCacheRevisionProvider`.
  final void Function()? onPullMerged;

  late final DoctorDependencyHelper _dependencyHelper;
  final Map<String, Future<void>> _inFlightPulls = {};

  /// Whether the last completed pull retrieved the full server dataset
  /// (`received >= data.total`). `false` means the server capped `limit` below
  /// `total`; callers must treat the result as partial. Exposed for tests.
  bool lastPullComplete = true;

  DoctorRepository({
    required this.hiveService,
    this.remoteDataSource,
    this.connectivityService,
    this.syncService,
    this.onPullMerged,
  }) {
    _dependencyHelper = DoctorDependencyHelper(hiveService: hiveService);
  }

  /// Normalizes doctor ID to ensure Hive key prefix.
  String _normalizeDoctorId(String rawId) {
    if (rawId.startsWith('doctor_')) return rawId;
    return 'doctor_$rawId';
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
    if (remoteDataSource != null) {
      unawaited(pullDoctors(profileId));
    }

    // 2. Return local Hive records immediately
    final rawList = await getDoctorsRaw(profileId);
    return rawList.map((m) => DoctorModel.fromJson(m)).toList();
  }

  /// Performs background pull-sync for doctors belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullDoctors(String profileId) {
    if (remoteDataSource == null) return Future.value();
    final existing = _inFlightPulls[profileId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullDoctors(profileId);
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullDoctors(String profileId) async {
    if (SyncService.isRemotePushSuspended) return;
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
        (limit, onTotal) => remoteDataSource!.fetchDoctors(
          profileId: numericProfileId,
          limit: limit,
          onTotal: onTotal,
        ),
        onComplete: (c) => lastPullComplete = c,
      );
      final box = hiveService.userBox;
      var pulledChanged = false;

      for (final raw in remoteList) {
        final remoteModel = DoctorModel.fromJson(raw);
        final cleanId = remoteModel.id.isNotEmpty
            ? remoteModel.id
            : (raw['id']?.toString() ?? '');
        final id = _normalizeDoctorId(cleanId);

        // Guard against overwriting pending local mutations (I2-C2)
        if (PendingMutationGuard.hasPendingMutation(
          syncQueueBox: hiveService.syncQueueBox,
          profileBox: hiveService.profileBox,
          entity: 'doctor',
          profileId: profileId,
          remoteId: id,
          clientUuid: remoteModel.clientUuid,
        )) {
          continue;
        }

        // Search for existing local entry by key, un-prefixed key, clientUuid, or matching name
        dynamic matchingKey;
        Map<String, dynamic>? existingMap;

        final directMatch = box.get(id) ?? box.get(cleanId);
        if (directMatch is Map) {
          matchingKey = box.containsKey(id) ? id : cleanId;
          existingMap = Map<String, dynamic>.from(directMatch);
        } else {
          for (final k in box.keys) {
            final kStr = k.toString();
            if (kStr.startsWith('doctor_')) {
              final val = box.get(k);
              if (val is Map) {
                final prof = (val['profile_id'] ?? val['profileId'])
                    ?.toString();
                if (IdUtils.matchesProfileId(
                  prof,
                  profileId,
                  profileBox: hiveService.profileBox,
                )) {
                  final u =
                      val['client_uuid']?.toString() ??
                      val['clientUuid']?.toString();
                  final n = val['name']?.toString().trim().toLowerCase();
                  final isTemporaryLocal =
                      IdUtils.toServerIntId(IdUtils.unprefix(kStr)) == null;

                  if (remoteModel.clientUuid != null &&
                      u != null &&
                      u == remoteModel.clientUuid) {
                    matchingKey = k;
                    existingMap = Map<String, dynamic>.from(val);
                    break;
                  } else if (isTemporaryLocal &&
                      n != null &&
                      n == remoteModel.name.trim().toLowerCase()) {
                    matchingKey = k;
                    existingMap = Map<String, dynamic>.from(val);
                    break;
                  }
                }
              }
            }
          }
        }

        DoctorModel merged = remoteModel.copyWith(id: id, profileId: profileId);

        if (existingMap != null) {
          final existingModel = DoctorModel.fromJson(existingMap);
          merged = merged.copyWith(
            hospitalIds: merged.hospitalIds.isNotEmpty
                ? merged.hospitalIds
                : existingModel.hospitalIds,
            notes: (merged.notes != null && merged.notes!.isNotEmpty)
                ? merged.notes
                : existingModel.notes,
            clientUuid: existingModel.clientUuid ?? remoteModel.clientUuid,
          );

          if (matchingKey != null && matchingKey.toString() != id) {
            final oldKeyStr = matchingKey.toString();
            final oldIdStr = IdUtils.unprefix(oldKeyStr);
            await box.delete(matchingKey);
            await box.delete(oldIdStr);

            // Re-point consultation doctor references in userBox
            final serverIntId = IdUtils.toServerIntId(IdUtils.unprefix(id));
            for (final cKey in box.keys) {
              final cKeyStr = cKey.toString();
              if (cKeyStr.startsWith('consultation_') ||
                  cKeyStr.startsWith('con_')) {
                final cVal = box.get(cKey);
                if (cVal is Map) {
                  final cMap = Map<String, dynamic>.from(cVal);
                  final cProf = (cMap['profile_id'] ?? cMap['profileId'])
                      ?.toString();
                  if (IdUtils.matchesProfileId(
                    cProf,
                    profileId,
                    profileBox: hiveService.profileBox,
                  )) {
                    final cDoc =
                        cMap['doctor_id']?.toString() ??
                        cMap['doctorId']?.toString();
                    if (cDoc == oldKeyStr ||
                        cDoc == oldIdStr ||
                        IdUtils.matches(cDoc, oldKeyStr)) {
                      cMap['doctor_id'] = serverIntId ?? id;
                      await box.put(cKey, cMap);
                    }
                  }
                }
              }
            }
          }
        }

        final encoded = merged.toJson();
        if (pulledRecordChanged(box.get(id), encoded)) pulledChanged = true;
        await box.put(id, encoded);
      }

      if (pulledChanged) {
        try {
          onPullMerged?.call();
        } catch (_) {}
      }
    } catch (_) {
      // Fallback gracefully to local Hive cache on remote error / offline
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Strictly profile-scoped doctor lookup by [doctorId] (D3).
  /// Returns null if doctor does not exist or belongs to another profile.
  Future<DoctorModel?> getDoctorById(String profileId, String doctorId) async {
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
    Map<String, dynamic> data,
  ) async {
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
    DoctorModel doctor,
  ) async {
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

    final cleanId = IdUtils.unprefix(doctor.id);
    final isNumericServerId = int.tryParse(cleanId) != null;

    bool syncedRemotely = false;
    if (remoteDataSource != null && !SyncService.isRemotePushSuspended) {
      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (isOnline) {
        final apiPayload = updated.toApiJson(
          resolvedHospitalName: resolvedHospitalName,
        );
        try {
          if (isNumericServerId) {
            // D4: Update Doctor (POST /doctors/{id})
            final remoteRes = await remoteDataSource!.updateDoctor(
              cleanId,
              apiPayload,
            );
            final serverDoctor = DoctorModel.fromJson(remoteRes);
            updated = updated.copyWith(
              name: serverDoctor.name,
              specialty: serverDoctor.specialty,
              phone: serverDoctor.phone ?? updated.phone,
              email: serverDoctor.email ?? updated.email,
              hospitalName: serverDoctor.hospitalName ?? updated.hospitalName,
            );
            await box.put(id, updated.toJson());
            syncedRemotely = true;
          } else {
            // D2: Add Doctor (POST /doctors)
            final remoteRes = await remoteDataSource!.addDoctor(apiPayload);
            final serverDoctor = DoctorModel.fromJson(remoteRes);
            final serverRawId = serverDoctor.id.isNotEmpty
                ? serverDoctor.id
                : (remoteRes['id']?.toString() ?? '');

            if (serverRawId.isNotEmpty) {
              final newId = _normalizeDoctorId(serverRawId);
              if (newId != id) {
                await box.delete(id);
                await box.delete(rawId);
              }
              updated = updated.copyWith(
                id: newId,
                name: serverDoctor.name,
                specialty: serverDoctor.specialty,
                phone: serverDoctor.phone ?? updated.phone,
                email: serverDoctor.email ?? updated.email,
                hospitalName: serverDoctor.hospitalName ?? updated.hospitalName,
              );
              await box.put(newId, updated.toJson());
              syncedRemotely = true;
            }
          }
        } catch (_) {
          // On any network or server error, fall back gracefully to offline queueing
          syncedRemotely = false;
        }
      }
    }

    if (!syncedRemotely && syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_doc_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'doctors',
          operation: isNumericServerId ? 'update' : 'create',
          payload: payload,
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
  Future<void> deleteDoctor(String profileId, String doctorId) async {
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

    final cleanId = IdUtils.unprefix(doctorId);
    final isNumericServerId = int.tryParse(cleanId) != null;

    bool deletedRemotely = false;
    if (remoteDataSource != null &&
        !SyncService.isRemotePushSuspended &&
        isNumericServerId) {
      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (isOnline) {
        try {
          await remoteDataSource!.deleteDoctor(cleanId);
          deletedRemotely = true;
        } catch (_) {
          deletedRemotely = false;
        }
      }
    }

    if (!deletedRemotely && syncService != null && isNumericServerId) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_doc_del_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'doctors',
          operation: 'delete',
          payload: {'id': cleanId, 'profile_id': profileId},
        ),
      );
    }

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
