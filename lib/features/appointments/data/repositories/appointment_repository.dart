import 'dart:async';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_profile_query_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/pulled_record_comparison.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/supabase_appointment_remote_data_source.dart';
import '../models/appointment_model.dart';

/// AppointmentRepository manages profile-scoped doctor appointments in Hive storage
/// with Supabase synchronization.
class AppointmentRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final SupabaseAppointmentRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal: invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  AppointmentRepository({
    required this.hiveService,
    this.syncService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    this.onPullMerged,
    dynamic remoteDataSource,
  });

  /// Normalizes key prefix for appointment storage.
  String _normalizeAppointmentId(String rawId) {
    if (rawId.startsWith('appointment_')) return rawId;
    if (rawId.startsWith('apt_')) return 'appointment_${rawId.substring(4)}';
    return 'appointment_$rawId';
  }

  String? _resolveCurrentUserId() {
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

  /// Retrieves raw maps for appointments belonging to [profileId].
  Future<List<Map<String, dynamic>>> getAppointments(String profileId) async {
    return HiveProfileQueryHelper.getRecordsForProfile(
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      keyPrefix: 'appointment_',
      profileId: profileId,
    );
  }

  /// Fetches typed [AppointmentModel] list belonging to [profileId] immediately from local Hive cache (AP1),
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<AppointmentModel>> getAppointmentModels(
    String profileId, {
    String? status,
    int? doctorId,
    int? hospitalId,
    String? from,
    String? to,
    String? sort,
    int limit = 20,
  }) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (supabaseRemoteDataSource != null) {
      unawaited(
        pullAppointments(
          profileId,
          status: status,
          doctorId: doctorId,
          hospitalId: hospitalId,
          from: from,
          to: to,
          sort: sort,
          limit: limit,
        ),
      );
    }

    // 2. Return local Hive records immediately
    final rawList = await getAppointments(profileId);
    var models = rawList.map((m) => AppointmentModel.fromJson(m)).toList();
    if (status != null && status.isNotEmpty) {
      models = models
          .where((a) => a.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (doctorId != null) {
      models = models
          .where(
            (a) =>
                a.doctorId == doctorId.toString() ||
                IdUtils.toServerIntId(a.doctorId ?? '') == doctorId,
          )
          .toList();
    }
    if (hospitalId != null) {
      models = models
          .where(
            (a) =>
                a.hospitalId == hospitalId.toString() ||
                IdUtils.toServerIntId(a.hospitalId ?? '') == hospitalId,
          )
          .toList();
    }
    models.sort((a, b) => a.date.compareTo(b.date));
    return models;
  }

  /// Performs background pull-sync for appointments belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullAppointments(
    String profileId, {
    String? status,
    int? doctorId,
    int? hospitalId,
    String? from,
    String? to,
    String? sort,
    int limit = 20,
  }) {
    if (supabaseRemoteDataSource == null) {
      return Future.value();
    }
    final existing = _inFlightPulls[profileId];
    if (existing != null) return existing;

    final future = _executePullAppointments(
      profileId,
      status: status,
      doctorId: doctorId,
      hospitalId: hospitalId,
      from: from,
      to: to,
      sort: sort,
      limit: limit,
    );
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullAppointments(
    String profileId, {
    String? status,
    int? doctorId,
    int? hospitalId,
    String? from,
    String? to,
    String? sort,
    int limit = 20,
  }) async {
    if (supabaseRemoteDataSource != null) {
      try {
        final ownerUserId = _resolveCurrentUserId();
        if (ownerUserId == null || ownerUserId.isEmpty) return;

        final profileUuid = _resolveProfileUuid(profileId, ownerUserId);
        if (profileUuid == null || profileUuid.isEmpty) return;

        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (!isOnline) return;

        final remoteList = await supabaseRemoteDataSource!.fetchAppointments(
          ownerUserId: ownerUserId,
          profileId: profileUuid,
          status: status,
          doctorId: doctorId?.toString(),
          hospitalId: hospitalId?.toString(),
          from: from,
          to: to,
          limit: limit,
        );

        final box = hiveService.userBox;
        var pulledChanged = false;
        for (final remoteModel in remoteList) {
          final serverId = remoteModel.id;
          final key = _normalizeAppointmentId(serverId);

          // Guard against overwriting pending local mutations (I2-C2)
          if (PendingMutationGuard.hasPendingMutation(
            syncQueueBox: hiveService.syncQueueBox,
            profileBox: hiveService.profileBox,
            entity: 'appointment',
            profileId: profileId,
            remoteId: key,
            clientUuid: remoteModel.clientUuid,
          )) {
            continue;
          }

          final localRaw = box.get(key);
          String? preservedDeptId;
          String? preservedUuid;
          if (localRaw is Map) {
            preservedDeptId = localRaw['department_id']?.toString();
            preservedUuid =
                localRaw['client_uuid']?.toString() ??
                localRaw['clientUuid']?.toString();
          }

          final merged = remoteModel.copyWith(
            id: key,
            profileId: profileId,
            departmentId: preservedDeptId ?? remoteModel.departmentId,
            clientUuid: preservedUuid ?? remoteModel.clientUuid,
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
      } catch (_) {
        // Fallback seamlessly to local Hive storage on network / API error
        // DO NOT fall back to legacy remoteDataSource!
      } finally {
        _inFlightPulls.remove(profileId);
      }
      return;
    }
  }

  /// Fetches a single typed [AppointmentModel] by ID for [profileId] with remote sync (AP3).
  Future<AppointmentModel?> getAppointmentById(
    String profileId,
    String appointmentId,
  ) async {
    final key = _normalizeAppointmentId(appointmentId);
    final box = hiveService.userBox;
    var val =
        box.get(key) ??
        box.get(appointmentId) ??
        box.get(IdUtils.unprefix(appointmentId));

    AppointmentModel? localModel;
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        localModel = AppointmentModel.fromJson(map);
      }
    }

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId();
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;

      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            final cleanId = IdUtils.unprefix(appointmentId);
            final remoteModel =
                await supabaseRemoteDataSource!.getAppointmentById(
              appointmentId: cleanId,
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            if (remoteModel != null) {
              final remoteKey = _normalizeAppointmentId(remoteModel.id);
              if (!PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'appointment',
                profileId: profileId,
                remoteId: remoteKey,
                clientUuid: remoteModel.clientUuid,
              )) {
                final merged = remoteModel.copyWith(
                  id: remoteKey,
                  profileId: profileId,
                  departmentId:
                      localModel?.departmentId ?? remoteModel.departmentId,
                  clientUuid:
                      localModel?.clientUuid ?? remoteModel.clientUuid,
                );
                await box.put(remoteKey, merged.toJson());
                return merged;
              }
            }
          } catch (_) {}
        }
      }
    }

    if (localModel != null) return localModel;

    final rawList = await getAppointments(profileId);
    final all = rawList.map((m) => AppointmentModel.fromJson(m)).toList();
    try {
      return all.firstWhere(
        (a) => IdUtils.matches(a.id, appointmentId) || a.id == key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves a raw map appointment into Hive for [profileId] and queues sync.
  Future<Map<String, dynamic>> saveAppointment(
    String profileId,
    Map<String, dynamic> data,
  ) async {
    final rawId =
        data['id'] ?? 'appointment_${DateTime.now().microsecondsSinceEpoch}';
    final id = _normalizeAppointmentId(rawId.toString());

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

    final isNumericServerId =
        IdUtils.toServerIntId(IdUtils.unprefix(id)) != null;
    await box.put(id, payload);
    if (rawId.toString().isNotEmpty && rawId.toString() != id) {
      await box.delete(rawId);
    }

    if (syncService != null) {
      final queuePayload = Map<String, dynamic>.from(payload);
      queuePayload['id'] = id;
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_appointment_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'appointments',
          operation: isNumericServerId ? 'update' : 'create',
          payload: queuePayload,
          createdAt: DateTime.now(),
        ),
      );
    }

    return payload;
  }

  /// Saves a typed [AppointmentModel] into Hive for [profileId] and queues sync (AP2/AP4).
  Future<AppointmentModel> saveAppointmentModel(
    String profileId,
    AppointmentModel model,
  ) async {
    final rawId = model.id.isNotEmpty
        ? model.id
        : 'appointment_${DateTime.now().microsecondsSinceEpoch}';
    final id = _normalizeAppointmentId(rawId);

    final box = hiveService.userBox;
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
        : (existingUuid ?? UuidUtils.generateV4());

    final updated = model.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: clientUuid,
      updatedAt: DateTime.now(),
    );

    final cleanId = IdUtils.unprefix(rawId);
    final isExistingUuid = UuidUtils.isValidUuid(cleanId);

    await box.put(id, updated.toJson());
    if (rawId.isNotEmpty && rawId != id) {
      await box.delete(rawId);
    }

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId();
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;

      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            AppointmentModel remoteResult;
            if (isExistingUuid) {
              remoteResult = await supabaseRemoteDataSource!.updateAppointment(
                appointment: updated,
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
              final normKey = _normalizeAppointmentId(remoteResult.id);
              final synced = remoteResult.copyWith(id: normKey);
              await box.put(normKey, synced.toJson());
              return synced;
            } else {
              remoteResult = await supabaseRemoteDataSource!.createAppointment(
                appointment: updated,
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
              final normKey = _normalizeAppointmentId(remoteResult.id);
              if (rawId.isNotEmpty && rawId != normKey) {
                await box.delete(rawId);
                await box.delete(id);
              }
              final synced = remoteResult.copyWith(id: normKey);
              await box.put(normKey, synced.toJson());
              return synced;
            }
          } catch (_) {
            // Queue for offline sync on error
            await _queueAppointmentMutation(
              operation: isExistingUuid ? 'update' : 'create',
              payload: updated.toJson(),
            );
            return updated;
          }
        }
      }

      // Offline or unresolved profile
      await _queueAppointmentMutation(
        operation: isExistingUuid ? 'update' : 'create',
        payload: updated.toJson(),
      );
      return updated;
    }

    await _queueAppointmentMutation(
      operation: isExistingUuid ? 'update' : 'create',
      payload: updated.toJson(),
    );

    return updated;
  }

  Future<void> _queueAppointmentMutation({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    if (syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_appointment_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'appointments',
          operation: operation,
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Updates status of an appointment and queues sync (AP4).
  Future<AppointmentModel?> updateAppointmentStatus(
    String profileId,
    String appointmentId,
    String newStatus,
  ) async {
    final appointment = await getAppointmentById(profileId, appointmentId);
    if (appointment == null) return null;

    final updated = appointment.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    return saveAppointmentModel(profileId, updated);
  }

  /// Deletes an appointment by [appointmentId] for [profileId] and queues remote sync (AP5).
  Future<void> deleteAppointment(String profileId, String appointmentId) async {
    final key = _normalizeAppointmentId(appointmentId);
    final box = hiveService.userBox;
    final cleanId = IdUtils.unprefix(appointmentId);
    final val = box.get(key) ?? box.get(appointmentId) ?? box.get(cleanId);
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        await box.delete(key);
      }
    }
    await box.delete(appointmentId);
    if (cleanId.isNotEmpty) {
      await box.delete(cleanId);
      await box.delete('apt_$cleanId');
    }

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId();
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
            await supabaseRemoteDataSource!.deleteAppointment(
              appointmentId: cleanId,
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            deletedRemotely = true;
          } catch (_) {
            deletedRemotely = false;
          }
        }
      }

      if (!deletedRemotely && isUuid) {
        await syncService?.addToQueue(
          SyncQueueItem(
            id: 'sync_appointment_${DateTime.now().millisecondsSinceEpoch}',
            entity: 'appointments',
            operation: 'delete',
            payload: {'id': key, 'profile_id': profileId},
            createdAt: DateTime.now(),
          ),
        );
      }
      return;
    }

    if (syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_appointment_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'appointments',
          operation: 'delete',
          payload: {'id': key, 'profile_id': profileId},
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Retrieves convertible appointments for [profileId] (not cancelled and not linked to any consultation).
  /// Enforces profile isolation by verifying that both appointment and consultation belong to [profileId].
  Future<List<AppointmentModel>> getConvertibleAppointmentModels(
    String profileId,
    List<dynamic> existingConsultations,
  ) async {
    final appointments = await getAppointmentModels(profileId);
    return appointments.where((a) {
      if (!IdUtils.matchesProfileId(
        a.profileId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return false;
      }
      if (a.isCancelled) return false;
      final isLinked = existingConsultations.any((c) {
        final cProfId = (c is Map)
            ? (c['profile_id'] ?? c['profileId'])?.toString()
            : (c.profileId as String?);
        if (!IdUtils.matchesProfileId(
          cProfId,
          profileId,
          profileBox: hiveService.profileBox,
        )) {
          return false;
        }
        final cAptId = (c is Map)
            ? (c['appointment_id'] ?? c['appointmentId'])?.toString()
            : (c.appointmentId as String?);
        if (cAptId == null || cAptId.isEmpty) return false;
        return IdUtils.matches(cAptId, a.id);
      });
      return !isLinked;
    }).toList();
  }
}
