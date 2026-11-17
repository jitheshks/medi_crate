import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/appointments/presentation/providers/appointment_providers.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/consultations/presentation/providers/consultation_providers.dart';
import '../../features/doctors/presentation/providers/doctors_providers.dart';
import '../../features/home/presentation/providers/clinical_sync_coordinator.dart';
import '../../features/home/presentation/providers/home_providers.dart';
import '../../features/hospitals/presentation/providers/hospitals_providers.dart';
import '../../features/insights/presentation/providers/insights_providers.dart';
import '../../features/medicines/presentation/providers/medicine_providers.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/reports/presentation/providers/reports_providers.dart';
import '../../features/vitals/presentation/providers/measurement_providers.dart';
import '../utils/id_utils.dart';
import 'sync_providers.dart';
import 'sync_rollout_config.dart';
import 'sync_service.dart';

/// Structured outcome of a manual synchronization operation.
class ManualSyncResult {
  final String message;
  final bool isSuccess;
  final int pullFailureCount;
  final int remainingActiveCount;
  final int remainingTotalCount;

  const ManualSyncResult({
    required this.message,
    required this.isSuccess,
    this.pullFailureCount = 0,
    this.remainingActiveCount = 0,
    this.remainingTotalCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManualSyncResult &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          isSuccess == other.isSuccess &&
          pullFailureCount == other.pullFailureCount &&
          remainingActiveCount == other.remainingActiveCount &&
          remainingTotalCount == other.remainingTotalCount;

  @override
  int get hashCode => Object.hash(
    message,
    isSuccess,
    pullFailureCount,
    remainingActiveCount,
    remainingTotalCount,
  );
}

/// AsyncNotifier managing manual "Force Sync Now" orchestration across
/// connectivity, push queue drain, active-profile clinical pulls, and cache invalidation.
///
/// Kept non-auto-disposed so in-flight synchronization continues safely even if the user
/// navigates away from DataSyncSettingsScreen.
class ManualSyncController extends AsyncNotifier<ManualSyncResult?> {
  bool _isExecuting = false;
  bool _isDisposed = false;

  @override
  ManualSyncResult? build() {
    _isDisposed = false;
    ref.onDispose(() => _isDisposed = true);
    return null;
  }

  /// Triggers force synchronization (P2-F7): pushes all pending mutations with force: true,
  /// pulls remote server records into Hive for the active profile only, refreshes caches,
  /// and constructs the truthful remaining queue status outcome.
  Future<ManualSyncResult> triggerForceSync() async {
    if (_isExecuting) {
      return state.value ??
          const ManualSyncResult(
            message: 'Synchronization already in progress.',
            isSuccess: true,
          );
    }

    _isExecuting = true;
    if (!_isDisposed) {
      state = const AsyncLoading();
    }
    final result = await _executeForceSync();
    if (!_isDisposed) {
      state = AsyncData(result);
    }
    _isExecuting = false;
    return result;
  }

  Future<ManualSyncResult> _executeForceSync() async {
    var message = 'All changes synchronized.';
    var isSuccess = true;
    var pullFailureCount = 0;
    var activeRemainingCount = 0;
    var allRemainingCount = 0;

    try {
      if (!SyncService.isRemoteSyncEnabled &&
          !SyncService.isControlledForegroundSyncEnabled) {
        return const ManualSyncResult(
          message:
              'Remote synchronization is disabled. Changes remain safely preserved on your device.',
          isSuccess: true,
        );
      }

      if (SyncRolloutConfig.isGlobalRolloutPaused) {
        return const ManualSyncResult(
          message:
              'Synchronization rollout is currently paused. '
              'Your changes remain safely preserved locally.',
          isSuccess: false,
        );
      }

      if (SyncRolloutConfig.isLocalKillSwitchActive) {
        return const ManualSyncResult(
          message:
              'Synchronization is currently disabled by local emergency controls. '
              'Your changes remain safely preserved locally.',
          isSuccess: false,
        );
      }

      final online = await ref
          .read(connectivityServiceProvider)
          .checkConnectivity();
      if (!online) {
        return const ManualSyncResult(
          message:
              'You are offline. Changes stay queued and sync automatically once '
              'you reconnect.',
          isSuccess: false,
        );
      }

      // 1. Pre-flight: Refresh profile mappings from server for current user
      final authUser = ref.read(authControllerProvider).user;
      if (authUser == null) {
        return const ManualSyncResult(
          message: 'Active authenticated session required to synchronize.',
          isSuccess: false,
        );
      }

      if (!SyncService.isRemoteSyncEnabled) {
        if (!SyncService.isEligibleTester(authUser.id)) {
          return const ManualSyncResult(
            message:
                'Foreground synchronization is currently restricted to authorized internal testers. '
                'Your changes remain safely preserved locally.',
            isSuccess: false,
          );
        }
        if (!ref.read(syncServiceProvider).isTesterOptedIn(authUser.id)) {
          return const ManualSyncResult(
            message:
                'Synchronization is available for your account but requires opt-in. '
                'Please enable synchronization in Data & Sync settings.',
            isSuccess: false,
          );
        }
      }

      try {
        await ref.read(profileRepositoryProvider).pullProfiles(authUser.id);
      } catch (_) {}

      // 2. Push pending mutations (force retries genuine transients; permanent
      //    400/404/422 dead-letters stay parked).
      await ref.read(syncServiceProvider).syncPending(
            force: true,
            explicitOwnerUserId: authUser.id,
          );

      // 3. Pull server -> Hive for the active profile only, then refresh the
      //    cache-first aggregate + list providers.
      final activeProfile = ref.read(activeProfileProvider);
      final profileId = activeProfile?.profileId;
      final serverProfileId = profileId != null
          ? IdUtils.resolveServerProfileId(
              profileBox: ref.read(hiveServiceProvider).profileBox,
              profileId: profileId,
            )
          : null;
      final isServerProfileReady = serverProfileId != null ||
          (profileId != null &&
              UuidUtils.isValidUuid(IdUtils.unprefix(profileId)));

      if (profileId != null && profileId.isNotEmpty) {
        if (isServerProfileReady) {
          final pulls = <Future<void>>[
            ref
                .read(consultationRepositoryProvider)
                .pullConsultations(profileId),
            ref.read(appointmentRepositoryProvider).pullAppointments(profileId),
            ref.read(reportRepositoryProvider).pullReports(profileId),
            ref.read(medicineRepositoryProvider).pullMedicines(profileId),
            ref.read(measurementRepositoryProvider).pullMeasurements(profileId),
            ref.read(doctorRepositoryProvider).pullDoctors(profileId),
            ref.read(hospitalRepositoryProvider).pullHospitals(profileId),
          ];
          await Future.wait(
            pulls.map((f) async {
              try {
                await f;
              } catch (_) {
                pullFailureCount++;
              }
            }),
          );
        }
        try {
          ref.read(clinicalCacheRevisionProvider.notifier).bump();
          ref.invalidate(homeSummaryProvider);
          ref.invalidate(insightsSummaryProvider);
        } catch (_) {}
      }

      if (_isDisposed) {
        return const ManualSyncResult(
          message: 'Synchronization was canceled.',
          isSuccess: false,
        );
      }

      // 4. Truthful status from the queue that actually remains for active profile.
      final allRemaining = ref
          .read(hiveServiceProvider)
          .syncQueueBox
          .values
          .whereType<Map>()
          .toList();

      final activeRemaining = allRemaining.where((raw) {
        return isQueueItemForProfile(
          rawItem: raw,
          activeProfileId: profileId,
          activeServerProfileId: serverProfileId,
          activeUserId: authUser.id,
          isPrimaryProfile: activeProfile?.isPrimary ?? false,
        );
      }).toList();

      activeRemainingCount = activeRemaining.length;
      allRemainingCount = allRemaining.length;

      if (activeRemaining.isEmpty) {
        if (!isServerProfileReady && profileId != null) {
          message =
              'Sync completed. Profile is being initialized with the server.';
        } else if (pullFailureCount > 0) {
          message =
              'Uploads synced, but some remote data could not be refreshed.';
        } else if (allRemaining.isEmpty) {
          message = 'All changes synchronized.';
        } else {
          message =
              'Active profile synchronized (${allRemaining.length} changes for other profiles pending).';
        }
      } else {
        final authBlocked = activeRemaining.any(
          (m) => m['status'] == 'auth_required',
        );
        final allDeadLettered = activeRemaining.every(
          (m) => (m['retryCount'] as int? ?? 0) >= 99,
        );
        final anyDeadLettered = activeRemaining.any(
          (m) => (m['retryCount'] as int? ?? 0) >= 99,
        );
        final allDeferred = activeRemaining.every(
          (m) => m['status'] == 'deferred',
        );
        if (authBlocked) {
          message =
              'Some changes need you to sign in again before they can sync.';
        } else if (allDeadLettered) {
          message =
              '${activeRemaining.length} change(s) were rejected by the server and '
              'need review.';
        } else if (allDeferred) {
          message =
              '${activeRemaining.length} change(s) are waiting on linked records and '
              'will sync shortly.';
        } else if (anyDeadLettered) {
          message =
              'Synchronization completed with ${activeRemaining.length} change(s) '
              'still pending; some need review.';
        } else {
          message =
              'Synchronization completed with ${activeRemaining.length} change(s) '
              'still pending.';
        }
      }
    } catch (_) {
      message = 'Synchronization could not be completed. It will retry automatically.';
      isSuccess = false;
    }

    return ManualSyncResult(
      message: message,
      isSuccess: isSuccess,
      pullFailureCount: pullFailureCount,
      remainingActiveCount: activeRemainingCount,
      remainingTotalCount: allRemainingCount,
    );
  }
}

final manualSyncControllerProvider =
    AsyncNotifierProvider<ManualSyncController, ManualSyncResult?>(
      ManualSyncController.new,
    );
