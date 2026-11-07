import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/timeline_providers.dart';
import '../widgets/timeline_controls_header.dart';
import '../widgets/timeline_empty_state.dart';
import '../widgets/timeline_grouped_list_view.dart';
import '../widgets/timeline_skeleton_loading.dart';

/// TimelineScreen presents a longitudinal chronological medical history timeline for active profile.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  static const List<String> categories = [
    'ALL',
    'Consultations',
    'Reports',
    'Medicines',
    'Measurements',
    'Appointments',
    'Expenses',
    'Doctors',
    'Hospitals',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(activeProfileProvider);
    final totalCount = ref.watch(timelineTotalCountProvider);
    final shownCount = ref.watch(timelineShownCountProvider);
    final selectedCategory = ref.watch(timelineFilterProvider);
    final selectedDateRange = ref.watch(timelineDateRangeProvider);
    final searchQuery = ref.watch(timelineSearchProvider);
    final groupedAsync = ref.watch(groupedTimelineProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final horizontalPadding = isWide ? 24.0 : 16.0;

        return RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(timelineEventsNotifierProvider.notifier)
                .refreshTimeline();
          },

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimelineControlsHeader(
                      isWide: isWide,
                      shownCount: shownCount,
                      totalCount: totalCount,
                      categories: categories,
                    ),
                    const SizedBox(height: 20),
                    groupedAsync.when(
                      data: (groupedMap) {
                        if (groupedMap.isEmpty) {
                          final isFiltered =
                              searchQuery.isNotEmpty ||
                              selectedCategory.toUpperCase() != 'ALL' ||
                              selectedDateRange != 'allTime';

                          return TimelineEmptyState(
                            title: isFiltered
                                ? 'No matching timeline events'
                                : 'No medical history yet.',
                            subtitle: isFiltered
                                ? 'Try adjusting your search terms, category filters, or date range.'
                                : 'Consultations, diagnostic lab reports, vitals, prescriptions, and appointments for ${activeProfile?.fullName ?? "this profile"} will appear here chronologically.',
                            actionLabel: isFiltered
                                ? 'Clear filters'
                                : 'Create your first health record',
                            onAction: () {
                              if (isFiltered) {
                                ref
                                        .read(timelineSearchProvider.notifier)
                                        .state =
                                    '';
                                ref
                                        .read(timelineFilterProvider.notifier)
                                        .state =
                                    'ALL';
                                ref
                                        .read(
                                          timelineDateRangeProvider.notifier,
                                        )
                                        .state =
                                    'allTime';
                                ref
                                        .read(
                                          timelineCustomStartDateProvider
                                              .notifier,
                                        )
                                        .state =
                                    null;
                                ref
                                        .read(
                                          timelineCustomEndDateProvider
                                              .notifier,
                                        )
                                        .state =
                                    null;
                              } else {
                                context.showSnackBar(
                                  'Use Quick Create to add consultations, reports, or measurements.',
                                );
                              }
                            },
                          );
                        }

                        return TimelineGroupedListView(groupedMap: groupedMap);
                      },
                      loading: () => const TimelineSkeletonLoading(),
                      error: (err, stack) => AppErrorState(
                        error: err,
                        onRetry: () => ref
                            .read(timelineEventsNotifierProvider.notifier)
                            .refreshTimeline(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
