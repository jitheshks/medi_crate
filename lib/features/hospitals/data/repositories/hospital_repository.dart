import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/api/list_pull_support.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../doctors/data/models/doctor_hospital_relation.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../datasources/remote/hospital_remote_data_source.dart';
import '../models/hospital_model.dart';

/// HospitalRepository manages profile-associated healthcare facilities,
/// coordinates offline-first Hive caching with live REST API synchronization,
/// and enforces relational dependency validation.
class HospitalRepository {
  final HiveService hiveService;
  final HospitalRemoteDataSource? remoteDataSource;
  final ConnectivityService? connectivityService;
  final SyncService? syncService;

  /// Post-pull freshness signal (Phase 3): invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  /// Whether the last completed pull retrieved the full server dataset
  /// (`received >= data.total`). Exposed for tests.
  bool lastPullComplete = true;

  HospitalRepository({
    required this.hiveService,
    this.remoteDataSource,
    this.connectivityService,
    this.syncService,
    this.onPullMerged,
  });

  String _normalizeHospitalId(String rawId) {
    if (rawId.startsWith('hospital_')) return rawId;
    return 'hospital_$rawId';
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
    if (remoteDataSource != null) {
      unawaited(pullHospitals(profileId));
    }

    // 2. Return local Hive records immediately
    final rawList = await getHospitals(profileId);
    return rawList.map((m) => HospitalModel.fromJson(m)).toList();
  }

  /// Performs background pull-sync for hospitals belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullHospitals(String profileId) {
    if (remoteDataSource == null) return Future.value();
    final existing = _inFlightPulls[profileId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullHospitals(profileId);
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullHospitals(String profileId) async {
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

      final remoteHospitals = await fetchCompleteList(
        (limit, onTotal) => remoteDataSource!.fetchHospitals(
          profileId: numericProfileId,
          limit: limit,
          onTotal: onTotal,
        ),
        onComplete: (c) => lastPullComplete = c,
      );
      final box = hiveService.userBox;
      var pulledChanged = false;

      for (final raw in remoteHospitals) {
        final remoteModel = HospitalModel.fromJson(raw);
        final key = remoteModel.id;

        // Guard against overwriting pending local mutations (I2-C2)
        if (PendingMutationGuard.hasPendingMutation(
          syncQueueBox: hiveService.syncQueueBox,
          profileBox: hiveService.profileBox,
          entity: 'hospital',
          profileId: profileId,
          remoteId: key,
          clientUuid: remoteModel.clientUuid,
        )) {
          continue;
        }

        // Search for existing local entry: by exact key, un-prefixed key, clientUuid, or matching name for temporary keys
        dynamic matchingKey;
        Map<String, dynamic>? existingMap;

        final directMatch = box.get(key) ?? box.get(IdUtils.unprefix(key));
        if (directMatch is Map) {
          matchingKey = box.containsKey(key) ? key : IdUtils.unprefix(key);
          existingMap = Map<String, dynamic>.from(directMatch);
        } else {
          for (final k in box.keys) {
            final kStr = k.toString();
            if (kStr.startsWith('hospital_')) {
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

        String? clientUuid;
        String? localNotes;
        DateTime? createdAt;

        if (existingMap != null) {
          clientUuid =
              existingMap['client_uuid']?.toString() ??
              existingMap['clientUuid']?.toString();
          localNotes = existingMap['notes']?.toString();
          if (existingMap['created_at'] != null) {
            createdAt = DateTime.tryParse(existingMap['created_at'].toString());
          }

          // If the matching local key is an old temporary key, clean it up and update references
          if (matchingKey != null && matchingKey.toString() != key) {
            final oldKeyStr = matchingKey.toString();
            final oldIdStr = IdUtils.unprefix(oldKeyStr);
            await box.delete(matchingKey);
            await box.delete(oldIdStr);

            // Re-point doctor references in userBox
            for (final dKey in box.keys) {
              final dKeyStr = dKey.toString();
              if (dKeyStr.startsWith('doctor_')) {
                final dVal = box.get(dKey);
                if (dVal is Map) {
                  final dMap = Map<String, dynamic>.from(dVal);
                  final dProf = (dMap['profile_id'] ?? dMap['profileId'])
                      ?.toString();
                  if (IdUtils.matchesProfileId(
                    dProf,
                    profileId,
                    profileBox: hiveService.profileBox,
                  )) {
                    final hIds = dMap['hospital_ids'] ?? dMap['hospitalIds'];
                    if (hIds is List) {
                      bool changed = false;
                      final updatedHIds = hIds.map((h) {
                        final hStr = h.toString();
                        if (hStr == oldKeyStr ||
                            hStr == oldIdStr ||
                            IdUtils.matches(hStr, oldKeyStr)) {
                          changed = true;
                          return key;
                        }
                        return hStr;
                      }).toList();
                      if (changed) {
                        dMap['hospital_ids'] = updatedHIds;
                        await box.put(dKey, dMap);
                      }
                    }
                  }
                }
              }
            }

            // Re-point consultation references in userBox
            final serverIntId = IdUtils.toServerIntId(IdUtils.unprefix(key));
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
                    final cHosp =
                        cMap['hospital_id']?.toString() ??
                        cMap['hospitalId']?.toString();
                    if (cHosp == oldKeyStr ||
                        cHosp == oldIdStr ||
                        IdUtils.matches(cHosp, oldKeyStr)) {
                      cMap['hospital_id'] = serverIntId ?? key;
                      await box.put(cKey, cMap);
                    }
                  }
                }
              }
            }
          }
        }

        final merged = remoteModel.copyWith(
          profileId: profileId,
          clientUuid:
              clientUuid ?? remoteModel.clientUuid ?? UuidUtils.generateV4(),
          notes: (localNotes != null && localNotes.isNotEmpty)
              ? localNotes
              : remoteModel.notes,
          createdAt: createdAt ?? remoteModel.createdAt ?? DateTime.now(),
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
    } catch (e) {
      debugPrint('[HospitalRepository] Remote sync skipped or failed: $e');
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Strictly profile-scoped hospital lookup by [hospitalId].
  Future<HospitalModel?> getHospitalById(
    String profileId,
    String hospitalId,
  ) async {
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

    // Try remote single lookup if online (H3)
    if (remoteDataSource != null) {
      try {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          final cleanId = IdUtils.unprefix(hospitalId);
          final raw = await remoteDataSource!.getHospital(cleanId);
          if (raw.isNotEmpty) {
            final remoteModel = HospitalModel.fromJson(
              raw,
            ).copyWith(profileId: profileId);

            // Guard against overwriting pending local mutations (I2-C2)
            if (!PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'hospital',
              profileId: profileId,
              remoteId: remoteModel.id,
              clientUuid: remoteModel.clientUuid,
            )) {
              await box.put(remoteModel.id, remoteModel.toJson());
              return remoteModel;
            }
          }
        }
      } catch (e) {
        debugPrint('[HospitalRepository] Single hospital fetch failed: $e');
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
    Map<String, dynamic> data,
  ) async {
    final model = HospitalModel.fromJson(data).copyWith(profileId: profileId);
    final saved = await saveHospitalModel(profileId, model);
    return saved.toJson();
  }

  /// Saves a typed [HospitalModel] into Hive for [profileId].
  /// Synchronizes with backend REST API (H2 create / H4 update) when online.
  Future<HospitalModel> saveHospitalModel(
    String profileId,
    HospitalModel hospital,
  ) async {
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

    final cleanId = IdUtils.unprefix(hospital.id);
    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    bool syncedRemotely = false;
    if (remoteDataSource != null) {
      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (isOnline) {
        final apiPayload = updated.toApiJson();
        try {
          if (isNumericServerId) {
            // H4: Update Hospital (POST /hospitals/{id})
            final remoteRes = await remoteDataSource!.updateHospital(
              serverIntId.toString(),
              apiPayload,
            );
            final serverHospital = HospitalModel.fromJson(remoteRes);
            updated = updated.copyWith(
              name: serverHospital.name,
              type: serverHospital.type ?? updated.type,
              address: serverHospital.address ?? updated.address,
              phone: serverHospital.phone ?? updated.phone,
              email: serverHospital.email ?? updated.email,
              website: serverHospital.website ?? updated.website,
              city: serverHospital.city ?? updated.city,
              state: serverHospital.state ?? updated.state,
              country: serverHospital.country ?? updated.country,
            );
            await box.put(id, updated.toJson());
            syncedRemotely = true;
          } else {
            // H2: Add Hospital (POST /hospitals)
            final remoteRes = await remoteDataSource!.addHospital(apiPayload);
            final serverHospital = HospitalModel.fromJson(remoteRes);
            final serverRawId = serverHospital.id.isNotEmpty
                ? serverHospital.id
                : (remoteRes['id']?.toString() ?? '');

            if (serverRawId.isNotEmpty) {
              final newId = _normalizeHospitalId(serverRawId);
              if (newId != id) {
                await box.delete(id);
                await box.delete(rawId);
              }
              updated = updated.copyWith(
                id: newId,
                name: serverHospital.name,
                type: serverHospital.type ?? updated.type,
                address: serverHospital.address ?? updated.address,
                phone: serverHospital.phone ?? updated.phone,
                email: serverHospital.email ?? updated.email,
                website: serverHospital.website ?? updated.website,
                city: serverHospital.city ?? updated.city,
                state: serverHospital.state ?? updated.state,
                country: serverHospital.country ?? updated.country,
              );
              await box.put(newId, updated.toJson());
              syncedRemotely = true;
            }
          }
        } catch (_) {
          syncedRemotely = false;
        }
      }
    }

    if (!syncedRemotely && syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_hosp_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'hospitals',
          operation: isNumericServerId ? 'update' : 'create',
          payload: payload,
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
  Future<void> deleteHospital(String profileId, String hospitalId) async {
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

    final cleanId = IdUtils.unprefix(hospitalId);
    final serverIntId = IdUtils.toServerIntId(cleanId);
    final isNumericServerId = serverIntId != null;

    bool deletedRemotely = false;
    if (remoteDataSource != null && isNumericServerId) {
      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (isOnline) {
        try {
          await remoteDataSource!.deleteHospital(serverIntId.toString());
          deletedRemotely = true;
        } catch (_) {
          deletedRemotely = false;
        }
      }
    }

    if (!deletedRemotely && syncService != null && isNumericServerId) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_hosp_del_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'hospitals',
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
