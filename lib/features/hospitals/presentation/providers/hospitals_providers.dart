import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';
import 'package:medi_crate/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_hospital_relation.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/doctors/presentation/providers/doctors_providers.dart';
import 'package:medi_crate/features/home/presentation/providers/clinical_sync_coordinator.dart';
import 'package:medi_crate/features/home/presentation/providers/home_providers.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/hospital_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/features/hospitals/data/repositories/hospital_repository.dart';
import 'package:medi_crate/features/insights/presentation/providers/insights_providers.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/reports/presentation/providers/reports_providers.dart';

final hospitalRemoteDataSourceProvider = Provider<HospitalRemoteDataSource>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return HospitalRemoteDataSource(apiClient: apiClient);
});

final hospitalRepositoryProvider = Provider<HospitalRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  final remoteDataSource = ref.watch(hospitalRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  return HospitalRepository(
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

final hospitalsListProvider =
    AsyncNotifierProvider<HospitalsListNotifier, List<HospitalModel>>(() {
      return HospitalsListNotifier();
    });

class HospitalsListNotifier extends AsyncNotifier<List<HospitalModel>> {
  @override
  Future<List<HospitalModel>> build() async {
    // P2-F6: recompute local cache after a background/pull sync (loop-safe;
    // see DoctorsListNotifier.build for rationale).
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];
    final repository = ref.watch(hospitalRepositoryProvider);
    return await repository.getHospitalModels(activeProfile.profileId);
  }

  Future<void> refresh() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }

  Future<HospitalModel?> saveHospital(HospitalModel hospital) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return null;
    final repository = ref.read(hospitalRepositoryProvider);
    final saved = await repository.saveHospitalModel(
      activeProfile.profileId,
      hospital,
    );
    ref.invalidate(doctorsListProvider);
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
    return saved;
  }

  Future<void> deleteHospital(String hospitalId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;
    final repository = ref.read(hospitalRepositoryProvider);
    await repository.deleteHospital(activeProfile.profileId, hospitalId);
    ref.invalidate(doctorsListProvider);
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(consultationsListNotifierProvider);
    ref.invalidate(reportsListNotifierProvider);
    ref.invalidate(appointmentsListProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }
}

final hospitalSearchQueryProvider = StateProvider<String>((ref) => '');

/// Sort option provider for hospitals ('newest', 'oldest', 'alphabetical').
final hospitalSortProvider = StateProvider<String>((ref) => 'newest');

final filteredHospitalsProvider = Provider<AsyncValue<List<HospitalModel>>>((
  ref,
) {
  final hospitalsAsync = ref.watch(hospitalsListProvider);
  final query = ref.watch(hospitalSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(hospitalSortProvider);

  return hospitalsAsync.whenData((hospitals) {
    var result = hospitals;
    if (query.isNotEmpty) {
      result = result.where((hosp) {
        final name = hosp.name.toLowerCase();
        final type = (hosp.type ?? '').toLowerCase();
        final address = (hosp.address ?? '').toLowerCase();
        return name.contains(query) ||
            type.contains(query) ||
            address.contains(query);
      }).toList();
    }

    final sorted = List<HospitalModel>.from(result);
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

final hospitalDetailsProvider = FutureProvider.family<HospitalModel?, String>((
  ref,
  hospitalId,
) async {
  final activeProfile = ref.watch(activeProfileProvider);
  final repository = ref.watch(hospitalRepositoryProvider);
  if (activeProfile == null) return null;
  final hosps = await ref.watch(hospitalsListProvider.future);
  final matched = hosps
      .where((h) => IdUtils.matches(h.id, hospitalId) || h.id == hospitalId)
      .firstOrNull;
  if (matched != null) return matched;

  return await repository.getHospitalById(activeProfile.profileId, hospitalId);
});

final hospitalDoctorsProvider =
    FutureProvider.family<List<DoctorModel>, String>((ref, hospitalId) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repository = ref.watch(hospitalRepositoryProvider);
      return await repository.getAssociatedDoctors(
        activeProfile.profileId,
        hospitalId,
      );
    });

/// Returns real-time dependency counts for [hospitalId] across all linked entities.
final hospitalDependenciesProvider =
    FutureProvider.family<EntityDependencies, String>((ref, hospitalId) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return const EntityDependencies();
      final repository = ref.watch(hospitalRepositoryProvider);
      return await repository.getHospitalDependencies(
        activeProfile.profileId,
        hospitalId,
      );
    });

final hospitalConsultationsProvider =
    FutureProvider.family<List<ConsultationModel>, HospitalModel>((
      ref,
      hospital,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(consultationRepositoryProvider);
      final list = await repo.getConsultationModels(activeProfile.profileId);
      final searchName = hospital.name.trim().toLowerCase();
      return list.where((c) {
        if (IdUtils.matches(c.hospitalId, hospital.id)) return true;
        final cHost = (c.hospitalName ?? '').trim().toLowerCase();
        if (cHost.isNotEmpty &&
            (cHost == searchName ||
                cHost.contains(searchName) ||
                searchName.contains(cHost))) {
          return true;
        }
        return false;
      }).toList();
    });

final hospitalAppointmentsProvider =
    FutureProvider.family<List<AppointmentModel>, HospitalModel>((
      ref,
      hospital,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(appointmentRepositoryProvider);
      final list = await repo.getAppointmentModels(activeProfile.profileId);
      final searchName = hospital.name.trim().toLowerCase();
      return list.where((a) {
        if (IdUtils.matches(a.hospitalId, hospital.id)) return true;
        final aHost = (a.hospitalName ?? '').trim().toLowerCase();
        if (aHost.isNotEmpty &&
            (aHost == searchName ||
                aHost.contains(searchName) ||
                searchName.contains(aHost))) {
          return true;
        }
        return false;
      }).toList();
    });

final hospitalReportsProvider =
    FutureProvider.family<List<ReportModel>, HospitalModel>((
      ref,
      hospital,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(reportRepositoryProvider);
      final list = await repo.getReportsForProfile(activeProfile.profileId);
      final searchName = hospital.name.trim().toLowerCase();
      return list.where((r) {
        if (IdUtils.matches(r.hospitalId, hospital.id)) return true;
        final rHost = (r.hospitalName ?? '').trim().toLowerCase();
        if (rHost.isNotEmpty &&
            (rHost == searchName ||
                rHost.contains(searchName) ||
                searchName.contains(rHost))) {
          return true;
        }
        return false;
      }).toList();
    });
