import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/insights_summary_model.dart';
import '../../data/repositories/analytics_repository.dart';

/// Repository provider for profile-scoped health analytics.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  return AnalyticsRepository(hiveService: hive, syncService: sync);
});

/// State provider for selected time range filter (7 Days, 30 Days, 3 Months, 1 Year, All Time, Custom).
final selectedTimeRangeProvider = StateProvider<InsightsTimeRange>(
  (ref) => InsightsTimeRange.threeMonths,
);

/// Custom date range providers for Insights.
final insightsCustomStartDateProvider = StateProvider<DateTime?>((ref) => null);
final insightsCustomEndDateProvider = StateProvider<DateTime?>((ref) => null);

/// AsyncNotifier managing profile-scoped insights summary state.
class InsightsNotifier extends AsyncNotifier<InsightsSummaryModel> {
  @override
  Future<InsightsSummaryModel> build() async {
    final timeRange = ref.watch(selectedTimeRangeProvider);
    final customStart = ref.watch(insightsCustomStartDateProvider);
    final customEnd = ref.watch(insightsCustomEndDateProvider);

    ref.watch(clinicalSyncCoordinatorProvider);
    ref.watch(clinicalCacheRevisionProvider);
    final repository = ref.watch(analyticsRepositoryProvider);
    final active = ref.watch(activeProfileProvider);

    if (active != null) {
      return await repository.getInsightsSummary(
        profile: active,
        timeRange: timeRange,
        customStartDate: customStart,
        customEndDate: customEnd,
      );
    }

    final profilesAsync = ref.watch(profilesListProvider);
    if (profilesAsync.hasError) {
      Error.throwWithStackTrace(
        profilesAsync.error!,
        profilesAsync.stackTrace ?? StackTrace.current,
      );
    }

    final profiles = profilesAsync.hasValue
        ? profilesAsync.value!
        : await ref.watch(profilesListProvider.future);
    if (profiles.isEmpty) {
      throw const NotFoundException('No health profile found.');
    }

    final activeProfile =
        active ??
        profiles.firstWhere((p) => p.isPrimary, orElse: () => profiles.first);

    return await repository.getInsightsSummary(
      profile: activeProfile,
      timeRange: timeRange,
      customStartDate: customStart,
      customEndDate: customEnd,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<InsightsSummaryModel>();
    state = await AsyncValue.guard(() async {
      var activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) {
        await ref.read(profilesListProvider.notifier).refreshProfiles();
        final profiles = await ref.read(profilesListProvider.future);
        if (profiles.isEmpty) {
          throw const NotFoundException('No health profile found.');
        }
        activeProfile =
            ref.read(activeProfileProvider) ??
            profiles.firstWhere(
              (p) => p.isPrimary,
              orElse: () => profiles.first,
            );
      }
      final timeRange = ref.read(selectedTimeRangeProvider);
      final customStart = ref.read(insightsCustomStartDateProvider);
      final customEnd = ref.read(insightsCustomEndDateProvider);
      final repository = ref.read(analyticsRepositoryProvider);
      return await repository.getInsightsSummary(
        profile: activeProfile,
        timeRange: timeRange,
        customStartDate: customStart,
        customEndDate: customEnd,
      );
    });
  }
}

final insightsSummaryProvider =
    AsyncNotifierProvider<InsightsNotifier, InsightsSummaryModel>(
      InsightsNotifier.new,
    );
