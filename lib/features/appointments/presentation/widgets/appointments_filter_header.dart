import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/buttons/date_range_filter_button.dart';
import '../../../../shared/widgets/buttons/sort_toggle_button.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';

class AppointmentsFilterHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final DateRangeSelection dateRange;
  final ValueChanged<DateRangePreset> onDateRangePresetSelected;
  final String selectedSort;
  final ValueChanged<String> onSortChanged;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;

  const AppointmentsFilterHeader({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.dateRange,
    required this.onDateRangePresetSelected,
    required this.selectedSort,
    required this.onSortChanged,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          // Search Input Field
          AppSearchField(
            controller: searchController,
            hintText: 'Search appointments or doctor...',
            onChanged: onSearchChanged,
            onClear: onClearSearch,
          ),
          const SizedBox(height: 12),

          // Status & Date/Sort Filter Chips Row
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
                _buildTabChip(context, 'upcoming', 'Upcoming'),
                const SizedBox(width: 8),
                _buildTabChip(context, 'completed', 'Completed'),
                const SizedBox(width: 8),
                _buildTabChip(context, 'cancelled', 'Cancelled'),
                const SizedBox(width: 8),
                _buildTabChip(context, 'all', 'All'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(BuildContext context, String key, String label) {
    final isSelected = selectedTab == key;
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return ChoiceChip(
      label: AnimatedDefaultTextStyle(
        duration: duration,
        curve: Curves.easeInOut,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
        child: Text(label),
      ),
      selected: isSelected,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          onTabSelected(key);
        }
      },
    );
  }
}
