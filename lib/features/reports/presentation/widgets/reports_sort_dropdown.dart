import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

class ReportsSortDropdown extends StatelessWidget {
  final String selectedSort;
  final ValueChanged<String> onSortSelected;

  const ReportsSortDropdown({
    super.key,
    required this.selectedSort,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      onSelected: onSortSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'newest', child: Text('Newest first')),
        PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
        PopupMenuItem(value: 'alphabetical', child: Text('Alphabetical (A-Z)')),
        PopupMenuItem(value: 'type', child: Text('By Category')),
      ],
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
            Icon(AppIcons.sort, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              _getSortLabel(selectedSort),
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'oldest':
        return 'Oldest first';
      case 'alphabetical':
        return 'Alphabetical';
      case 'type':
        return 'By Category';
      case 'newest':
      default:
        return 'Newest first';
    }
  }
}
