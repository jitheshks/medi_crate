import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/id_utils.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../medicines/presentation/providers/medicine_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../vitals/presentation/providers/measurement_providers.dart';

/// Monotonic counter bumped once a background clinical pull for the active
/// profile has merged server records into Hive. Cache-first aggregate screens
/// (Home, Insights) watch this so freshly-synced data surfaces without the user
/// having to open every feature screen first.
class ClinicalCacheRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final clinicalCacheRevisionProvider =
    NotifierProvider<ClinicalCacheRevision, int>(ClinicalCacheRevision.new);

/// In-flight clinical domain sync futures per profileId to avoid duplicate concurrent syncs.
final _inFlightClinicalSyncs = <String, Future<void>>{};

/// Fires a single, non-blocking background pull of every clinical domain for the
/// currently active profile (each repository dedupes concurrent pulls), then
/// bumps [clinicalCacheRevisionProvider].
///
/// Re-runs automatically whenever [activeProfileProvider] changes (profile
/// switch / initial resolution). Offline is a no-op — the individual repository
/// pulls already short-circuit offline, and skipping the bump avoids a
/// redundant aggregate recompute.
final clinicalSyncCoordinatorProvider = Provider<void>((ref) {
  // Watch profile identity and serverProfileId so when serverProfileId is resolved from
  // pullProfiles or initial profile creation, clinical sync runs without waiting for restart.
  final activeProfileKey = ref.watch(
    activeProfileProvider.select(
      (p) => p == null ? null : '${p.profileId}_${p.serverProfileId}',
    ),
  );
  if (activeProfileKey == null || activeProfileKey.isEmpty) return;

  final profileId = ref.read(activeProfileProvider)?.profileId;
  if (profileId == null || profileId.isEmpty) return;

  var disposed = false;
  ref.onDispose(() => disposed = true);

  unawaited(_syncClinicalDomains(ref, profileId, () => disposed));
});

Future<void> _syncClinicalDomains(
  Ref ref,
  String profileId,
  bool Function() isDisposed,
) async {
  try {
    final isOnline = await ref
        .read(connectivityServiceProvider)
        .checkConnectivity();
    if (!isOnline || isDisposed()) return;
  } catch (_) {
    return;
  }

  final existingFuture = _inFlightClinicalSyncs[profileId];
  if (existingFuture != null) {
    await existingFuture;
    return;
  }

  final syncFuture = _executeClinicalSync(ref, profileId, isDisposed);
  _inFlightClinicalSyncs[profileId] = syncFuture;
  try {
    await syncFuture;
  } finally {
    if (identical(_inFlightClinicalSyncs[profileId], syncFuture)) {
      _inFlightClinicalSyncs.remove(profileId);
    }
  }
}

Future<void> _executeClinicalSync(
  Ref ref,
  String profileId,
  bool Function() isDisposed,
) async {
  final hive = ref.read(hiveServiceProvider);
  var numericProfileId = IdUtils.resolveServerProfileId(
    profileBox: hive.profileBox,
    profileId: profileId,
  );

  // If serverProfileId is not yet resolved (e.g. fresh install first login),
  // reconcile profiles first to obtain the numeric serverProfileId.
  if (numericProfileId == null) {
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      try {
        await ref.read(profileRepositoryProvider).pullProfiles(user.id);
        if (isDisposed()) return;
        final updated =
            await ref.read(profileRepositoryProvider).getProfiles(user.id);
        if (updated.isNotEmpty) {
          try {
            ref.read(profilesListProvider.notifier).setProfiles(updated);
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  if (isDisposed()) return;

  final pulls = <Future<void>>[
    ref.read(consultationRepositoryProvider).pullConsultations(profileId),
    ref.read(appointmentRepositoryProvider).pullAppointments(profileId),
    ref.read(reportRepositoryProvider).pullReports(profileId),
    ref.read(medicineRepositoryProvider).pullMedicines(profileId),
    ref.read(measurementRepositoryProvider).pullMeasurements(profileId),
    ref.read(doctorRepositoryProvider).pullDoctors(profileId),
    ref.read(hospitalRepositoryProvider).pullHospitals(profileId),
  ];

  await Future.wait(pulls.map((f) => f.catchError((_) {})));

  if (isDisposed()) return;
  try {
    // Guard against a profile switch that happened mid-pull.
    if (ref.read(activeProfileProvider)?.profileId != profileId) return;
    ref.read(clinicalCacheRevisionProvider.notifier).bump();
  } catch (_) {
    // Provider container / coordinator was disposed while awaiting.
  }
}
