import 'package:flutter/material.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/app_semantic_colors.dart';

/// Presentation component displaying a warning banner when a user attempts
/// to create an entity (e.g., Doctor, Hospital) whose name already exists.
class PickerDuplicateWarningBanner extends StatelessWidget {
  final String duplicateName;
  final String entityNoun;
  final String? actionLabel;
  final VoidCallback onUseDuplicate;

  const PickerDuplicateWarningBanner({
    super.key,
    required this.duplicateName,
    required this.entityNoun,
    this.actionLabel,
    required this.onUseDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = context.semanticColors;
    final effectiveActionLabel = actionLabel ?? 'Use this $entityNoun instead';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semanticColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: semanticColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: semanticColors.onWarningContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A $entityNoun named "$duplicateName" already exists.',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: semanticColors.onWarningContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onUseDuplicate,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
              minimumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: Text(effectiveActionLabel),
          ),
          const SizedBox(height: 4),
          Text(
            'You can still continue if this is intentionally a separate $entityNoun.',
            style: AppTypography.caption.copyWith(
              color: semanticColors.onWarningContainer,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
