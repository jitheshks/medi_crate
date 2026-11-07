import 'package:flutter/material.dart';

import '../../../../../core/constants/app_currency.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../data/models/insights_summary_model.dart';

class ExpenseHeroCard extends StatelessWidget {
  final InsightsSummaryModel summary;
  final String currency;

  const ExpenseHeroCard({
    super.key,
    required this.summary,
    this.currency = 'INR',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = AppCurrency.getSymbol(currency);

    final formattedTotal =
        '$symbol ${summary.totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.timeRange.label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formattedTotal,
            style: AppTypography.display.copyWith(
              color: colorScheme.onPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.recordsWithCostCount} records with cost data for ${summary.profileName}',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseEmptyCard extends StatelessWidget {
  const ExpenseEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
      child: Center(
        child: Text(
          'No healthcare expenses recorded for this period.',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
