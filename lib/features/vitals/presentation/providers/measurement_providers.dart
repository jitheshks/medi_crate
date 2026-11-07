import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../timeline/presentation/providers/timeline_providers.dart';
import '../../data/datasources/remote/vitals_remote_data_source.dart';
import '../../data/models/measurement_model.dart';
import '../../data/repositories/measurement_repository.dart';

final vitalsRemoteDataSourceProvider = Provider<VitalsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VitalsRemoteDataSource(apiClient: apiClient);
});

/// Provider for MeasurementRepository
final measurementRepositoryProvider = Provider<MeasurementRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  final remoteDataSource = ref.watch(vitalsRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return MeasurementRepository(
    hiveService: hiveService,
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

/// AsyncNotifier managing profile-scoped list of health measurements.
/// Automatically reacts to changes in activeProfileProvider.
class MeasurementsListNotifier extends AsyncNotifier<List<MeasurementModel>> {
  @override
  Future<List<MeasurementModel>> build() async {
    // P2-F6: recompute local cache after a background/pull sync (loop-safe;
    // see DoctorsListNotifier.build for rationale).
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    final repository = ref.read(measurementRepositoryProvider);
    return repository.getMeasurementModels(activeProfile.profileId);
  }

  /// Add or update a measurement for the currently active profile.
  Future<void> addMeasurement(MeasurementModel model) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(measurementRepositoryProvider);
    final modelWithProfile = model.copyWith(profileId: activeProfile.profileId);

    await repository.saveMeasurementModel(modelWithProfile);
    await refresh();
    _invalidateDownstream();
  }

  /// Delete a measurement from Hive for the active profile.
  Future<void> deleteMeasurement(String measurementId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(measurementRepositoryProvider);
    await repository.deleteMeasurement(activeProfile.profileId, measurementId);
    await refresh();
    _invalidateDownstream();
  }

  /// Force refresh measurement data from storage.
  Future<void> refresh() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(timelineEventsNotifierProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }

  void _invalidateDownstream() {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(timelineEventsNotifierProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }
}

/// Provider for MeasurementsListNotifier
final measurementsListProvider =
    AsyncNotifierProvider<MeasurementsListNotifier, List<MeasurementModel>>(
      MeasurementsListNotifier.new,
    );
