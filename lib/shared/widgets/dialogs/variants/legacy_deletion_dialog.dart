import 'package:flutter/material.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/theme/app_theme.dart';
import '../deletion_impact_dialog.dart';

/// Legacy variant supporting explicit impact item breakdowns for profile or batch callers.
class LegacyDeletionDialog extends StatelessWidget {
  final String title;
  final String recordName;
  final List<DeletionImpactItem> impactItems;
  final String? customWarning;
  final String deleteButtonText;
  final VoidCallback? onConfirm;

  const LegacyDeletionDialog({
    super.key,
    required this.title,
    required this.recordName,
    required this.impactItems,
    this.customWarning,
    this.deleteButtonText = 'DELETE',
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredImpacts = impactItems.where((i) => i.count > 0).toList();

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
          RichText(
            text: TextSpan(
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              children: [
                const TextSpan(
                  text: 'Are you sure you want to permanently delete ',
                ),
                TextSpan(
                  text: recordName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          if (filteredImpacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Deleting will have the following effects:',
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                children: filteredImpacts.map((item) {
                  final isCascade =
                      item.type == DeletionImpactType.recordDeleted;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isCascade ? Icons.close : Icons.link_off,
                          size: 16,
                          color: isCascade
                              ? colorScheme.error
                              : context.semanticColors.statusWarning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: AppTypography.caption.copyWith(
                                color: colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: '${item.count} ${item.label} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: item.description),
                              ],
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
          if (customWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              customWarning!,
              style: AppTypography.caption.copyWith(color: colorScheme.error),
            ),
          ],
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
