import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../connectivity/connectivity_service.dart';
import '../storage/hive_service.dart';
import '../utils/id_utils.dart';
import 'background_sync_service.dart';
import 'models/sync_queue_item.dart';
import 'queue_coalescer.dart';
import 'supabase_sync_coordinator.dart';
import 'sync_lock.dart';
import 'sync_rollout_config.dart';

/// SyncService processes pending offline mutations when internet connectivity is available.
///
/// Dispatches mutations exclusively through [SupabaseSyncCoordinator] to PostgreSQL
/// and Supabase Storage. When [isRemoteSyncEnabled] is false, all pending mutations
/// remain safely stored in Hive.
class SyncService {
  final HiveService hiveService;
  final ConnectivityService connectivityService;
  final void Function()? onSyncCompleted;
  final SupabaseSyncCoordinator? _supabaseSyncCoordinator;

  /// Whether remote push synchronization is enabled.
  /// Defaults to false. When false, pending mutations remain safely preserved in Hive.
  /// When true, mutations are dispatched exclusively through [_supabaseSyncCoordinator].
  static bool isRemoteSyncEnabled = false;

  /// Whether controlled foreground / manual synchronization is permitted.
  /// When true, explicit manual sync and foreground resume can sync for the
  /// authenticated user without enabling automatic background sync or global polling.
  static bool isControlledForegroundSyncEnabled = false;

  /// Registry of authorized internal tester Supabase user UUIDs.
  /// When [isRemoteSyncEnabled] is false and [isControlledForegroundSyncEnabled] is true,
  /// only users in this set who have explicitly opted in may synchronize mutations to Supabase.
  static Set<String> get authorizedTesterUserIds =>
      SyncRolloutConfig.authorizedTesterUuids;

  /// Checks if [userId] is an authorized internal tester.
  /// Enforces UUID format validation, global rollout pause, local kill switch,
  /// and presence in [SyncRolloutConfig.authorizedTesterUuids].
  static bool isEligibleTester(String? userId) {
    if (userId == null || userId.trim().isEmpty) return false;
    final cleanId = userId.trim();
    if (!UuidUtils.isValidUuid(cleanId)) return false;

    if (SyncRolloutConfig.isLocalKillSwitchActive) return false;
    if (SyncRolloutConfig.isGlobalRolloutPaused) return false;

    return SyncRolloutConfig.authorizedTesterUuids.contains(cleanId);
  }

  /// Authorizes an internal tester by Supabase UUID.
  /// Fails closed if UUID format is invalid.
  static bool authorizeTester(String userId) {
    return SyncRolloutConfig.authorizeTester(userId);
  }

  /// Revokes an internal tester's authorization.
  static void revokeTester(String userId) {
    SyncRolloutConfig.revokeTester(userId);
  }

  /// Clears all authorized testers (fail closed).
  static void clearAuthorizedTesters() {
    SyncRolloutConfig.clearAuthorizedTesters();
  }

  /// Checks whether [userId] has explicitly opted in to foreground synchronization.
  /// Scoped by user ID in [HiveService.settingsBox] to prevent cross-account leakage.
  bool isTesterOptedIn(String? userId) {
    if (userId == null || userId.trim().isEmpty) return false;
    final val = hiveService.settingsBox.get('sync_opt_in_${userId.trim()}');
    if (val is Map) {
      return val['opted_in'] == true;
    }
    return false;
  }

  /// Sets the opt-in preference for [userId] in [HiveService.settingsBox].
  Future<void> setTesterOptIn(String userId, bool optedIn) async {
    if (userId.trim().isEmpty) return;
    await hiveService.settingsBox.put(
      'sync_opt_in_${userId.trim()}',
      {
        'opted_in': optedIn,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

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
    this.onSyncCompleted,
    SupabaseSyncCoordinator? customSupabaseSyncCoordinator,
  }) : _supabaseSyncCoordinator = customSupabaseSyncCoordinator {
    _connectivitySub = connectivityService.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) {
        syncPending();
      }
    });
  }

  SupabaseSyncCoordinator? get supabaseSyncCoordinator =>
      _supabaseSyncCoordinator;

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
        final hasServerUuid =
            UuidUtils.isValidUuid(m['profile_id']?.toString()) ||
            UuidUtils.isValidUuid(m['id']?.toString()) ||
            UuidUtils.isValidUuid(m['server_profile_id']?.toString());
        return (sid != null || hasServerUuid, sid);
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
      final hasServerUuid = UuidUtils.isValidUuid(m['id']?.toString()) ||
          UuidUtils.isValidUuid(key.toString());
      return (sid != null || hasServerUuid, sid);
    }
    return (false, null);
  }

  /// Processes all queued mutations according to entity dependency order:
  /// Profiles (0) -> Hospitals (1) -> Doctors (2) -> Consultations (3) -> Reports (4) -> Appointments (5) -> Medicines (6) -> Vitals (7)
  ///
  /// When [isRemoteSyncEnabled] is false, remote synchronization is permitted ONLY
  /// when [isControlledForegroundSyncEnabled] is true, and the effective user is
  /// an authorized internal tester who has explicitly opted in.
  Future<void> syncPending({
    bool force = false,
    bool lockAlreadyHeld = false,
    String? explicitOwnerUserId,
  }) async {
    if (!isRemoteSyncEnabled) {
      if (!isControlledForegroundSyncEnabled) {
        debugPrint(
          '[SyncService] Remote synchronization is disabled (isRemoteSyncEnabled = false). '
          'Pending mutations remain safely preserved in Hive.',
        );
        return;
      }

      if (SyncRolloutConfig.isGlobalRolloutPaused) {
        debugPrint(
          '[SyncService] Remote synchronization blocked: global rollout is paused. '
          'Pending mutations remain safely preserved in Hive.',
        );
        return;
      }

      if (SyncRolloutConfig.isLocalKillSwitchActive) {
        debugPrint(
          '[SyncService] Remote synchronization blocked: local kill switch is active. '
          'Pending mutations remain safely preserved in Hive.',
        );
        return;
      }

      final coordinator = _supabaseSyncCoordinator;
      final effectiveUserId =
          explicitOwnerUserId ?? coordinator?.authenticatedUserId;
      if (effectiveUserId == null ||
          !isEligibleTester(effectiveUserId) ||
          !isTesterOptedIn(effectiveUserId)) {
        debugPrint(
          '[SyncService] Remote synchronization blocked: user $effectiveUserId is not an '
          'authorized internal tester or has not opted in. '
          'Pending mutations remain safely preserved in Hive.',
        );
        return;
      }
    }

    final coordinator = _supabaseSyncCoordinator;
    if (coordinator == null) {
      debugPrint(
        '[SyncService] SupabaseSyncCoordinator not configured. '
        'Deferring pending mutations safely.',
      );
      final box = hiveService.syncQueueBox;
      for (final raw in box.values) {
        final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw));
        if (item.status == 'pending' || item.status == 'failed') {
          final entity = item.entity.toLowerCase();
          final op = item.operation.toLowerCase();
          final payload = item.payload;
          final isPrimaryProfileDelete = (entity == 'profile' ||
                  entity == 'profiles') &&
              op == 'delete' &&
              (payload['is_primary'] == true ||
                  payload['relationship'] == 'Self' ||
                  item.id.startsWith('prof_primary_') ||
                  payload['id']?.toString().startsWith('prof_primary_') ==
                      true);

          if (isPrimaryProfileDelete) {
            item.status = 'failed';
            item.retryCount = 99;
            item.errorMessage =
                'Primary profile deletion rejected: prohibited by system invariant';
          } else {
            item.status = 'deferred';
          }
          item.claimToken = null;
          item.claimedAt = null;
          await box.put(item.id, item.toMap());
        }
      }
      return;
    }

    return syncPendingToSupabase(
      force: force,
      lockAlreadyHeld: lockAlreadyHeld,
      explicitOwnerUserId: explicitOwnerUserId,
    );
  }

  /// Synchronizes pending offline mutations natively to PostgreSQL and private
  /// Supabase Storage buckets via [SupabaseSyncCoordinator].
  ///
  /// Preserves:
  /// 1. Entity dependency ordering (Profiles -> Hospitals -> Doctors -> Consultations -> Reports -> Appointments -> Medicines -> Measurements).
  /// 2. Cross-isolate and cross-context mutual exclusion via [SyncLock].
  /// 3. Per-mutation lease claims via `claimToken` (P2-F8).
  /// 4. Exponential backoff and retry budgets (preserving deferred and auth_required items without burn).
  /// 5. Complete isolation with Supabase as the sole remote backend.
  Future<void> syncPendingToSupabase({
    bool force = false,
    bool lockAlreadyHeld = false,
    String? explicitOwnerUserId,
  }) async {
    final coordinator = _supabaseSyncCoordinator;
    if (coordinator == null) {
      debugPrint(
        '[SyncService] SupabaseSyncCoordinator not configured. '
        'Cannot synchronize pending mutations to Supabase.',
      );
      return;
    }

    if (_isSyncing) return;

    final lock = SyncLock(hiveService.settingsBox);
    final String? lockToken;
    if (lockAlreadyHeld) {
      lockToken = null;
    } else {
      lockToken = await lock.tryAcquire();
      if (lockToken == null) {
        return;
      }
    }

    _isSyncing = true;

    try {
      final isOnline = await connectivityService.checkConnectivity();
      if (!isOnline) return;

      final box = hiveService.syncQueueBox;
      final rawItems = box.values.toList();
      final items = rawItems
          .whereType<Map>()
          .map((m) => SyncQueueItem.fromMap(Map<String, dynamic>.from(m)))
          .toList();

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

        if (activeItem.retryCount >= 99) {
          continue;
        }

        if (!force &&
            activeItem.status == 'failed' &&
            activeItem.retryCount >= 5) {
          continue;
        }

        if (!force &&
            activeItem.status == 'failed' &&
            activeItem.lastAttemptAt != null) {
          final backoffSec = min(300, (1 << min(activeItem.retryCount, 6)) * 5);
          if (now.difference(activeItem.lastAttemptAt!).inSeconds < backoffSec) {
            continue;
          }
        }

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

        final confirmRaw = box.get(activeItem.id);
        if (confirmRaw is Map) {
          final confirm = SyncQueueItem.fromMap(
            Map<String, dynamic>.from(confirmRaw),
          );
          if (confirm.claimToken != _processorId) {
            continue;
          }
        }

        // Start a lightweight heartbeat timer for long-running operations (e.g. large file uploads)
        // to extend the claim timestamp and renew the isolate lease, preventing premature preemption.
        Timer? heartbeatTimer;
        heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
          try {
            final hbNow = DateTime.now();
            if (lockToken != null) {
              await lock.renew(lockToken);
            }
            final cur = box.get(activeItem.id);
            if (cur is Map && cur['claimToken'] == _processorId) {
              final updated = Map<String, dynamic>.from(cur);
              updated['claimedAt'] = hbNow.toIso8601String();
              await box.put(activeItem.id, updated);
            }
          } catch (_) {}
        });

        final bool success;
        try {
          success = await coordinator.processItem(
            item: activeItem,
            explicitOwnerUserId: explicitOwnerUserId,
          );
        } finally {
          heartbeatTimer.cancel();
        }

        final postCheckRaw = box.get(activeItem.id);
        if (postCheckRaw is Map) {
          final postCheck = SyncQueueItem.fromMap(
            Map<String, dynamic>.from(postCheckRaw),
          );
          if (postCheck.claimToken != null &&
              postCheck.claimToken != _processorId) {
            continue;
          }
        }

        if (success) {
          syncedCount++;
          await box.delete(activeItem.id);
        } else if (activeItem.status == 'auth_required') {
          activeItem.claimToken = null;
          activeItem.claimedAt = null;
          await box.put(activeItem.id, activeItem.toMap());
          // Stop further queue processing immediately when unauthenticated or logged out
          break;
        } else if (activeItem.status == 'deferred') {
          activeItem.claimToken = null;
          activeItem.claimedAt = null;
          await box.put(activeItem.id, activeItem.toMap());
        } else {
          if (activeItem.retryCount < 5) {
            activeItem.status = 'failed';
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
      debugPrint('[SyncService] Supabase sync processing error: $e');
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

  void dispose() {
    _connectivitySub?.cancel();
  }
}
