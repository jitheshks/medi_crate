import 'package:flutter/material.dart';

import '../../../../shared/widgets/forms/app_search_field.dart';
import 'vital_filter_chips_bar.dart';

class MeasurementsSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedFilterType;
  final ValueChanged<String> onFilterSelected;
  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;

  const MeasurementsSearchBar({
    super.key,
    required this.searchController,
    required this.selectedFilterType,
    required this.onFilterSelected,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          AppSearchField(
            controller: searchController,
            hintText: 'Search measurements or notes...',
            onChanged: (_) => onSearchChanged(),
            onClear: onClearSearch,
          ),
          const SizedBox(height: 12),
          VitalFilterChipsBar(
            selectedFilterType: selectedFilterType,
            onFilterSelected: onFilterSelected,
          ),
        ],
      ),
    );
  }
}
