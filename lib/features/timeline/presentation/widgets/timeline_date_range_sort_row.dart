import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/buttons/sort_toggle_button.dart';

class TimelineDateRangeSortRow extends StatelessWidget {
  final String selectedDateRange;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String currentSort;
  final ValueChanged<String> onDateRangeSelected;
  final ValueChanged<String> onSortChanged;

  const TimelineDateRangeSortRow({
    super.key,
    required this.selectedDateRange,
    required this.customStart,
    required this.customEnd,
    required this.currentSort,
    required this.onDateRangeSelected,
    required this.onSortChanged,
  });

  String _getDateRangeLabel(String range, DateTime? start, DateTime? end) {
    switch (range) {
      case 'last30Days':
        return 'Last 30 days';
      case 'last90Days':
        return 'Last 90 days';
      case 'lastYear':
        return 'Last year';
      case 'allTime':
        return 'All time';
      case 'custom':
        if (start != null && end != null) {
          return DateFormatter.formatDateRange(start, end);
        }
        return 'Custom range…';
      default:
        return 'All time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<String>(
          onSelected: onDateRangeSelected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'last30Days',
              child: Text('Last 30 days'),
            ),
            const PopupMenuItem(
              value: 'last90Days',
              child: Text('Last 90 days'),
            ),
            const PopupMenuItem(value: 'lastYear', child: Text('Last year')),
            const PopupMenuItem(value: 'allTime', child: Text('All time')),
            const PopupMenuItem(value: 'custom', child: Text('Custom range…')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selectedDateRange == 'custom'
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.calendar,
                  size: 16,
                  color: selectedDateRange == 'custom'
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  _getDateRangeLabel(selectedDateRange, customStart, customEnd),
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selectedDateRange == 'custom'
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: selectedDateRange == 'custom'
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ),
        SortToggleButton(
          currentSort: currentSort,
          onSortChanged: onSortChanged,
        ),
      ],
    );
  }
}
