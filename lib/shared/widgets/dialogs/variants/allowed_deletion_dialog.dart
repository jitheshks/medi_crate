import 'package:flutter/material.dart';

import '../../../../../core/constants/app_typography.dart';

/// Variant for safe deletion of unlinked entities.
class AllowedDeletionDialog extends StatelessWidget {
  final String title;
  final String recordType;
  final String deleteButtonText;
  final VoidCallback? onConfirm;

  const AllowedDeletionDialog({
    super.key,
    required this.title,
    required this.recordType,
    this.deleteButtonText = 'DELETE',
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              color: colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline,
              color: colorScheme.error,
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
      content: Text(
        'Are you sure you want to delete this $lowerType? This action cannot be undone.',
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(true);
            if (onConfirm != null) onConfirm!();
          },
          child: Text(deleteButtonText),
        ),
      ],
    );
  }
}
