import 'package:flutter/material.dart';
import '../../../../../core/constants/app_currency.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../data/models/insights_summary_model.dart';

class ExpenseBreakdownSection extends StatelessWidget {
  final InsightsSummaryModel summary;
  final String currency;

  const ExpenseBreakdownSection({
    super.key,
    required this.summary,
    this.currency = 'INR',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Expenses by Category
        if (summary.expensesByCategory.isNotEmpty) ...[
          Text(
            'Expenses by category',
            style: AppTypography.h3.copyWith(
              fontSize: 17,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBreakdownCard(context, summary.expensesByCategory, colorScheme),
          const SizedBox(height: AppSpacing.xl),
        ],

        // 2. Expenses by Hospital
        if (summary.expensesByHospital.isNotEmpty) ...[
          Text(
            'Expenses by hospital',
            style: AppTypography.h3.copyWith(
              fontSize: 17,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBreakdownCard(context, summary.expensesByHospital, colorScheme),
          const SizedBox(height: AppSpacing.xl),
        ],

        // 3. Expenses by Doctor
        if (summary.expensesByDoctor.isNotEmpty) ...[
          Text(
            'Expenses by doctor',
            style: AppTypography.h3.copyWith(
              fontSize: 17,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildBreakdownCard(context, summary.expensesByDoctor, colorScheme),
        ],
      ],
    );
  }

  Widget _buildBreakdownCard(
    BuildContext context,
    List<ExpenseBreakdownItem> items,
    ColorScheme colorScheme,
  ) {
    final symbol = AppCurrency.getSymbol(currency);

    return Container(
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
        children: items.map((item) {
          final formattedAmt =
              '$symbol ${item.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formattedAmt,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.percentage,
                    minHeight: 8,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
