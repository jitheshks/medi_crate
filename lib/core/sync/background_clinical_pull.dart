import 'package:flutter/foundation.dart';

import '../connectivity/connectivity_service.dart';
import '../storage/hive_service.dart';
import '../storage/secure_storage_service.dart';
import '../supabase/supabase_config.dart';
import 'sync_service.dart';

import '../../features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import '../../features/appointments/data/repositories/appointment_repository.dart';
import '../../features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import '../../features/consultations/data/repositories/consultation_repository.dart';
import '../../features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import '../../features/doctors/data/repositories/doctor_repository.dart';
import '../../features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import '../../features/hospitals/data/repositories/hospital_repository.dart';
import '../../features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import '../../features/medicines/data/repositories/medicine_repository.dart';
import '../../features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import '../../features/reports/data/repositories/report_repository.dart';
import '../../features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import '../../features/vitals/data/repositories/measurement_repository.dart';

/// Pulls the seven clinical domains (Doctors, Hospitals, Consultations,
/// Appointments, Reports, Medicines, Vitals) for every locally-known profile,
/// **reusing the existing repository pull methods** — no second data layer.
///
/// This is the server -> Hive half of the background synchronization cycle
/// (the push half stays in [SyncService.syncPending]). It is designed to run
/// inside the WorkManager isolate, so it deliberately:
///
///   * takes no Riverpod `Ref` and touches no provider / UI state,
///   * constructs each repository **without** an `onPullMerged` callback — the
///     foreground `clinicalCacheRevisionProvider` is bumped later, from the
///     foreground, when the app next resumes (see `runForegroundResumeSync`),
///   * writes only into the shared Hive boxes via the unchanged repo merge
///     logic, so [PendingMutationGuard] still protects queued mutations,
///   * swallows per-domain / per-profile errors so one failing endpoint never
///     aborts the rest.
///
/// Profile isolation: each `pullX` call is scoped to one canonical `profileId`
/// and the server request is filtered by that profile's resolved server id, so
/// a profile's rows can only be written back into that same profile's scope.
class BackgroundClinicalPull {
  const BackgroundClinicalPull();

  /// Runs the pull for all known profiles. No-op when offline, when there is no
  /// stored session, or when there are no local profiles yet.
  ///
  /// [pullersFor] is a test seam: when supplied it returns the per-domain pull
  /// futures for a profile id instead of the real repositories. Production code
  /// leaves it null.
  Future<void> run({
    required HiveService hiveService,
    required ConnectivityService connectivityService,
    SecureStorageService? secureStorage,
    @visibleForTesting
    Iterable<Future<void>> Function(String profileId)? pullersFor,
  }) async {
    // Skip remote pull when remote synchronization is disabled
    if (!SyncService.isRemoteSyncEnabled) {
      debugPrint(
        '[BackgroundClinicalPull] Skipping remote pull: remote synchronization is disabled.',
      );
      return;
    }

    try {
      if (!await connectivityService.checkConnectivity()) return;
    } catch (_) {
      return;
    }

    // No authenticated session -> nothing to pull. Never destroy local data.
    try {
      final token = await (secureStorage ?? SecureStorageService())
          .getAuthToken();
      if (token == null || token.isEmpty) return;
    } catch (_) {
      // If secure storage is unreadable in this isolate, fall through.
    }

    final profileIds = _knownProfileIds(hiveService);
    if (profileIds.isEmpty) return;

    if (pullersFor != null) {
      for (final profileId in profileIds) {
        await Future.wait(
          pullersFor(profileId).map((f) => f.catchError((_) {})),
        );
      }
      return;
    }

    final client = SupabaseConfig.isInitialized ? SupabaseConfig.client : null;

    final doctors = DoctorRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseDoctorRemoteDataSource(customClient: client),
    );
    final hospitals = HospitalRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseHospitalRemoteDataSource(customClient: client),
    );
    final consultations = ConsultationRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseConsultationRemoteDataSource(client: client),
    );
    final appointments = AppointmentRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseAppointmentRemoteDataSource(client: client),
    );
    final reports = ReportRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseReportRemoteDataSource(client: client),
    );
    final medicines = MedicineRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseMedicineRemoteDataSource(client: client),
    );
    final vitals = MeasurementRepository(
      hiveService: hiveService,
      connectivityService: connectivityService,
      supabaseRemoteDataSource:
          SupabaseVitalsRemoteDataSource(client: client),
    );

    for (final profileId in profileIds) {
      await Future.wait(
        <Future<void>>[
          doctors.pullDoctors(profileId),
          hospitals.pullHospitals(profileId),
          consultations.pullConsultations(profileId),
          appointments.pullAppointments(profileId),
          reports.pullReports(profileId),
          medicines.pullMedicines(profileId),
          vitals.pullMeasurements(profileId),
        ].map((f) => f.catchError((_) {})),
      );
    }

    debugPrint(
      '[BackgroundClinicalPull] pulled ${profileIds.length} profile(s): '
      '${profileIds.join(", ")}',
    );
  }

  /// Canonical profile ids from the Hive profile box scoped to the authenticated user.
  /// Uses the existing identity system (the box key IS the canonical `profileId`);
  /// no synthetic or `?? 1` fallback.
  List<String> _knownProfileIds(HiveService hiveService) {
    final ids = <String>{};
    try {
      String? currentUserId;
      final rawUser = hiveService.userBox.get('current_user');
      if (rawUser is Map) {
        currentUserId = (rawUser['id'] ?? rawUser['userId'])?.toString();
      }
      String? activeProfileId;
      final rawActive = hiveService.userBox.get('active_profile_id');
      if (rawActive != null) {
        activeProfileId =
            (rawActive['id'] ??
                    rawActive['profileId'] ??
                    rawActive['profile_id'])
                ?.toString();
      }

      final box = hiveService.profileBox;
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          final ownerId = (raw['owner_user_id'] ?? raw['ownerUserId'])
              ?.toString();
          final pid = (raw['profileId'] ?? raw['profile_id'] ?? key)
              ?.toString();
          if (pid == null || pid.trim().isEmpty) continue;

          if (currentUserId != null && currentUserId.isNotEmpty) {
            if (ownerId != null && ownerId.isNotEmpty) {
              if (ownerId == currentUserId) {
                ids.add(pid.trim());
              }
            } else if (activeProfileId != null &&
                (pid == activeProfileId || key.toString() == activeProfileId)) {
              ids.add(pid.trim());
            }
          } else {
            if (activeProfileId != null) {
              if (pid == activeProfileId || key.toString() == activeProfileId) {
                ids.add(pid.trim());
              }
            } else {
              ids.add(pid.trim());
            }
          }
        } else {
          final keyStr = key.toString();
          if (currentUserId == null ||
              keyStr.contains(currentUserId) ||
              (activeProfileId != null && keyStr == activeProfileId)) {
            ids.add(keyStr);
          }
        }
      }
    } catch (_) {
      // Box unavailable in this isolate -> caller treats as "nothing to pull".
    }
    return ids.toList();
  }
}
