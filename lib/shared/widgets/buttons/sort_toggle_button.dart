import 'package:flutter/material.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// SortToggleButton renders a standardized Material 3 pill dropdown button
/// with a sort icon, active sort label, and a menu to toggle sorting options.
class SortToggleButton extends StatelessWidget {
  final String currentSort;
  final ValueChanged<String> onSortChanged;
  final List<SortOptionItem> options;

  const SortToggleButton({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
    this.options = const [
      SortOptionItem(value: 'newest', label: 'Newest first'),
      SortOptionItem(value: 'oldest', label: 'Oldest first'),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String currentLabel = 'Sort';
    for (final opt in options) {
      if (opt.value == currentSort) {
        currentLabel = opt.shortLabel ?? opt.label;
        break;
      }
    }

    return PopupMenuButton<String>(
      initialValue: currentSort,
      tooltip: 'Sort list',
      onSelected: onSortChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      itemBuilder: (context) => options.map((opt) {
        return PopupMenuItem<String>(value: opt.value, child: Text(opt.label));
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              currentLabel,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents an item in the sort popup menu.
class SortOptionItem {
  final String value;
  final String label;
  final String? shortLabel;

  const SortOptionItem({
    required this.value,
    required this.label,
    this.shortLabel,
  });
}
