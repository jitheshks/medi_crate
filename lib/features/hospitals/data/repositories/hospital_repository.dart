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
import '../../../doctors/data/models/doctor_hospital_relation.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../datasources/remote/supabase_hospital_remote_data_source.dart';
import '../models/hospital_model.dart';

/// HospitalRepository manages profile-associated healthcare facilities,
/// coordinates offline-first Hive caching with Supabase synchronization,
/// and enforces relational dependency validation.
class HospitalRepository {
  final HiveService hiveService;
  final SupabaseHospitalRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;
  final SyncService? syncService;

  /// Post-pull freshness signal: invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  HospitalRepository({
    required this.hiveService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    this.syncService,
    this.onPullMerged,
    dynamic remoteDataSource,
  });

  String _normalizeHospitalId(String rawId) {
    if (rawId.startsWith('hospital_')) return rawId;
    return 'hospital_$rawId';
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
        if (entity == 'hospitals' || entity == 'hospital') {
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

  /// Retrieves raw maps for hospitals belonging to [profileId].
  Future<List<Map<String, dynamic>>> getHospitals(String profileId) async {
    final box = hiveService.userBox;
    final hospitals = <Map<String, dynamic>>[];
    final seenUuids = <String, Map<String, dynamic>>{};
    final seenNames = <String, Map<String, dynamic>>{};
    final staleKeysToDelete = <dynamic>[];

    for (final key in box.keys) {
      if (key.toString().startsWith('hospital_')) {
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
            final hId = map['id']?.toString() ?? key.toString();
            final uuid =
                map['client_uuid']?.toString() ?? map['clientUuid']?.toString();
            final name = (map['name']?.toString() ?? '').trim().toLowerCase();
            final isServerId =
                IdUtils.toServerIntId(IdUtils.unprefix(hId)) != null;

            if (uuid != null &&
                uuid.isNotEmpty &&
                seenUuids.containsKey(uuid)) {
              final existing = seenUuids[uuid]!;
              final existingId = existing['id']?.toString() ?? '';
              final existingIsServer =
                  IdUtils.toServerIntId(IdUtils.unprefix(existingId)) != null;
              if (isServerId && !existingIsServer) {
                // Replace unsynced with synced
                staleKeysToDelete.add(existingId);
                hospitals.remove(existing);
                seenUuids[uuid] = map;
                hospitals.add(map);
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
                // Replace unsynced with synced
                staleKeysToDelete.add(existingId);
                hospitals.remove(existing);
                seenNames[name] = map;
                if (uuid != null && uuid.isNotEmpty) seenUuids[uuid] = map;
                hospitals.add(map);
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
            hospitals.add(map);
          }
        }
      }
    }

    for (final k in staleKeysToDelete) {
      await box.delete(k);
      await box.delete(IdUtils.unprefix(k.toString()));
    }

    return hospitals;
  }

  /// Fetches typed [HospitalModel] records for [profileId] immediately from local Hive cache (H1),
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<HospitalModel>> getHospitalModels(String profileId) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (supabaseRemoteDataSource != null) {
      unawaited(pullHospitals(profileId));
    }

    // 2. Return local Hive records immediately
    final rawList = await getHospitals(profileId);
    return rawList.map((m) => HospitalModel.fromJson(m)).toList();
  }

  /// Performs background pull-sync for hospitals belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullHospitals(
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

    final future = _executePullHospitals(
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

  Future<void> _executePullHospitals(
    String profileId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    try {
      if (supabaseRemoteDataSource != null) {
      final effectiveOwnerUserId =
          _resolveCurrentUserId(ownerUserId ?? explicitOwnerUserId);
      if (effectiveOwnerUserId == null || effectiveOwnerUserId.isEmpty) return;

      final profileUuid =
          _resolveProfileUuid(profileId, effectiveOwnerUserId);
      if (profileUuid == null || profileUuid.isEmpty) return;

      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;
      if (!isOnline) return;

      try {
        final remoteList = await supabaseRemoteDataSource!.fetchHospitals(
          ownerUserId: effectiveOwnerUserId,
          profileId: profileUuid,
        );

        if (remoteList.isNotEmpty) {
          final box = hiveService.userBox;
          var pulledChanged = false;
          for (final model in remoteList) {
            final key = _normalizeHospitalId(model.id);

            if (PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'hospital',
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
      } catch (_) {}
      return;
    }
  } finally {
    _inFlightPulls.remove(profileId);
  }
  }



  /// Strictly profile-scoped hospital lookup by [hospitalId].
  Future<HospitalModel?> getHospitalById(
    String profileId,
    String hospitalId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final key = _normalizeHospitalId(hospitalId);
    final box = hiveService.userBox;
    var val =
        box.get(key) ??
        box.get(hospitalId) ??
        box.get(IdUtils.unprefix(hospitalId));
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return HospitalModel.fromJson(map);
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
            final remoteHosp = await supabaseRemoteDataSource!.getHospitalById(
              hospitalId: IdUtils.unprefix(hospitalId),
              ownerUserId: effectiveOwnerUserId,
              profileId: profileUuid,
            );
            if (remoteHosp != null) {
              final cachedModel = remoteHosp.copyWith(
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

    final rawList = await getHospitals(profileId);
    final all = rawList.map((m) => HospitalModel.fromJson(m)).toList();
    try {
      return all.firstWhere(
        (h) => IdUtils.matches(h.id, hospitalId) || h.id == key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves a hospital map into Hive for [profileId].
  Future<Map<String, dynamic>> saveHospital(
    String profileId,
    Map<String, dynamic> data, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final model = HospitalModel.fromJson(data).copyWith(profileId: profileId);
    final saved = await saveHospitalModel(
      profileId,
      model,
      ownerUserId: ownerUserId,
      explicitOwnerUserId: explicitOwnerUserId,
    );
    return saved.toJson();
  }

  /// Saves a typed [HospitalModel] into Hive for [profileId].
  /// Synchronizes with backend REST API (H2 create / H4 update) when online.
  Future<HospitalModel> saveHospitalModel(
    String profileId,
    HospitalModel hospital, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final rawId = hospital.id.isNotEmpty
        ? hospital.id
        : 'hospital_${DateTime.now().microsecondsSinceEpoch}';
    final id = _normalizeHospitalId(rawId);

    final box = hiveService.userBox;
    final existingRaw = box.get(id) ?? box.get(rawId);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    final clientUuid =
        (hospital.clientUuid != null && hospital.clientUuid!.trim().isNotEmpty)
        ? hospital.clientUuid!.trim()
        : (existingUuid ?? UuidUtils.generateV4());

    var updated = hospital.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: clientUuid,
    );
    final payload = updated.toJson();

    await box.put(id, payload);

    final cleanId = IdUtils.unprefix(hospital.id).trim();
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
              final created = await supabaseRemoteDataSource!.createHospital(
                hospital: updated.copyWith(profileId: profileUuid),
                ownerUserId: effectiveOwnerUserId,
                profileId: profileUuid,
              );
              final newKey = _normalizeHospitalId(created.id);
              if (newKey != id) {
                await box.delete(id);
                await box.delete(rawId);
              }
              final savedModel = created.copyWith(
                id: newKey,
                profileId: profileId,
                clientUuid: clientUuid,
              );
              await box.put(newKey, savedModel.toJson());
              await _cleanupSyncQueue(newKey, created.id, clientUuid);
              return savedModel;
            } else {
              final updatedRemote =
                  await supabaseRemoteDataSource!.updateHospital(
                hospital: updated.copyWith(id: cleanId, profileId: profileUuid),
                ownerUserId: effectiveOwnerUserId,
                profileId: profileUuid,
              );
              final savedModel = updatedRemote.copyWith(
                id: id,
                profileId: profileId,
                clientUuid: clientUuid,
              );
              await box.put(id, savedModel.toJson());
              await _cleanupSyncQueue(id, cleanId, clientUuid);
              return savedModel;
            }
          } catch (e) {
            if (syncService != null) {
              await syncService!.addToQueue(
                SyncQueueItem(
                  id: 'sync_hosp_${DateTime.now().microsecondsSinceEpoch}',
                  entity: 'hospital',
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
                id: 'sync_hosp_${DateTime.now().microsecondsSinceEpoch}',
                entity: 'hospital',
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
          id: 'sync_hosp_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'hospital',
          operation: isNew ? 'create' : 'update',
          payload: updated.toJson(),
        ),
      );
    }

    return updated;
  }

  /// Returns all associated doctors practicing at [hospitalId] (direct + consultation).
  Future<List<DoctorModel>> getAssociatedDoctors(
    String profileId,
    String hospitalId,
  ) async {
    final hospital = await getHospitalById(profileId, hospitalId);
    final hospitalNameLower = hospital?.name.trim().toLowerCase() ?? '';
    final box = hiveService.userBox;

    final directDoctorIds = <String>{};
    final consultationDoctorIds = <String>{};
    final consultationDoctorNames = <String, String>{};

    // 1. Check all doctors for explicit hospitalIds
    for (final k in box.keys) {
      final kStr = k.toString();
      if (kStr.startsWith('doctor_')) {
        final val = box.get(k);
        if (val is Map) {
          final docProfId = (val['profile_id'] ?? val['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            docProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final doc = DoctorModel.fromJson(Map<String, dynamic>.from(val));
            if (IdUtils.contains(doc.hospitalIds, hospitalId)) {
              directDoctorIds.add(doc.id);
            }
          }
        }
      } else if (kStr.startsWith('consultation_') || kStr.startsWith('con_')) {
        final val = box.get(k);
        if (val is Map) {
          final cProfId = (val['profile_id'] ?? val['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            cProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final cHostId =
                val['hospital_id']?.toString() ?? val['hospitalId']?.toString();
            final cHostName =
                (val['hospital_name'] ?? val['hospitalName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (IdUtils.matches(cHostId, hospitalId) ||
                (cHostName.isNotEmpty && cHostName == hospitalNameLower)) {
              final docId =
                  val['doctor_id']?.toString() ?? val['doctorId']?.toString();
              final docName = (val['doctor_name'] ?? val['doctorName'] ?? '')
                  .toString()
                  .trim();
              if (docId != null && docId.isNotEmpty) {
                consultationDoctorIds.add(docId);
              } else if (docName.isNotEmpty) {
                consultationDoctorNames[docName.toLowerCase()] = docName;
              }
            }
          }
        }
      }
    }

    final allDoctorKeys = <String>{
      ...directDoctorIds,
      ...consultationDoctorIds,
    };
    final result = <DoctorModel>[];
    final addedIds = <String>{};

    for (final k in box.keys) {
      final kStr = k.toString();
      if (kStr.startsWith('doctor_')) {
        final val = box.get(k);
        if (val is Map) {
          final docProfId = (val['profile_id'] ?? val['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            docProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final doc = DoctorModel.fromJson(Map<String, dynamic>.from(val));
            if (allDoctorKeys.any(
                  (target) => IdUtils.matches(doc.id, target),
                ) ||
                consultationDoctorNames.containsKey(
                  doc.name.trim().toLowerCase(),
                )) {
              if (!addedIds.contains(doc.id)) {
                addedIds.add(doc.id);
                result.add(doc);
              }
            }
          }
        }
      }
    }

    // Include consultation doctors that may not have formal doctor directory entries
    for (final entry in consultationDoctorNames.entries) {
      final docName = entry.value;
      if (!result.any((d) => d.name.trim().toLowerCase() == entry.key)) {
        final fallbackId = 'doc_${entry.key.replaceAll(' ', '_')}';
        result.add(
          DoctorModel(
            id: fallbackId,
            profileId: profileId,
            name: docName,
            specialty: 'General Practice',
          ),
        );
      }
    }

    return result;
  }

  /// Calculates all dependent records linked to [hospitalId] for [profileId].
  Future<EntityDependencies> getHospitalDependencies(
    String profileId,
    String hospitalId,
  ) async {
    final hospital = await getHospitalById(profileId, hospitalId);
    if (hospital == null) {
      return const EntityDependencies();
    }

    final box = hiveService.userBox;
    final hospitalNameLower = hospital.name.trim().toLowerCase();

    final associatedDoctors = await getAssociatedDoctors(profileId, hospitalId);
    int consultationCount = 0;
    int reportCount = 0;
    int appointmentCount = 0;

    for (final k in box.keys) {
      final kStr = k.toString();
      if (kStr.startsWith('consultation_') || kStr.startsWith('con_')) {
        final cVal = box.get(k);
        if (cVal is Map) {
          final cProfId = (cVal['profile_id'] ?? cVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            cProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final cHostId =
                cVal['hospital_id']?.toString() ??
                cVal['hospitalId']?.toString();
            final cHostName =
                (cVal['hospital_name'] ?? cVal['hospitalName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (IdUtils.matches(cHostId, hospitalId) ||
                (cHostName.isNotEmpty && cHostName == hospitalNameLower)) {
              consultationCount++;
            }
          }
        }
      } else if (kStr.startsWith('report_') || kStr.startsWith('rep_')) {
        final rVal = box.get(k);
        if (rVal is Map) {
          final rProfId = (rVal['profile_id'] ?? rVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            rProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final rHostId =
                rVal['hospital_id']?.toString() ??
                rVal['hospitalId']?.toString();
            final rHostName =
                (rVal['hospital_name'] ??
                        rVal['hospital'] ??
                        rVal['hospitalName'] ??
                        '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (IdUtils.matches(rHostId, hospitalId) ||
                (rHostName.isNotEmpty && rHostName == hospitalNameLower)) {
              reportCount++;
            }
          }
        }
      } else if (kStr.startsWith('appointment_') || kStr.startsWith('apt_')) {
        final aVal = box.get(k);
        if (aVal is Map) {
          final aProfId = (aVal['profile_id'] ?? aVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            aProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final aHostId =
                aVal['hospital_id']?.toString() ??
                aVal['hospitalId']?.toString();
            final aHostName =
                (aVal['hospital_name'] ?? aVal['hospitalName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (IdUtils.matches(aHostId, hospitalId) ||
                (aHostName.isNotEmpty && aHostName == hospitalNameLower)) {
              appointmentCount++;
            }
          }
        }
      }
    }

    return EntityDependencies(
      doctors: associatedDoctors.length,
      consultations: consultationCount,
      reports: reportCount,
      appointments: appointmentCount,
    );
  }

  /// Deletes a hospital by [hospitalId] for [profileId] if there are no dependencies.
  /// Throws [ResourceHasDependenciesException] if dependencies exist.
  /// Synchronizes with backend REST API (H5) when online.
  Future<void> deleteHospital(
    String profileId,
    String hospitalId, {
    String? ownerUserId,
    String? explicitOwnerUserId,
  }) async {
    final key = _normalizeHospitalId(hospitalId);
    final box = hiveService.userBox;
    final val = box.get(key) ?? box.get(hospitalId);
    if (val == null) return;

    final deps = await getHospitalDependencies(profileId, hospitalId);
    if (deps.hasDependencies) {
      throw ResourceHasDependenciesException(
        'Cannot delete this hospital. This hospital has linked records and cannot be permanently deleted until they are removed or reassigned.',
        dependencyCounts: {
          'doctors': deps.doctors,
          'consultations': deps.consultations,
          'reports': deps.reports,
          'appointments': deps.appointments,
        },
      );
    }

    // 1. Delete from local Hive first
    await box.delete(key);
    await box.delete(hospitalId);
    final cleanId = IdUtils.unprefix(hospitalId).trim();
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
            await supabaseRemoteDataSource!.deleteHospital(
              hospitalId: cleanId,
              ownerUserId: effectiveOwnerUserId,
              profileId: profileUuid,
            );
          } catch (_) {}
        } else {
          if (syncService != null) {
            await syncService!.addToQueue(
              SyncQueueItem(
                id: 'sync_hosp_del_${DateTime.now().microsecondsSinceEpoch}',
                entity: 'hospital',
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
          id: 'sync_hosp_del_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'hospital',
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
          if (entity == 'hospitals' || entity == 'hospital') {
            final p = val['payload'];
            if (p is Map) {
              final pId = p['id']?.toString();
              if (pId == key ||
                  pId == hospitalId ||
                  (val['id']?.toString() == hospitalId)) {
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
