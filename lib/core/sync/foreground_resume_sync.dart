import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_lock.dart';
import '../../features/appointments/presentation/providers/appointment_providers.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/consultations/presentation/providers/consultation_providers.dart';
import '../../features/doctors/presentation/providers/doctors_providers.dart';
import '../../features/home/presentation/providers/clinical_sync_coordinator.dart';
import '../../features/hospitals/presentation/providers/hospitals_providers.dart';
import '../../features/medicines/presentation/providers/medicine_providers.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/reports/presentation/providers/reports_providers.dart';
import '../../features/vitals/presentation/providers/measurement_providers.dart';

/// Foreground half of the Phase 5 background/foreground handoff.
///
/// Called when the app returns to the foreground (`AppLifecycleState.resumed`)
/// or when connectivity is restored while the app is running. It:
///
///   1. bumps the **existing** [clinicalCacheRevisionProvider] once, so any
///      rows a WorkManager background pull merged into Hive while the app was
///      away become visible without the user leaving/reopening a screen — this
///      reuses the Phase 3 freshness signal, it does not add a new one;
///   2. if online, pushes the pending queue then pulls the active profile's
///      seven clinical domains (push-before-pull, same order as Force Sync),
///      guarded by the same cross-context [SyncLock] the background worker uses
///      so the two never pull concurrently. The repositories' own
///      `onPullMerged` hooks bump the revision again for any post-resume delta.
///
/// This runs from the foreground Riverpod container only. The WorkManager
/// isolate never calls it and never touches the container.
Future<void> runForegroundResumeSync(ProviderContainer container) async {
  // 1. Surface whatever a background worker already merged into Hive.
  try {
    container.read(clinicalCacheRevisionProvider.notifier).bump();
  } catch (_) {}

  bool online;
  try {
    online = await container
        .read(connectivityServiceProvider)
        .checkConnectivity();
  } catch (_) {
    return;
  }
  if (!online) return;

  // 2. Push first (its own lease; fast no-op when the queue is empty).
  try {
    await container.read(syncServiceProvider).syncPending();
  } catch (_) {}

  final profileId = container.read(activeProfileProvider)?.profileId;
  if (profileId == null || profileId.trim().isEmpty) return;

  // 3. Pull the active profile, holding the shared lease so a background
  //    worker's pull cannot run at the same time. If the lease is held, the
  //    other processor is already pulling — the bump above covers the UI.
  final lock = SyncLock(container.read(hiveServiceProvider).settingsBox);
  final token = await lock.tryAcquire();
  if (token == null) return;
  try {
    await Future.wait(
      <Future<void>>[
        container
            .read(consultationRepositoryProvider)
            .pullConsultations(profileId),
        container
            .read(appointmentRepositoryProvider)
            .pullAppointments(profileId),
        container.read(reportRepositoryProvider).pullReports(profileId),
        container.read(medicineRepositoryProvider).pullMedicines(profileId),
        container
            .read(measurementRepositoryProvider)
            .pullMeasurements(profileId),
        container.read(doctorRepositoryProvider).pullDoctors(profileId),
        container.read(hospitalRepositoryProvider).pullHospitals(profileId),
      ].map((f) => f.catchError((_) {})),
    );
  } finally {
    await lock.release(token);
  }

  debugPrint('[ForegroundResumeSync] completed for profile $profileId');
}
