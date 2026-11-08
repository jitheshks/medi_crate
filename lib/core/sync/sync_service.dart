import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/appointments/data/datasources/remote/appointment_remote_data_source.dart';
import '../../features/appointments/data/sync/appointment_sync_handler.dart';
import '../../features/consultations/data/datasources/remote/consultation_remote_data_source.dart';
import '../../features/consultations/data/sync/consultation_sync_handler.dart';
import '../../features/doctors/data/datasources/remote/doctor_remote_data_source.dart';
import '../../features/doctors/data/sync/doctor_sync_handler.dart';
import '../../features/hospitals/data/datasources/remote/hospital_remote_data_source.dart';
import '../../features/hospitals/data/sync/hospital_sync_handler.dart';
import '../../features/medicines/data/datasources/remote/medicine_remote_data_source.dart';
import '../../features/medicines/data/sync/medicine_sync_handler.dart';
import '../../features/profile/data/datasources/remote/profile_remote_data_source.dart';
import '../../features/profile/data/datasources/remote/user_remote_data_source.dart';
import '../../features/profile/data/models/profile_model.dart';
import '../../features/profile/data/sync/profile_sync_handler.dart';
import '../../features/reports/data/datasources/remote/report_remote_data_source.dart';
import '../../features/reports/data/sync/report_sync_handler.dart';
import '../../features/vitals/data/datasources/remote/vitals_remote_data_source.dart';
import '../../features/vitals/data/sync/measurement_sync_handler.dart';
import '../api/api_client.dart';
import '../connectivity/connectivity_service.dart';
import '../storage/hive_service.dart';
import '../utils/id_utils.dart';
import 'background_sync_service.dart';
import 'models/sync_queue_item.dart';
import 'queue_coalescer.dart';
import 'sync_lock.dart';

/// SyncService processes pending offline mutations when internet connectivity is available.
class SyncService {
  final HiveService hiveService;
  final ConnectivityService connectivityService;
  final ApiClient? apiClient;
  final void Function()? onSyncCompleted;
  final AppointmentRemoteDataSource? _appointmentRemoteDataSource;
  final ConsultationRemoteDataSource? _consultationRemoteDataSource;
  final DoctorRemoteDataSource? _doctorRemoteDataSource;
  final HospitalRemoteDataSource? _hospitalRemoteDataSource;
  final ReportRemoteDataSource? _reportRemoteDataSource;
  final MedicineRemoteDataSource? _medicineRemoteDataSource;
  final VitalsRemoteDataSource? _vitalsRemoteDataSource;
  final ProfileRemoteDataSource? _profileRemoteDataSource;
  final UserRemoteDataSource? _userRemoteDataSource;

  /// Whether remote push synchronization against legacy Laravel endpoints is suspended.
  /// Option D target: Suspended to protect offline mutations until Phase 4 Supabase backend.
  static bool isRemotePushSuspended = true;

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySub;

  /// Opaque identity for this SyncService instance. Stamped on a queue item
  /// while it is being processed so a second processor (the WorkManager
  /// background isolate runs its own SyncService) does not send the same
  /// mutation concurrently (P2-F8).
  final String _processorId =
      'proc_${DateTime.now().microsecondsSinceEpoch}_'
      '${UuidUtils.generateV4().substring(0, 8)}';

  SyncService({
    required this.hiveService,
    required this.connectivityService,
    this.apiClient,
    this.onSyncCompleted,
    AppointmentRemoteDataSource? customAppointmentRemoteDataSource,
    ConsultationRemoteDataSource? customConsultationRemoteDataSource,
    DoctorRemoteDataSource? customDoctorRemoteDataSource,
    HospitalRemoteDataSource? customHospitalRemoteDataSource,
    ReportRemoteDataSource? customReportRemoteDataSource,
    MedicineRemoteDataSource? customMedicineRemoteDataSource,
    VitalsRemoteDataSource? customVitalsRemoteDataSource,
    ProfileRemoteDataSource? customProfileRemoteDataSource,
    UserRemoteDataSource? customUserRemoteDataSource,
  }) : _appointmentRemoteDataSource = customAppointmentRemoteDataSource,
       _consultationRemoteDataSource = customConsultationRemoteDataSource,
       _doctorRemoteDataSource = customDoctorRemoteDataSource,
       _hospitalRemoteDataSource = customHospitalRemoteDataSource,
       _reportRemoteDataSource = customReportRemoteDataSource,
       _medicineRemoteDataSource = customMedicineRemoteDataSource,
       _vitalsRemoteDataSource = customVitalsRemoteDataSource,
       _profileRemoteDataSource = customProfileRemoteDataSource,
       _userRemoteDataSource = customUserRemoteDataSource {
    _connectivitySub = connectivityService.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) {
        syncPending();
      }
    });
  }

  ConsultationRemoteDataSource? get consultationRemoteDataSource {
    if (_consultationRemoteDataSource != null) {
      return _consultationRemoteDataSource;
    }
    if (apiClient != null) {
      return ConsultationRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  DoctorRemoteDataSource? get doctorRemoteDataSource {
    if (_doctorRemoteDataSource != null) {
      return _doctorRemoteDataSource;
    }
    if (apiClient != null) {
      return DoctorRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  HospitalRemoteDataSource? get hospitalRemoteDataSource {
    if (_hospitalRemoteDataSource != null) {
      return _hospitalRemoteDataSource;
    }
    if (apiClient != null) {
      return HospitalRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  ReportRemoteDataSource? get reportRemoteDataSource {
    if (_reportRemoteDataSource != null) {
      return _reportRemoteDataSource;
    }
    if (apiClient != null) {
      return ReportRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  AppointmentRemoteDataSource? get appointmentRemoteDataSource {
    if (_appointmentRemoteDataSource != null) {
      return _appointmentRemoteDataSource;
    }
    if (apiClient != null) {
      return AppointmentRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  MedicineRemoteDataSource? get medicineRemoteDataSource {
    if (_medicineRemoteDataSource != null) {
      return _medicineRemoteDataSource;
    }
    if (apiClient != null) {
      return MedicineRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  VitalsRemoteDataSource? get vitalsRemoteDataSource {
    if (_vitalsRemoteDataSource != null) {
      return _vitalsRemoteDataSource;
    }
    if (apiClient != null) {
      return VitalsRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  ProfileRemoteDataSource? get profileRemoteDataSource {
    if (_profileRemoteDataSource != null) {
      return _profileRemoteDataSource;
    }
    if (apiClient != null) {
      return ProfileRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  UserRemoteDataSource? get userRemoteDataSource {
    if (_userRemoteDataSource != null) {
      return _userRemoteDataSource;
    }
    if (apiClient != null) {
      return UserRemoteDataSource(apiClient: apiClient!);
    }
    return null;
  }

  Future<void> addToQueue(SyncQueueItem item) async {
    final box = hiveService.syncQueueBox;

    // P2-F4: fold the incoming mutation into the existing queue using a stable
    // (entity + client_uuid) identity. An offline create-then-edit(s) collapses
    // to a single create with the latest state; a create-then-delete that never
    // reached the server cancels out entirely; a delete for a server-backed
    // entity is rewritten onto the server id. Legacy timestamp-keyed items with
    // no client_uuid/id remain individually processed.
    final existing = <QueueEntry>[];
    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is Map) {
        try {
          existing.add(
            QueueEntry(
              k,
              SyncQueueItem.fromMap(Map<String, dynamic>.from(raw)),
            ),
          );
        } catch (_) {
          // Undecodable legacy entry: leave it untouched.
        }
      }
    }

    final serverRecord = _resolveServerRecord(item);
    final result = QueueCoalescer.coalesce(
      existing: existing,
      incoming: item,
      now: DateTime.now(),
      leaseDuration: SyncLock.leaseDuration,
      hasServerRecord: serverRecord.$1,
      resolvedServerId: serverRecord.$2,
    );

    for (final k in result.keysToDelete) {
      await box.delete(k);
    }
    if (result.putItem != null) {
      await box.put(result.putKey, result.putItem!.toMap());
    }

    // The mutation fully cancelled a pending offline create and nothing else is
    // queued: no sync needed.
    if (result.putItem == null && box.isEmpty) return;

    final isOnline = await connectivityService.checkConnectivity();
    if (isOnline) {
      syncPending();
    } else {
      // Schedule WorkManager one-time background task when offline
      BackgroundSyncService.scheduleOneTimeSync();
    }
  }

  /// Hive key prefix for a clinical entity's records in [HiveService.userBox].
  static String? _userBoxPrefix(String entity) {
    switch (entity.trim().toLowerCase()) {
      case 'doctor':
      case 'doctors':
        return 'doctor_';
      case 'hospital':
      case 'hospitals':
        return 'hospital_';
      case 'consultation':
      case 'consultations':
        return 'consultation_';
      case 'appointment':
      case 'appointments':
        return 'appointment_';
      case 'report':
      case 'reports':
        return 'report_';
      case 'medicine':
      case 'medicines':
        return 'medicine_';
      case 'measurement':
      case 'measurements':
      case 'vital':
      case 'vitals':
        return 'measurement_';
      default:
        return null;
    }
  }

  /// Looks up whether the entity referenced by [item] already has a
  /// server-assigned id in local Hive, matched by `client_uuid`. Returns
  /// `(reachedServer, serverId?)`. Used by the queue coalescer to distinguish
  /// CASE B (never synced -> cancel) from CASE D (synced -> delete by id).
  (bool, int?) _resolveServerRecord(SyncQueueItem item) {
    final entity = item.entity.trim().toLowerCase();
    final uuid = (item.payload['client_uuid'] ?? item.payload['clientUuid'])
        ?.toString()
        .trim();

    if (entity == 'profile' ||
        entity == 'profiles' ||
        entity == 'family_member' ||
        entity == 'family_members') {
      if (uuid == null || uuid.isEmpty) return (false, null);
      for (final raw in hiveService.profileBox.values) {
        final m = Map<String, dynamic>.from(raw);
        final cu = (m['client_uuid'] ?? m['clientUuid'])?.toString().trim();
        if (cu != uuid) continue;
        final sid = IdUtils.toServerIntId(
          m['server_profile_id'] ?? m['serverProfileId'],
        );
        return (sid != null, sid);
      }
      return (false, null);
    }

    final prefix = _userBoxPrefix(entity);
    if (prefix == null || uuid == null || uuid.isEmpty) return (false, null);
    for (final key in hiveService.userBox.keys) {
      if (!key.toString().startsWith(prefix)) continue;
      final raw = hiveService.userBox.get(key);
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final cu = (m['client_uuid'] ?? m['clientUuid'])?.toString().trim();
      if (cu != uuid) continue;
      final sid =
          IdUtils.toServerIntId(m['id']) ??
          IdUtils.toServerIntId(key.toString());
      return (sid != null, sid);
    }
    return (false, null);
  }

  /// Resolves a numeric server id for a DELETE queue item whose payload carries
  /// a local id or only a `client_uuid`. Scans [userBox] for a record with a
  /// matching `client_uuid` that already holds a server id.
  int? _resolveDeleteServerId(String prefix, Map<String, dynamic> payload) {
    final direct = IdUtils.toServerIntId(payload['id']);
    if (direct != null) return direct;
    final uuid = (payload['client_uuid'] ?? payload['clientUuid'])
        ?.toString()
        .trim();
    if (uuid == null || uuid.isEmpty) return null;
    final userBox = hiveService.userBox;
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

  /// Processes all queued mutations according to entity dependency order:
  /// Hospitals (0) -> Doctors (1) -> Consultations (2) -> Reports (3) -> Others (4)
  ///
  /// [lockAlreadyHeld] is set by the WorkManager background worker, which claims
  /// the [SyncLock] lease once for its whole push+pull cycle and then calls this
  /// method inside that lease. When true this method neither acquires nor
  /// releases the lease (doing so would see its own valid lease and abort).
  Future<void> syncPending({
    bool force = false,
    bool lockAlreadyHeld = false,
  }) async {
    // Option D isolation: Suspend legacy Laravel pushes to preserve pending mutations for Phase 4
    if (isRemotePushSuspended) {
      debugPrint(
        '[SyncService] Remote push skipped: legacy Laravel sync suspended. '
        'Pending mutations preserved in Hive for Phase 4.',
      );
      return;
    }

    if (_isSyncing) return;

    // Cross-context guard: the WorkManager background isolate runs a separate
    // SyncService whose _isSyncing flag is not shared with this one. The Hive
    // lease lock prevents both from draining the same queue at once; a stale
    // lease (crashed holder) auto-expires so sync is never permanently blocked.
    final lock = SyncLock(hiveService.settingsBox);
    final String? lockToken;
    if (lockAlreadyHeld) {
      lockToken = null; // caller owns the lease; do not re-acquire or release
    } else {
      lockToken = await lock.tryAcquire();
      if (lockToken == null) {
        // Another sync processor holds a valid lease. It will finish the queue.
        return;
      }
    }

    _isSyncing = true;

    try {
      final isOnline = await connectivityService.checkConnectivity();
      if (!isOnline) return;

      // Pre-flight profile resolution: if profileRemoteDataSource is available and
      // any profile in profileBox lacks server_profile_id, reconcile family members first.
      final pRemote = profileRemoteDataSource;
      if (pRemote != null) {
        try {
          final profileBox = hiveService.profileBox;
          final hasUnresolvedProfiles = profileBox.values.any((raw) {
            final sId = raw['server_profile_id'] ?? raw['serverProfileId'];
            return sId == null;
          });
          if (hasUnresolvedProfiles) {
            final members = await pRemote.fetchFamilyMembers();
            if (members.isNotEmpty) {
              for (final m in members) {
                final rawId = m['id'];
                final serverId = rawId is int
                    ? rawId
                    : int.tryParse(rawId?.toString() ?? '');
                if (serverId == null) continue;
                final isPrimary =
                    m['is_primary'] == true ||
                    m['is_primary'] == 1 ||
                    m['is_primary'] == '1' ||
                    m['is_primary'] == 'true' ||
                    (ProfileRelationships.normalize(
                          (m['relationship'] ?? '').toString(),
                        ) ==
                        ProfileRelationships.self);

                for (final key in profileBox.keys) {
                  final raw = profileBox.get(key);
                  if (raw is Map) {
                    final map = Map<String, dynamic>.from(raw);
                    final keyStr = key.toString();
                    if (isPrimary &&
                        (keyStr.startsWith('prof_primary_') ||
                            map['is_primary'] == true ||
                            map['isPrimary'] == true)) {
                      if (map['server_profile_id'] != serverId ||
                          map['serverProfileId'] != serverId) {
                        map['server_profile_id'] = serverId;
                        map['serverProfileId'] = serverId;
                        await profileBox.put(key, map);
                      }
                    } else {
                      final clientUuid =
                          map['client_uuid'] ?? map['clientUuid'];
                      final mUuid = m['client_uuid'] ?? m['clientUuid'];
                      if (clientUuid != null &&
                          mUuid != null &&
                          clientUuid.toString().trim() ==
                              mUuid.toString().trim()) {
                        if (map['server_profile_id'] != serverId ||
                            map['serverProfileId'] != serverId) {
                          map['server_profile_id'] = serverId;
                          map['serverProfileId'] = serverId;
                          await profileBox.put(key, map);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[SyncService] Pre-flight profile resolution note: $e');
        }
      }

      final box = hiveService.syncQueueBox;
      final rawItems = box.values.toList();
      final items = rawItems
          .whereType<Map>()
          .map((m) => SyncQueueItem.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      // Sort by dependency priority then insertion time
      items.sort((a, b) {
        final priorityA = _entityPriority(a.entity, a.operation);
        final priorityB = _entityPriority(b.entity, b.operation);
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        return a.createdAt.compareTo(b.createdAt);
      });

      final now = DateTime.now();
      int syncedCount = 0;

      for (final item in items) {
        final latestRaw = box.get(item.id);
        final activeItem = latestRaw != null
            ? SyncQueueItem.fromMap(Map<String, dynamic>.from(latestRaw))
            : item;

        // Dead-letter: permanent validation failure (400/404/422) or unsupported
        // entity, marked with retryCount == 99. Never auto-retried, not even by
        // a forced sync.
        if (activeItem.retryCount >= 99) {
          continue;
        }

        // Transient retry budget exhausted: skip until an explicit forced sync
        // re-attempts it (F2: force must be able to retry genuine transients).
        if (!force &&
            activeItem.status == 'failed' &&
            activeItem.retryCount >= 5) {
          continue;
        }

        // Exponential backoff check for transient & auth errors (bypassed if force == true).
        // A 'deferred' item (dependency not ready) is intentionally NOT backed off
        // so it can resolve as soon as its dependency syncs.
        if (!force &&
            (activeItem.status == 'failed' ||
                activeItem.status == 'auth_required') &&
            activeItem.lastAttemptAt != null) {
          final backoffSec = min(300, (1 << min(activeItem.retryCount, 6)) * 5);
          if (now.difference(activeItem.lastAttemptAt!).inSeconds <
              backoffSec) {
            continue;
          }
        }

        // P2-F8: claim the item before dispatch. If another processor holds a
        // fresh claim (it started between our lease acquisition and now, across
        // isolates where the lease write is not instantly visible), yield it.
        // A claim older than the lease belongs to a crashed processor and is
        // reclaimed here, so the queue never deadlocks.
        final claimNow = DateTime.now();
        final ownedByOther =
            activeItem.claimToken != null &&
            activeItem.claimToken != _processorId &&
            activeItem.claimedAt != null &&
            claimNow.difference(activeItem.claimedAt!) < SyncLock.leaseDuration;
        if (ownedByOther) {
          continue;
        }

        activeItem.claimToken = _processorId;
        activeItem.claimedAt = claimNow;
        activeItem.status = 'syncing';
        activeItem.lastAttemptAt = claimNow;
        await box.put(activeItem.id, activeItem.toMap());

        // Confirm the claim stuck (last-writer-wins detection under a race).
        final confirmRaw = box.get(activeItem.id);
        if (confirmRaw is Map) {
          final confirm = SyncQueueItem.fromMap(
            Map<String, dynamic>.from(confirmRaw),
          );
          if (confirm.claimToken != _processorId) {
            continue;
          }
        }

        final success = await _processItem(activeItem);

        if (success) {
          syncedCount++;
          await box.delete(activeItem.id);
        } else if (activeItem.status == 'deferred') {
          // A required dependency (typically an unresolved server profile id) is
          // not available yet. This is NOT a failure: keep the queue item
          // intact, do NOT consume the retry budget, and leave it eligible for
          // the next sync pass once dependency ordering resolves it.
          activeItem.claimToken = null;
          activeItem.claimedAt = null;
          await box.put(activeItem.id, activeItem.toMap());
        } else {
          // Genuine failure. Dead-letter items (retryCount == 99 for
          // 400/404/422) are preserved as-is; transient failures accrue toward
          // the retry cap.
          if (activeItem.retryCount < 5) {
            if (activeItem.status != 'auth_required') {
              activeItem.status = 'failed';
            }
            activeItem.retryCount += 1;
          }
          activeItem.claimToken = null;
          activeItem.claimedAt = null;
          await box.put(activeItem.id, activeItem.toMap());
        }
      }

      if (syncedCount > 0) {
        try {
          onSyncCompleted?.call();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SyncService] Sync processing error: $e');
    } finally {
      _isSyncing = false;
      if (lockToken != null) await lock.release(lockToken);
    }
  }

  int _entityPriority(String entity, [String? operation]) {
    final e = entity.toLowerCase();
    final op = operation?.toLowerCase();
    if (e == 'profile' ||
        e == 'profiles' ||
        e == 'family_members' ||
        e == 'family_member') {
      if (op == 'create') {
        // Dependency chain: profile CREATE (0) -> hospitals (1) -> doctors (2)
        // -> consultations (3) -> reports (4) -> appointments (5) -> medicines
        // (6) -> vitals (7). A family member's server profile id must exist
        // before any of its profile-scoped clinical records can be pushed.
        return 0;
      } else if (op == 'delete') {
        return 9;
      } else {
        return 8; // update
      }
    }
    switch (e) {
      case 'hospitals':
      case 'hospital':
        return 1;
      case 'doctors':
      case 'doctor':
        return 2;
      case 'consultations':
      case 'consultation':
        return 3;
      case 'reports':
      case 'report':
        return 4;
      case 'appointments':
      case 'appointment':
        return 5;
      case 'medicines':
      case 'medicine':
        return 6;
      case 'measurement':
      case 'measurements':
      case 'vitals':
      case 'vital':
        return 7;
      default:
        return 10;
    }
  }

  Future<bool> _processItem(SyncQueueItem item) async {
    final entity = item.entity.toLowerCase();
    if (entity == 'consultations' || entity == 'consultation') {
      return _processConsultationSync(item);
    }
    if (entity == 'reports' || entity == 'report') {
      return _processReportSync(item);
    }
    if (entity == 'appointments' || entity == 'appointment') {
      return _processAppointmentSync(item);
    }
    if (entity == 'doctors' || entity == 'doctor') {
      return _processDoctorSync(item);
    }
    if (entity == 'hospitals' || entity == 'hospital') {
      return _processHospitalSync(item);
    }
    if (entity == 'medicines' || entity == 'medicine') {
      return _processMedicineSync(item);
    }
    if (entity == 'measurement' ||
        entity == 'measurements' ||
        entity == 'vitals' ||
        entity == 'vital') {
      return _processMeasurementSync(item);
    }
    if (entity == 'profile' ||
        entity == 'profiles' ||
        entity == 'family_members' ||
        entity == 'family_member') {
      return _processProfileSync(item);
    }

    // Explicit failure for unsupported entities (dead-letter; do not delete silently from queue)
    item.status = 'failed';
    item.retryCount = 99;
    item.errorMessage = 'Unsupported entity: ${item.entity}';
    return false;
  }

  /// Processes Consultation synchronization with actual API dispatch and Hive ID synchronization.
  Future<bool> _processConsultationSync(SyncQueueItem item) async {
    final remote = consultationRemoteDataSource;
    if (remote == null) {
      debugPrint(
        '[SyncService] ConsultationRemoteDataSource not available, completing local sync pass.',
      );
      return true;
    }

    return ConsultationSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  Future<bool> _processDoctorSync(SyncQueueItem item) async {
    final remote = doctorRemoteDataSource;
    if (remote == null) {
      debugPrint('[SyncService] DoctorRemoteDataSource not available.');
      return true;
    }

    return DoctorSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      syncQueueBox: hiveService.syncQueueBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  Future<bool> _processHospitalSync(SyncQueueItem item) async {
    final remote = hospitalRemoteDataSource;
    if (remote == null) {
      debugPrint('[SyncService] HospitalRemoteDataSource not available.');
      return true;
    }

    return HospitalSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      syncQueueBox: hiveService.syncQueueBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  /// Processes Report synchronization with actual API dispatch and Hive ID synchronization.
  Future<bool> _processReportSync(SyncQueueItem item) async {
    final remote = reportRemoteDataSource;
    if (remote == null) {
      debugPrint(
        '[SyncService] ReportRemoteDataSource not available, completing local sync pass.',
      );
      return true;
    }

    return ReportSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  /// Processes Appointment synchronization with actual API dispatch and Hive ID synchronization.
  Future<bool> _processAppointmentSync(SyncQueueItem item) async {
    final remote = appointmentRemoteDataSource;
    if (remote == null) {
      debugPrint('[SyncService] No AppointmentRemoteDataSource available.');
      return false;
    }

    return AppointmentSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  Future<bool> _processMedicineSync(SyncQueueItem item) async {
    final remote = medicineRemoteDataSource;
    if (remote == null) {
      debugPrint('[SyncService] MedicineRemoteDataSource not available.');
      return true;
    }

    return MedicineSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  Future<bool> _processMeasurementSync(SyncQueueItem item) async {
    final remote = vitalsRemoteDataSource;
    if (remote == null) {
      debugPrint('[SyncService] VitalsRemoteDataSource not available.');
      return true;
    }

    return MeasurementSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      resolveDeleteServerId: (prefix, payload) =>
          _resolveDeleteServerId(prefix, payload),
    );
  }

  Future<bool> _processProfileSync(SyncQueueItem item) async {
    final remote = profileRemoteDataSource;
    if (remote == null) {
      debugPrint('[SyncService] ProfileRemoteDataSource not available.');
      return true;
    }

    return ProfileSyncHandler.process(
      item: item,
      remoteDataSource: remote,
      userRemoteDataSource: userRemoteDataSource,
      profileBox: hiveService.profileBox,
    );
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
