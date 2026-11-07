import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/insights_summary_model.dart';
import 'expense/expense_breakdown_section.dart';
import 'expense/expense_hero_card.dart';
import 'expense/monthly_expense_chart.dart';

export 'expense/expense_breakdown_section.dart';
export 'expense/expense_hero_card.dart';
export 'expense/monthly_expense_chart.dart';

/// ExpenseAnalyticsSection renders expense hero card, monthly fl_chart bar/line chart with toggle,
/// and breakdown progress bars by category, hospital, and doctor.
class ExpenseAnalyticsSection extends StatefulWidget {
  final InsightsSummaryModel summary;
  final String currency;

  const ExpenseAnalyticsSection({
    super.key,
    required this.summary,
    this.currency = 'INR',
  });

  @override
  State<ExpenseAnalyticsSection> createState() =>
      _ExpenseAnalyticsSectionState();
}

class _ExpenseAnalyticsSectionState extends State<ExpenseAnalyticsSection> {
  bool _isLineView = false; // Default: Bar view

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = widget.summary;
    final currency = widget.currency;

    if (summary.totalExpenses <= 0) {
      return const ExpenseEmptyCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Total Healthcare Expenses Header
        Text(
          'Total healthcare expenses',
          style: AppTypography.h3.copyWith(
            fontSize: 17,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 2. Hero Blue Expense Card
        ExpenseHeroCard(summary: summary, currency: currency),

        const SizedBox(height: AppSpacing.xl),

        // 3. Monthly Expenses Chart Header & Segmented Line/Bar Toggle Control
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Monthly expenses',
                style: AppTypography.h3.copyWith(
                  fontSize: 17,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleButton(
                    label: 'Line',
                    icon: Icons.north_east,
                    isSelected: _isLineView,
                    onTap: () => setState(() => _isLineView = true),
                    colorScheme: colorScheme,
                  ),
                  _buildToggleButton(
                    label: 'Bar',
                    icon: Icons.bar_chart,
                    isSelected: !_isLineView,
                    onTap: () => setState(() => _isLineView = false),
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ],
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
          child: SizedBox(
            height: 180,
            child: MonthlyExpenseChart(
              summary: summary,
              isLineView: _isLineView,
              currency: currency,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 4. Expenses Breakdowns (Category, Hospital, Doctor)
        ExpenseBreakdownSection(summary: summary, currency: currency),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
