import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/doctor_summary_model.dart';

/// Renders the patient demographic summary card on the Doctor Summary screen.
class DoctorSummaryPatientHeader extends StatelessWidget {
  final DoctorSummaryModel summary;
  final String dateLabel;

  const DoctorSummaryPatientHeader({
    super.key,
    required this.summary,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final p = summary.profile;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final nameStyle = AppTypography.h2.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              );
              final chipTextStyle = AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              );

              Widget buildChip({double? maxWidth}) {
                Widget chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chipTextStyle,
                  ),
                );

                if (maxWidth != null) {
                  chip = ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: chip,
                  );
                }

                return Tooltip(
                  message: dateLabel,
                  child: chip,
                );
              }

              final textDirection =
                  Directionality.maybeOf(context) ?? TextDirection.ltr;

              final namePainter = TextPainter(
                text: TextSpan(
                  text: p.fullName,
                  style: nameStyle,
                ),
                maxLines: 1,
                textDirection: textDirection,
              )..layout();

              final chipPainter = TextPainter(
                text: TextSpan(
                  text: dateLabel,
                  style: chipTextStyle,
                ),
                maxLines: 1,
                textDirection: textDirection,
              )..layout();

              // Container horizontal padding: 10 on each side (20 total)
              final chipWidth = chipPainter.width + 20.0;
              const spacing = AppSpacing.md;
              final totalInlineWidth = namePainter.width + chipWidth + spacing;

              if (totalInlineWidth <= constraints.maxWidth) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        p.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                    ),
                    const SizedBox(width: spacing),
                    buildChip(
                      maxWidth: constraints.maxWidth - namePainter.width - spacing,
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    buildChip(
                      maxWidth: constraints.maxWidth,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 6),
          // Demographics Line
          Text(
            [
              p.relationship.toUpperCase(),
              p.gender ?? 'Unspecified',
              if (summary.formattedAge != null)
                'Age: ${summary.formattedAge}',
              if (summary.formattedDob != null && summary.formattedAge == null)
                'DOB: ${summary.formattedDob}',
              'Blood: ${p.bloodGroup ?? 'N/A'}',
            ].join(' · '),
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (summary.formattedHeight != null ||
              summary.formattedWeight != null ||
              summary.formattedBmi() != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (summary.formattedHeight != null)
                  'Height: ${summary.formattedHeight}',
                if (summary.formattedWeight != null)
                  'Weight: ${summary.formattedWeight}',
                if (summary.formattedBmi() != null)
                  'BMI: ${summary.formattedBmi()}',
              ].join(' · '),
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Allergies & Chronic Conditions Columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALLERGIES',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.formattedAllergies,
                      style: AppTypography.caption.copyWith(
                        color: p.allergies.isNotEmpty
                            ? context.semanticColors.statusWarning
                            : colorScheme.onSurface,
                        fontWeight: p.allergies.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHRONIC CONDITIONS',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.formattedChronicConditions,
                      style: AppTypography.caption.copyWith(
                        color: p.chronicConditions.isNotEmpty
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: p.chronicConditions.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
