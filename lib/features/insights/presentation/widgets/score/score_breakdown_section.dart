import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../data/models/health_vault_score_model.dart';

/// ScoreBreakdownSection renders the 4 categories (Vitals, Profile, Consultations, Reports)
/// with earned/max points, progress bars, and dynamic explanations.
class ScoreBreakdownSection extends StatelessWidget {
  final HealthVaultScoreModel vaultScore;

  const ScoreBreakdownSection({super.key, required this.vaultScore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successColor = context.semanticColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score breakdown',
          style: AppTypography.h3.copyWith(
            fontSize: 17,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            children: vaultScore.categories.map((cat) {
              final double progress = (cat.score / cat.maxScore).clamp(
                0.0,
                1.0,
              );
              final isComplete = cat.isComplete;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.name,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${_formatScore(cat.score)}/${cat.maxScore}',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isComplete
                                ? successColor
                                : colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete ? successColor : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat.statusDetail,
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatScore(num score) {
    if (score == score.toInt()) {
      return '${score.toInt()}';
    }
    return score.toStringAsFixed(1);
  }
}
