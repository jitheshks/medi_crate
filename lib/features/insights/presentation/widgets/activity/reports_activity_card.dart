import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../data/models/insights_summary_model.dart';

class ReportsActivityCard extends StatelessWidget {
  final ReportSummaryData summary;

  const ReportsActivityCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;

    final categories = summary.categoryCounts.entries.toList();

    final maxCount = categories.isEmpty
        ? 1
        : categories.fold<int>(1, (max, e) => e.value > max ? e.value : max);

    final colors = [
      colorScheme.primary,
      semanticColors.success,
      semanticColors.vitalTemperature,
      colorScheme.tertiary,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reports',
              style: AppTypography.h3.copyWith(
                fontSize: 17,
                color: colorScheme.onSurface,
              ),
            ),
            GestureDetector(
              onTap: () => context.go(AppRoutes.reports),
              child: Row(
                children: [
                  Text(
                    'View all',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Category Breakdown Progress Bar Container or Empty State
        if (categories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 32,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No reports uploaded yet',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
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
              children: categories.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final barColor = colors[idx % colors.length];
                final pct = (item.value / maxCount).clamp(0.1, 1.0);

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: idx == categories.length - 1 ? 0 : AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.key,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${item.value}',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: barColor.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // Latest Report Card
        if (summary.latestReport != null) ...[
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => context.pushGuarded(
              AppRoutes.reportDetail(summary.latestReport!.id),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest: ${summary.latestReport!.title}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(summary.latestReport!.date)} · ${summary.totalCount} total',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
