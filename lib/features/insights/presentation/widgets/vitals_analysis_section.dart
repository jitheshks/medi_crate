import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/insights_summary_model.dart';
import 'vitals/vital_trend_card.dart';

export 'vitals/vital_trend_card.dart';

/// VitalsAnalysisSection renders individual vital trend cards with a shared section-level
/// Line / Bar toggle control, auto-scaled axes, and non-diagnostic informational status badges.
class VitalsAnalysisSection extends StatefulWidget {
  final List<VitalTrendSeries> trends;

  const VitalsAnalysisSection({super.key, required this.trends});

  @override
  State<VitalsAnalysisSection> createState() => _VitalsAnalysisSectionState();
}

class _VitalsAnalysisSectionState extends State<VitalsAnalysisSection> {
  bool _isLineView = true;

  @override
  Widget build(BuildContext context) {
    // Filter out series with 0 readings
    final activeTrends = widget.trends.where((t) => !t.isEmpty).toList();

    if (activeTrends.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final hasAnyTrend = activeTrends.any((t) => t.hasTrend);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row: Title on Left, Shared Line/Bar Toggle on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Vitals analysis',
                style: AppTypography.h3.copyWith(
                  fontSize: 17,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasAnyTrend) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.5,
                  ),
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
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // List of Active Vital Trend Cards
        ...activeTrends.map(
          (series) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: VitalTrendCard(series: series, isLineView: _isLineView),
          ),
        ),
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
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
