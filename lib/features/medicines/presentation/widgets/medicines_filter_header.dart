import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/buttons/date_range_filter_button.dart';
import '../../../../shared/widgets/buttons/sort_toggle_button.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';

enum MedicineFilter { all, active, completed }

class MedicinesFilterHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final DateRangeSelection dateRange;
  final ValueChanged<DateRangePreset> onDateRangePresetSelected;
  final String selectedSort;
  final ValueChanged<String> onSortChanged;
  final MedicineFilter selectedFilter;
  final ValueChanged<MedicineFilter> onFilterChanged;

  const MedicinesFilterHeader({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.dateRange,
    required this.onDateRangePresetSelected,
    required this.selectedSort,
    required this.onSortChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Search Field
          AppSearchField(
            controller: searchController,
            hintText: 'Search medicine name...',
            onClear: () => searchController.clear(),
          ),
          const SizedBox(height: 12),

          // Filter & Sort Controls Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DateRangeFilterButton(
                  selection: dateRange,
                  onSelected: onDateRangePresetSelected,
                ),
                const SizedBox(width: 8),
                SortToggleButton(
                  currentSort: selectedSort,
                  onSortChanged: onSortChanged,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(context, MedicineFilter.all, 'All'),
                const SizedBox(width: 8),
                _buildFilterChip(context, MedicineFilter.active, 'Active'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  MedicineFilter.completed,
                  'Completed',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    MedicineFilter filter,
    String label,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedFilter == filter;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return FilterChip(
      label: AnimatedDefaultTextStyle(
        duration: duration,
        curve: Curves.easeInOut,
        style: AppTypography.caption.copyWith(
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        child: Text(label),
      ),
      selected: isSelected,
      onSelected: (_) => onFilterChanged(filter),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      ),
    );
  }
}
