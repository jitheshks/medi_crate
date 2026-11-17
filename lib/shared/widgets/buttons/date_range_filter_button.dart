import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/date_range_selection.dart';

/// DateRangeFilterButton renders a standardized Material 3 pill button with
/// a calendar icon, current date range label, and a dropdown menu with presets
/// and "Custom range…".
class DateRangeFilterButton extends StatelessWidget {
  final DateRangeSelection selection;
  final ValueChanged<DateRangePreset> onSelected;

  const DateRangeFilterButton({
    super.key,
    required this.selection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCustomOrFiltered = selection.preset != DateRangePreset.allTime;

    return PopupMenuButton<DateRangePreset>(
      initialValue: selection.preset,
      tooltip: 'Filter by date range',
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: DateRangePreset.last30Days,
          child: Text('Last 30 days'),
        ),
        PopupMenuItem(
          value: DateRangePreset.last90Days,
          child: Text('Last 90 days'),
        ),
        PopupMenuItem(
          value: DateRangePreset.lastYear,
          child: Text('Last year'),
        ),
        PopupMenuItem(value: DateRangePreset.allTime, child: Text('All time')),
        PopupMenuItem(
          value: DateRangePreset.custom,
          child: Text('Custom range…'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isCustomOrFiltered
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
              color: isCustomOrFiltered
                  ? colorScheme.primary
                  : colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              selection.label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isCustomOrFiltered
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isCustomOrFiltered
                  ? colorScheme.primary
                  : colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}
