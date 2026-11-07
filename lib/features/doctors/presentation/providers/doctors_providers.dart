import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/mutable_state_notifier.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';
import 'package:medi_crate/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
import 'package:medi_crate/features/doctors/data/datasources/remote/doctor_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_hospital_relation.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/doctors/data/repositories/doctor_repository.dart';
import 'package:medi_crate/features/home/presentation/providers/clinical_sync_coordinator.dart';
import 'package:medi_crate/features/home/presentation/providers/home_providers.dart';
import 'package:medi_crate/features/hospitals/presentation/providers/hospitals_providers.dart';
import 'package:medi_crate/features/insights/presentation/providers/insights_providers.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/reports/presentation/providers/reports_providers.dart';

final doctorRemoteDataSourceProvider = Provider<DoctorRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DoctorRemoteDataSource(apiClient: apiClient);
});

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  final remoteDataSource = ref.watch(doctorRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  return DoctorRepository(
    hiveService: hiveService,
    remoteDataSource: remoteDataSource,
    connectivityService: connectivityService,
    syncService: syncService,
    onPullMerged: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
});

final doctorsListProvider =
    AsyncNotifierProvider<DoctorsListNotifier, List<DoctorModel>>(() {
      return DoctorsListNotifier();
    });

class DoctorsListNotifier extends AsyncNotifier<List<DoctorModel>> {
  @override
  Future<List<DoctorModel>> build() async {
    // P2-F6: recompute from Hive when a background/pull sync merged new server
    // records for the active profile. This only re-reads local cache — the pull
    // itself is fired (and de-duped) inside the repository and never bumps the
    // revision, so there is no rebuild -> pull -> rebuild loop.
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];
    final repository = ref.watch(doctorRepositoryProvider);
    return await repository.getDoctorModels(activeProfile.profileId);
  }

  Future<void> refresh() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }

  Future<DoctorModel?> saveDoctor(DoctorModel doctor) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return null;
    final repository = ref.read(doctorRepositoryProvider);
    final saved = await repository.saveDoctorModel(
      activeProfile.profileId,
      doctor,
    );
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(hospitalsListProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
    return saved;
  }

  Future<void> deleteDoctor(String doctorId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;
    final repository = ref.read(doctorRepositoryProvider);
    await repository.deleteDoctor(activeProfile.profileId, doctorId);
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(consultationsListNotifierProvider);
    ref.invalidate(reportsListNotifierProvider);
    ref.invalidate(appointmentsListProvider);
    ref.invalidate(hospitalsListProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }
}

final doctorSearchQueryProvider = mutableStateProvider<String>('');

/// Sort option provider for doctors ('newest', 'oldest', 'alphabetical').
final doctorSortProvider = mutableStateProvider<String>('newest');

final filteredDoctorsProvider = Provider<AsyncValue<List<DoctorModel>>>((ref) {
  final doctorsAsync = ref.watch(doctorsListProvider);
  final hospitalsAsync = ref.watch(hospitalsListProvider);
  final query = ref.watch(doctorSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(doctorSortProvider);

  final hospitalsMap = <String, String>{};
  if (hospitalsAsync.hasValue) {
    for (final h in hospitalsAsync.value!) {
      hospitalsMap[h.id] = h.name.toLowerCase();
    }
  }

  return doctorsAsync.whenData((doctors) {
    var result = doctors;
    if (query.isNotEmpty) {
      result = result.where((doc) {
        final name = doc.name.toLowerCase();
        final specialty = doc.specialty.toLowerCase();
        final legacyHospital = (doc.hospitalName ?? '').toLowerCase();
        final linkedHospitals = doc.hospitalIds
            .map((id) => hospitalsMap[id] ?? '')
            .join(' ');

        return name.contains(query) ||
            specialty.contains(query) ||
            legacyHospital.contains(query) ||
            linkedHospitals.contains(query);
      }).toList();
    }

    final sorted = List<DoctorModel>.from(result);
    if (sort == 'oldest') {
      sorted.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });
    } else if (sort == 'alphabetical') {
      sorted.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else {
      // Default: newest
      sorted.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    }

    return sorted;
  });
});

final doctorDetailsProvider = FutureProvider.family<DoctorModel?, String>((
  ref,
  doctorId,
) async {
  final activeProfile = ref.watch(activeProfileProvider);
  final repository = ref.watch(doctorRepositoryProvider);
  if (activeProfile == null) return null;
  final docs = await ref.watch(doctorsListProvider.future);
  final matched = docs
      .where((d) => IdUtils.matches(d.id, doctorId) || d.id == doctorId)
      .firstOrNull;
  if (matched != null) return matched;

  return await repository.getDoctorById(activeProfile.profileId, doctorId);
});

/// Returns all practicing hospitals for [doctor], derived from both explicit
/// relations and active consultation encounters.
final doctorHospitalsProvider =
    FutureProvider.family<List<PracticingHospitalInfo>, DoctorModel>((
      ref,
      doctor,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repository = ref.watch(doctorRepositoryProvider);
      return await repository.getPracticingHospitals(
        activeProfile.profileId,
        doctor,
      );
    });

/// Returns real-time dependency counts for [doctorId] across all linked entities.
final doctorDependenciesProvider =
    FutureProvider.family<EntityDependencies, String>((ref, doctorId) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return const EntityDependencies();
      final repository = ref.watch(doctorRepositoryProvider);
      return await repository.getDoctorDependencies(
        activeProfile.profileId,
        doctorId,
      );
    });

final doctorConsultationsProvider =
    FutureProvider.family<List<ConsultationModel>, DoctorModel>((
      ref,
      doctor,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(consultationRepositoryProvider);
      final rawConsultations = await repo.getConsultationModels(
        activeProfile.profileId,
      );

      final searchName = doctor.name.trim().toLowerCase();
      return rawConsultations.where((c) {
        if (IdUtils.matches(c.doctorId, doctor.id)) return true;
        final cDoc = c.doctorName.trim().toLowerCase();
        if (cDoc.isNotEmpty &&
            (cDoc == searchName ||
                cDoc.contains(searchName) ||
                searchName.contains(cDoc))) {
          return true;
        }
        return false;
      }).toList();
    });

final doctorAppointmentsProvider =
    FutureProvider.family<List<AppointmentModel>, DoctorModel>((
      ref,
      doctor,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(appointmentRepositoryProvider);
      final list = await repo.getAppointmentModels(activeProfile.profileId);
      final searchName = doctor.name.trim().toLowerCase();
      return list.where((a) {
        if (IdUtils.matches(a.doctorId, doctor.id)) return true;
        final aDoc = a.doctorName.trim().toLowerCase();
        if (aDoc.isNotEmpty &&
            (aDoc == searchName ||
                aDoc.contains(searchName) ||
                searchName.contains(aDoc))) {
          return true;
        }
        return false;
      }).toList();
    });

final doctorReportsProvider =
    FutureProvider.family<List<ReportModel>, DoctorModel>((ref, doctor) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(reportRepositoryProvider);
      final list = await repo.getReportsForProfile(activeProfile.profileId);
      final searchName = doctor.name.trim().toLowerCase();
      return list.where((r) {
        if (IdUtils.matches(r.doctorId, doctor.id)) return true;
        final rDoc = (r.doctorName ?? '').trim().toLowerCase();
        if (rDoc.isNotEmpty &&
            (rDoc == searchName ||
                rDoc.contains(searchName) ||
                searchName.contains(rDoc))) {
          return true;
        }
        return false;
      }).toList();
    });
