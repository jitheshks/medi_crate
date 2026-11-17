import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/buttons/date_range_filter_button.dart';
import 'vitals_sort_picker_sheet.dart';

class VitalsControlsBar extends StatelessWidget {
  final DateRangeSelection dateRange;
  final String selectedSortOrder;
  final int filteredCount;
  final int totalCount;
  final ValueChanged<DateRangePreset> onDateRangePresetSelected;
  final ValueChanged<String> onSortOrderSelected;

  const VitalsControlsBar({
    super.key,
    required this.dateRange,
    required this.selectedSortOrder,
    required this.filteredCount,
    required this.totalCount,
    required this.onDateRangePresetSelected,
    required this.onSortOrderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          DateRangeFilterButton(
            selection: dateRange,
            onSelected: onDateRangePresetSelected,
          ),
          InkWell(
            onTap: () {
              showVitalsSortPickerSheet(
                context,
                currentSortOrder: selectedSortOrder,
                onSortOrderSelected: onSortOrderSelected,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    selectedSortOrder,
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '$filteredCount of $totalCount',
            style: AppTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
