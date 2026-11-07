import 'package:flutter/material.dart';

import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/theme/app_semantic_colors.dart';

/// Variant showing reassurance message when deleting items that won't cascade delete other records.
class ReassuranceDeletionDialog extends StatelessWidget {
  final String title;
  final String? reassuranceMessage;
  final String deleteButtonText;
  final VoidCallback? onConfirm;

  const ReassuranceDeletionDialog({
    super.key,
    required this.title,
    this.reassuranceMessage,
    this.deleteButtonText = 'DELETE',
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reassuranceMessage != null && reassuranceMessage!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: semantic.hospitalAccentContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: semantic.hospitalAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: semantic.hospitalAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reassuranceMessage!,
                      style: AppTypography.caption.copyWith(
                        color: semantic.hospitalAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'This action cannot be undone.',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ],
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
