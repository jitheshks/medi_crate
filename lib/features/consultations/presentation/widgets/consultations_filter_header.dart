import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/buttons/date_range_filter_button.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';

enum ConsultationFilter { all, upcomingFollowUp, followUpDone, noFollowUp }

enum ConsultationSort { newest, oldest }

class ConsultationsFilterHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final DateRangeSelection dateRange;
  final ValueChanged<DateRangePreset> onDateRangePresetSelected;
  final ConsultationFilter filter;
  final ValueChanged<ConsultationFilter> onFilterChanged;
  final ConsultationSort sort;
  final ValueChanged<ConsultationSort> onSortChanged;

  const ConsultationsFilterHeader({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.dateRange,
    required this.onDateRangePresetSelected,
    required this.filter,
    required this.onFilterChanged,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Search Field
              AppSearchField(
                controller: searchController,
                hintText: 'Search doctor, hospital, diagnosis, tags...',
                onChanged: onSearchChanged,
                onClear: onClearSearch,
              ),
              const SizedBox(height: 12),

              // Filter & Sort Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date Range Filter Button
                    DateRangeFilterButton(
                      selection: dateRange,
                      onSelected: onDateRangePresetSelected,
                    ),
                    const SizedBox(width: 8),

                    // Status Filter Chips
                    _buildFilterChip(
                      context,
                      label: 'All',
                      selected: filter == ConsultationFilter.all,
                      onSelected: () => onFilterChanged(ConsultationFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Upcoming Follow-up',
                      selected: filter == ConsultationFilter.upcomingFollowUp,
                      onSelected: () =>
                          onFilterChanged(ConsultationFilter.upcomingFollowUp),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Follow-up Done',
                      selected: filter == ConsultationFilter.followUpDone,
                      onSelected: () =>
                          onFilterChanged(ConsultationFilter.followUpDone),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'No Follow-up',
                      selected: filter == ConsultationFilter.noFollowUp,
                      onSelected: () =>
                          onFilterChanged(ConsultationFilter.noFollowUp),
                    ),
                    const SizedBox(width: 16),
                    Container(height: 24, width: 1, color: colorScheme.outline),
                    const SizedBox(width: 16),

                    // Sort Dropdown
                    PopupMenuButton<ConsultationSort>(
                      initialValue: sort,
                      tooltip: 'Sort Consultations',
                      onSelected: onSortChanged,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: ConsultationSort.newest,
                          child: Text('Newest First'),
                        ),
                        PopupMenuItem(
                          value: ConsultationSort.oldest,
                          child: Text('Oldest First'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sort == ConsultationSort.newest
                                  ? 'Newest'
                                  : 'Oldest',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return FilterChip(
      label: AnimatedDefaultTextStyle(
        duration: duration,
        curve: Curves.easeInOut,
        style: AppTypography.caption.copyWith(
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
        child: Text(label),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
      showCheckmark: false,
    );
  }
}
