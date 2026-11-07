import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';
import '../../../../shared/widgets/forms/custom_date_range_panel.dart';
import '../providers/timeline_providers.dart';
import 'timeline_category_chips_bar.dart';
import 'timeline_date_range_sort_row.dart';

class TimelineControlsHeader extends ConsumerStatefulWidget {
  final bool isWide;
  final int shownCount;
  final int totalCount;
  final List<String> categories;

  const TimelineControlsHeader({
    super.key,
    required this.isWide,
    required this.shownCount,
    required this.totalCount,
    required this.categories,
  });

  @override
  ConsumerState<TimelineControlsHeader> createState() =>
      _TimelineControlsHeaderState();
}

class _TimelineControlsHeaderState
    extends ConsumerState<TimelineControlsHeader> {
  bool _showCustomDatePanel = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(timelineSearchProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCategory = ref.watch(timelineFilterProvider);
    final selectedDateRange = ref.watch(timelineDateRangeProvider);
    final customStart = ref.watch(timelineCustomStartDateProvider);
    final customEnd = ref.watch(timelineCustomEndDateProvider);
    final searchQuery = ref.watch(timelineSearchProvider);
    final currentSort = ref.watch(timelineSortProvider);

    if (_searchController.text != searchQuery) {
      _searchController.value = _searchController.value.copyWith(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
        composing: TextRange.empty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LONGITUDINAL',
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Health Timeline',
                style: AppTypography.h1.copyWith(
                  fontSize: widget.isWide ? 28 : 24,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${widget.shownCount} of ${widget.totalCount} events',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppSearchField(
          controller: _searchController,
          hintText: 'Search consultations, diagnoses, meds...',
          onChanged: (val) {
            ref.read(timelineSearchProvider.notifier).state = val;
          },
          onClear: () {
            ref.read(timelineSearchProvider.notifier).state = '';
          },
        ),
        const SizedBox(height: 14),
        TimelineCategoryChipsBar(
          categories: widget.categories,
          selectedCategory: selectedCategory,
          onSelected: (cat) {
            ref.read(timelineFilterProvider.notifier).state = cat;
          },
        ),
        const SizedBox(height: 14),
        TimelineDateRangeSortRow(
          selectedDateRange: selectedDateRange,
          customStart: customStart,
          customEnd: customEnd,
          currentSort: currentSort,
          onDateRangeSelected: (range) {
            if (range == 'custom') {
              setState(() {
                _showCustomDatePanel = true;
              });
            } else {
              setState(() {
                _showCustomDatePanel = false;
              });
              ref.read(timelineDateRangeProvider.notifier).state = range;
            }
          },
          onSortChanged: (sort) {
            ref.read(timelineSortProvider.notifier).state = sort;
          },
        ),
        if (_showCustomDatePanel) ...[
          const SizedBox(height: 12),
          CustomDateRangePanel(
            initialStartDate: customStart,
            initialEndDate: customEnd,
            onApply: (start, end) {
              ref.read(timelineDateRangeProvider.notifier).state = 'custom';
              ref.read(timelineCustomStartDateProvider.notifier).state = start;
              ref.read(timelineCustomEndDateProvider.notifier).state = end;
              setState(() {
                _showCustomDatePanel = false;
              });
            },
            onCancel: () {
              setState(() {
                _showCustomDatePanel = false;
              });
            },
          ),
        ],
      ],
    );
  }
}
