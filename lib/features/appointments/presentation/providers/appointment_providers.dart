import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../timeline/presentation/providers/timeline_providers.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../data/datasources/remote/supabase_appointment_remote_data_source.dart';
import '../../data/models/appointment_model.dart';
import '../../data/repositories/appointment_repository.dart';

final supabaseAppointmentRemoteDataSourceProvider =
    Provider<SupabaseAppointmentRemoteDataSource>((ref) {
  return SupabaseAppointmentRemoteDataSource();
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  final supabaseRemoteDataSource =
      ref.watch(supabaseAppointmentRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  return AppointmentRepository(
    hiveService: hiveService,
    syncService: syncService,
    supabaseRemoteDataSource: supabaseRemoteDataSource,
    connectivityService: connectivityService,
    onPullMerged: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
});

final appointmentsListProvider =
    AsyncNotifierProvider<AppointmentsNotifier, List<AppointmentModel>>(
      AppointmentsNotifier.new,
    );

final appointmentDetailsProvider =
    FutureProvider.family<AppointmentModel?, String>((ref, id) async {
      final appointments = await ref.watch(appointmentsListProvider.future);
      return appointments.where((a) => a.id == id).firstOrNull;
    });

class AppointmentsNotifier extends AsyncNotifier<List<AppointmentModel>> {
  @override
  Future<List<AppointmentModel>> build() async {
    // P2-F6: recompute local cache after a background/pull sync (loop-safe;
    // see DoctorsListNotifier.build for rationale).
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    final repository = ref.watch(appointmentRepositoryProvider);
    return repository.getAppointmentModels(activeProfile.profileId);
  }

  Future<void> refresh() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(timelineEventsNotifierProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }

  Future<AppointmentModel?> addAppointment(AppointmentModel appointment) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return null;

    final repository = ref.read(appointmentRepositoryProvider);
    final saved = await repository.saveAppointmentModel(
      activeProfile.profileId,
      appointment,
    );

    // Schedule local device notification reminder if enabled
    if (saved.reminderEnabled) {
      try {
        final notifService = ref.read(localNotificationServiceProvider);
        await notifService.scheduleAppointmentReminder(
          appointmentId: saved.id,
          title: saved.title,
          doctorOrHospital: saved.doctorName.isNotEmpty
              ? 'Dr. ${saved.doctorName}'
              : (saved.hospitalName ?? 'Doctor'),
          appointmentDateTime: saved.date,
        );
      } catch (_) {}
    }

    // Sync optional expense into ExpenseRepository if cost is specified
    if (saved.cost != null && saved.cost! > 0) {
      try {
        final expenseRepo = ref.read(expenseRepositoryProvider);
        await expenseRepo.saveExpense(activeProfile.profileId, {
          'id': 'expense_app_${saved.id}',
          'profile_id': activeProfile.profileId,
          'title': 'Appointment Fee: ${saved.title}',
          'amount': saved.cost,
          'currency': saved.currency,
          'category': 'Appointments',
          'date': saved.date.toIso8601String(),
          'notes': 'Appointment with ${saved.doctorName}',
          'reference_type': 'appointment',
          'reference_id': saved.id,
        });
      } catch (_) {}
    }

    await refresh();
    return saved;
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(appointmentRepositoryProvider);
    await repository.saveAppointmentModel(activeProfile.profileId, appointment);

    // Reschedule or cancel local reminder
    try {
      final notifService = ref.read(localNotificationServiceProvider);
      if (appointment.reminderEnabled) {
        await notifService.scheduleAppointmentReminder(
          appointmentId: appointment.id,
          title: appointment.title,
          doctorOrHospital: appointment.doctorName.isNotEmpty
              ? 'Dr. ${appointment.doctorName}'
              : (appointment.hospitalName ?? 'Doctor'),
          appointmentDateTime: appointment.date,
        );
      } else {
        await notifService.cancelAppointmentReminder(appointment.id);
      }
    } catch (_) {}

    // Sync expense update
    final expenseRepo = ref.read(expenseRepositoryProvider);
    final expenseId = 'expense_app_${appointment.id}';
    if (appointment.cost != null && appointment.cost! > 0) {
      try {
        await expenseRepo.saveExpense(activeProfile.profileId, {
          'id': expenseId,
          'profile_id': activeProfile.profileId,
          'title': 'Appointment Fee: ${appointment.title}',
          'amount': appointment.cost,
          'currency': appointment.currency,
          'category': 'Appointments',
          'date': appointment.date.toIso8601String(),
          'notes': 'Appointment with ${appointment.doctorName}',
          'reference_type': 'appointment',
          'reference_id': appointment.id,
        });
      } catch (_) {}
    } else {
      try {
        await expenseRepo.deleteExpense(activeProfile.profileId, expenseId);
      } catch (_) {}
    }

    await refresh();
  }

  Future<void> updateStatus(String appointmentId, String newStatus) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(appointmentRepositoryProvider);
    await repository.updateAppointmentStatus(
      activeProfile.profileId,
      appointmentId,
      newStatus,
    );
    await refresh();
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    // Cancel scheduled local reminder
    try {
      final notifService = ref.read(localNotificationServiceProvider);
      await notifService.cancelAppointmentReminder(appointmentId);
    } catch (_) {}

    final repository = ref.read(appointmentRepositoryProvider);
    await repository.deleteAppointment(activeProfile.profileId, appointmentId);

    // Also clean up linked expense record if present
    try {
      final expenseRepo = ref.read(expenseRepositoryProvider);
      await expenseRepo.deleteExpense(
        activeProfile.profileId,
        'expense_app_$appointmentId',
      );
    } catch (_) {}

    await refresh();
  }
}
