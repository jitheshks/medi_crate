import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../timeline/presentation/providers/timeline_providers.dart';
import '../../../../core/notifications/local_notification_service.dart';

import 'package:material_ui/material_ui.dart';

import '../../data/datasources/remote/supabase_medicine_remote_data_source.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';

final supabaseMedicineRemoteDataSourceProvider =
    Provider<SupabaseMedicineRemoteDataSource>((ref) {
  return SupabaseMedicineRemoteDataSource();
});

final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  final supabaseRemote = ref.watch(supabaseMedicineRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return MedicineRepository(
    hiveService: hive,
    syncService: sync,
    supabaseRemoteDataSource: supabaseRemote,
    connectivityService: connectivity,
    onPullMerged: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
});

class MedicinesListNotifier extends AsyncNotifier<List<MedicineModel>> {
  @override
  Future<List<MedicineModel>> build() async {
    // P2-F6: recompute local cache after a background/pull sync (loop-safe;
    // see DoctorsListNotifier.build for rationale).
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    final repo = ref.watch(medicineRepositoryProvider);
    return repo.getMedicineModels(activeProfile.profileId);
  }

  Future<MedicineModel> saveMedicine(MedicineModel model) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) {
      throw Exception('No active profile selected.');
    }

    final repo = ref.read(medicineRepositoryProvider);
    final modelWithProfile = model.copyWith(profileId: activeProfile.profileId);
    final saved = await repo.saveMedicineModel(
      activeProfile.profileId,
      modelWithProfile,
    );

    // Schedule or cancel local dose reminders
    try {
      final notifService = ref.read(localNotificationServiceProvider);
      if (saved.reminder) {
        final times = (saved.reminderTimes ?? ['09:00']).map((timeStr) {
          final parts = timeStr.split(':');
          final h = int.tryParse(parts[0]) ?? 9;
          final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          return TimeOfDay(hour: h, minute: m);
        }).toList();

        await notifService.scheduleMedicineReminders(
          medicineId: saved.id,
          medicineName: saved.medicineName,
          dosage: saved.dosage,
          reminderTimes: times,
          startDate: saved.startDate,
          endDate: saved.endDate,
        );
      } else {
        await notifService.cancelMedicineReminders(saved.id);
      }
    } catch (_) {}

    await _invalidateDownstream();
    return saved;
  }

  Future<void> deleteMedicine(String medicineId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    // Cancel local reminder notifications for deleted medicine
    try {
      final notifService = ref.read(localNotificationServiceProvider);
      await notifService.cancelMedicineReminders(medicineId);
    } catch (_) {}

    final repo = ref.read(medicineRepositoryProvider);
    await repo.deleteMedicine(activeProfile.profileId, medicineId);

    await _invalidateDownstream();
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

  Future<void> _invalidateDownstream() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(timelineEventsNotifierProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }
}

final medicinesListNotifierProvider =
    AsyncNotifierProvider<MedicinesListNotifier, List<MedicineModel>>(
      MedicinesListNotifier.new,
    );

final medicineDetailProvider = FutureProvider.family<MedicineModel?, String>((
  ref,
  medicineId,
) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return null;

  // Watch list notifier so detail automatically updates when list updates
  ref.watch(medicinesListNotifierProvider);

  final repo = ref.watch(medicineRepositoryProvider);
  return repo.getMedicineById(activeProfile.profileId, medicineId);
});
