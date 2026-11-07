import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/mutable_state_notifier.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/timeline_event_model.dart';
import '../../data/repositories/timeline_repository.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  return TimelineRepository(hiveService: hive, syncService: sync);
});

/// Search query provider for Timeline.
final timelineSearchProvider = mutableStateProvider<String>('');

/// Category filter chip provider ('ALL', 'CONSULTATIONS', 'REPORTS', etc.).
final timelineFilterProvider = mutableStateProvider<String>('ALL');

/// Date range filter provider ('last30Days', 'last90Days', 'last6Months', 'lastYear', 'allTime', 'custom').
final timelineDateRangeProvider = mutableStateProvider<String>('last90Days');

/// Custom date range providers for Timeline.
final timelineCustomStartDateProvider =
    mutableStateProvider<DateTime?>(null);
final timelineCustomEndDateProvider =
    mutableStateProvider<DateTime?>(null);

/// Sort order provider ('newest', 'oldest').
final timelineSortProvider = mutableStateProvider<String>('newest');

/// Notifier managing active profile's aggregated timeline events.
class TimelineEventsNotifier extends AsyncNotifier<List<TimelineEventModel>> {
  @override
  Future<List<TimelineEventModel>> build() async {
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    final repo = ref.watch(timelineRepositoryProvider);
    return await repo.getTimelineEvents(activeProfile.profileId);
  }

  Future<void> refreshTimeline() async {
    state = const AsyncLoading<List<TimelineEventModel>>();
    state = await AsyncValue.guard(() async {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.read(timelineRepositoryProvider);
      return await repo.getTimelineEvents(activeProfile.profileId);
    });
  }
}

final timelineEventsNotifierProvider =
    AsyncNotifierProvider<TimelineEventsNotifier, List<TimelineEventModel>>(
      TimelineEventsNotifier.new,
    );

/// Provider computing filtered and sorted timeline events.
final filteredTimelineProvider = Provider<AsyncValue<List<TimelineEventModel>>>(
  (ref) {
    final eventsAsync = ref.watch(timelineEventsNotifierProvider);
    final query = ref.watch(timelineSearchProvider);
    final category = ref.watch(timelineFilterProvider);
    final dateRange = ref.watch(timelineDateRangeProvider);
    final customStart = ref.watch(timelineCustomStartDateProvider);
    final customEnd = ref.watch(timelineCustomEndDateProvider);
    final sortOption = ref.watch(timelineSortProvider);
    final repo = ref.watch(timelineRepositoryProvider);

    return eventsAsync.whenData((events) {
      return repo.filterAndSortEvents(
        events: events,
        query: query,
        categoryFilter: category,
        dateRange: dateRange,
        customStartDate: customStart,
        customEndDate: customEnd,
        sortOption: sortOption,
      );
    });
  },
);

/// Provider computing day-grouped timeline events for UI list rendering.
final groupedTimelineProvider =
    Provider<AsyncValue<Map<String, List<TimelineEventModel>>>>((ref) {
      final filteredAsync = ref.watch(filteredTimelineProvider);
      final repo = ref.watch(timelineRepositoryProvider);

      return filteredAsync.whenData((filteredEvents) {
        return repo.groupEventsByDay(filteredEvents);
      });
    });

/// Provider returning total count of raw timeline events for active profile.
final timelineTotalCountProvider = Provider<int>((ref) {
  final eventsAsync = ref.watch(timelineEventsNotifierProvider);
  return eventsAsync.value?.length ?? 0;
});

/// Provider returning count of currently shown/filtered events.
final timelineShownCountProvider = Provider<int>((ref) {
  final filteredAsync = ref.watch(filteredTimelineProvider);
  return filteredAsync.value?.length ?? 0;
});
