import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../medicines/data/models/medicine_model.dart';
import '../../../medicines/presentation/providers/medicine_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reports/data/models/report_model.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../doctors/data/models/doctor_hospital_relation.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../timeline/presentation/providers/timeline_providers.dart';
import '../../data/datasources/remote/consultation_remote_data_source.dart';
import '../../data/models/consultation_model.dart';
import '../../data/repositories/consultation_repository.dart';

export 'consultation_form_providers.dart';

final consultationRemoteDataSourceProvider =
    Provider<ConsultationRemoteDataSource>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return ConsultationRemoteDataSource(apiClient: apiClient);
    });

final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  final remoteDataSource = ref.watch(consultationRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ConsultationRepository(
    hiveService: hive,
    syncService: syncService,
    remoteDataSource: remoteDataSource,
    connectivityService: connectivity,
    onPullMerged: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
});

/// AsyncNotifier managing consultations list for current active profile.
class ConsultationsListNotifier extends AsyncNotifier<List<ConsultationModel>> {
  @override
  Future<List<ConsultationModel>> build() async {
    // P2-F6: recompute local cache after a background/pull sync (loop-safe;
    // see DoctorsListNotifier.build for rationale).
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    try {
      final repo = ref.watch(consultationRepositoryProvider);
      return await repo.getConsultationModels(activeProfile.profileId);
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshConsultations() async {
    state = const AsyncLoading<List<ConsultationModel>>();
    state = await AsyncValue.guard(() async {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.read(consultationRepositoryProvider);
      return await repo.getConsultationModels(activeProfile.profileId);
    });
    ref.invalidate(insightsSummaryProvider);
  }

  /// Saves (creates or updates) a [ConsultationModel] and syncs its shared expense.
  Future<ConsultationModel> saveConsultation(
    ConsultationModel consultation,
  ) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) {
      throw Exception('No active profile selected.');
    }

    // Determine if this is a brand-new consultation creation before persistence
    final hive = ref.read(hiveServiceProvider);
    final userBox = hive.userBox;
    final isNew =
        consultation.id.isEmpty ||
        (!userBox.containsKey(consultation.id) &&
            !userBox.containsKey('consultation_${consultation.id}'));

    final repo = ref.read(consultationRepositoryProvider);

    final saved = await repo.saveConsultationModel(
      activeProfile.profileId,
      consultation,
    );

    // If a new consultation was converted from an appointment, mark appointment as completed
    if (isNew &&
        saved.appointmentId != null &&
        saved.appointmentId!.trim().isNotEmpty) {
      try {
        final appointmentRepo = ref.read(appointmentRepositoryProvider);
        final linkedAppointment = await appointmentRepo.getAppointmentById(
          activeProfile.profileId,
          saved.appointmentId!,
        );
        if (linkedAppointment != null && !linkedAppointment.isCompleted) {
          await appointmentRepo.updateAppointmentStatus(
            activeProfile.profileId,
            linkedAppointment.id,
            'completed',
          );
        }
      } catch (_) {}
    }

    // Sync shared expense
    final expenseId = 'expense_con_${saved.id}';

    if (saved.consultationFee != null && saved.consultationFee! > 0) {
      try {
        final expenseRepo = ref.read(expenseRepositoryProvider);
        await expenseRepo.saveExpense(activeProfile.profileId, {
          'id': expenseId,
          'profile_id': activeProfile.profileId,
          'title': 'Consultation Fee: ${saved.diagnosis}',
          'amount': saved.consultationFee,
          'currency': saved.currency,
          'category': 'Consultation',
          'date': saved.visitDate.toIso8601String(),
          'notes': 'Consultation with ${saved.doctorName}',
          'reference_type': 'consultation',
          'reference_id': saved.id,
        });
      } catch (_) {}
    } else {
      try {
        final expenseRepo = ref.read(expenseRepositoryProvider);
        await expenseRepo.deleteExpense(activeProfile.profileId, expenseId);
      } catch (_) {}
    }

    await _invalidateDownstream();
    return saved;
  }

  /// Updates follow-up status for a consultation.
  Future<void> updateFollowUpStatus(
    String consultationId, {
    required bool isDone,
  }) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repo = ref.read(consultationRepositoryProvider);
    await repo.updateFollowUpStatus(
      activeProfile.profileId,
      consultationId,
      isDone: isDone,
    );

    await _invalidateDownstream();
  }

  /// Deletes a consultation by [consultationId] and removes its shared expense.
  Future<void> deleteConsultation(String consultationId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repo = ref.read(consultationRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);
    await repo.deleteConsultation(activeProfile.profileId, consultationId);

    // Clean up shared expense
    try {
      await expenseRepo.deleteExpense(
        activeProfile.profileId,
        'expense_con_$consultationId',
      );
    } catch (_) {}

    await _invalidateDownstream();
  }

  Future<void> refresh() => refreshConsultations();

  Future<void> _invalidateDownstream() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(timelineEventsNotifierProvider);
    ref.invalidate(reportsListNotifierProvider);
    ref.invalidate(medicinesListNotifierProvider);
    ref.invalidate(doctorsListProvider);
    ref.invalidate(hospitalsListProvider);
    ref.invalidate(appointmentsListProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }
}

final consultationsListNotifierProvider =
    AsyncNotifierProvider<ConsultationsListNotifier, List<ConsultationModel>>(
      ConsultationsListNotifier.new,
    );

/// Provider returning a single consultation by [id] for current active profile.
final consultationDetailProvider =
    FutureProvider.family<ConsultationModel?, String>((ref, id) async {
      final activeProfile = ref.watch(activeProfileProvider);
      final repo = ref.watch(consultationRepositoryProvider);
      final list = await ref.watch(consultationsListNotifierProvider.future);
      final fromList = list
          .where(
            (c) =>
                c.id == id ||
                c.id == 'consultation_$id' ||
                IdUtils.matches(c.id, id) ||
                (c.clientUuid != null && c.clientUuid == id),
          )
          .firstOrNull;
      if (fromList != null) return fromList;

      if (activeProfile != null) {
        return await repo.getConsultationById(activeProfile.profileId, id);
      }
      return null;
    });

/// Derived lookup provider returning the ConsultationModel linked to [appointmentId] for active profile.
final convertedConsultationForAppointmentProvider =
    Provider.family<ConsultationModel?, String>((ref, appointmentId) {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return null;
      final consultationsAsync = ref.watch(consultationsListNotifierProvider);
      final consultations = consultationsAsync.value ?? [];
      final cleanId = IdUtils.unprefix(appointmentId);
      final hive = ref.watch(hiveServiceProvider);

      return consultations.where((c) {
        if (!IdUtils.matchesProfileId(
          c.profileId,
          activeProfile.profileId,
          profileBox: hive.profileBox,
        )) {
          return false;
        }
        if (c.appointmentId == null || c.appointmentId!.isEmpty) return false;
        return IdUtils.matches(c.appointmentId, appointmentId) ||
            IdUtils.matches(c.appointmentId, cleanId);
      }).firstOrNull;
    });

/// Provider returning list of convertible AppointmentModels for the active profile.
/// An appointment is convertible when:
/// 1. It belongs to the active profile.
/// 2. It is not cancelled.
/// 3. It does not already have a linked consultation.
final convertibleAppointmentsProvider = FutureProvider<List<AppointmentModel>>((
  ref,
) async {
  final activeProfile = ref.watch(activeProfileProvider);
  final hive = ref.watch(hiveServiceProvider);
  if (activeProfile == null) return [];
  final appointments = await ref.watch(appointmentsListProvider.future);
  final consultations = await ref.watch(
    consultationsListNotifierProvider.future,
  );

  return appointments.where((a) {
    if (!IdUtils.matchesProfileId(
      a.profileId,
      activeProfile.profileId,
      profileBox: hive.profileBox,
    )) {
      return false;
    }
    if (a.isCancelled) return false;
    final isLinked = consultations.any((c) {
      if (!IdUtils.matchesProfileId(
        c.profileId,
        activeProfile.profileId,
        profileBox: hive.profileBox,
      )) {
        return false;
      }
      if (c.appointmentId == null || c.appointmentId!.isEmpty) return false;
      return IdUtils.matches(c.appointmentId, a.id);
    });
    return !isLinked;
  }).toList();
});

/// Returns real-time dependency counts for [consultationId] across linked medicines and reports.
final consultationDependenciesProvider =
    FutureProvider.family<EntityDependencies, String>((
      ref,
      consultationId,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return const EntityDependencies();
      final repository = ref.watch(consultationRepositoryProvider);
      return await repository.getConsultationDependencies(
        activeProfile.profileId,
        consultationId,
      );
    });

final consultationMedicinesProvider =
    FutureProvider.family<List<MedicineModel>, String>((
      ref,
      consultationId,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(medicineRepositoryProvider);
      final list = await repo.getMedicineModels(activeProfile.profileId);
      return list
          .where((m) => IdUtils.matches(m.linkedConsultationId, consultationId))
          .toList();
    });

final consultationReportsProvider =
    FutureProvider.family<List<ReportModel>, String>((
      ref,
      consultationId,
    ) async {
      final activeProfile = ref.watch(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.watch(reportRepositoryProvider);
      final list = await repo.getReportsForProfile(activeProfile.profileId);
      return list
          .where((r) => IdUtils.matches(r.consultationId, consultationId))
          .toList();
    });
