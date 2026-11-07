import 'package:flutter/material.dart';

import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../features/doctors/data/models/doctor_hospital_relation.dart';

/// Variant for entities with active blocking dependencies.
class BlockedDeletionDialog extends StatelessWidget {
  final String title;
  final String recordType;
  final EntityDependencies dependencies;
  final String? explanatoryMessage;
  final VoidCallback? onViewLinkedRecords;

  const BlockedDeletionDialog({
    super.key,
    required this.title,
    required this.recordType,
    required this.dependencies,
    this.explanatoryMessage,
    this.onViewLinkedRecords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lowerType = recordType.toLowerCase();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.semanticColors.warningContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: context.semanticColors.statusWarning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTypography.h2.copyWith(
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explanatoryMessage ?? 'This $lowerType has linked records.',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Linked records preventing deletion:',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: dependencies.activeItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        item.iconEmoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.count} ${item.label}',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      actions: [
        if (onViewLinkedRecords != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(false);
              onViewLinkedRecords!();
            },
            child: const Text('VIEW LINKED RECORDS'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}
