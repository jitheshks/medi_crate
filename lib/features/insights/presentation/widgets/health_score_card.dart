import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/insights_summary_model.dart';

export 'score/score_breakdown_section.dart';
export 'score/see_whats_missing_section.dart';

/// HealthScoreCard renders the hero card displaying Health Record Score,
/// disclaimer info, and 3 summary metrics (Consultations, Upcoming, Doctors Seen).
class HealthScoreCard extends StatelessWidget {
  final InsightsSummaryModel summary;

  const HealthScoreCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = summary.healthScore;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Score Circle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 2.5),
                ),
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$score',
                          style: AppTypography.display.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                        TextSpan(
                          text: '/100',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'HEALTH RECORD SCORE',
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => _showDisclaimerDialog(context),
                          tooltip: 'About Health Record Score',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Measures how complete and up-to-date your records are — not a medical or clinical assessment.',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
          ),
          const SizedBox(height: AppSpacing.md),

          // Three Summary Metrics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  count: summary.overviewConsultationsCount,
                  label: 'Consultations',
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _buildMetricTile(
                  context,
                  count: summary.overviewUpcomingAppointmentsCount,
                  label: 'Upcoming',
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _buildMetricTile(
                  context,
                  count: summary.overviewDoctorsSeenCount,
                  label: 'Doctors Seen',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required int count,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$count',
            style: AppTypography.h2.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  void _showDisclaimerDialog(BuildContext context) {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return;
    _lastOpenTime = now;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('About Health Record Score'),
          content: const Text(
            'The Health Record Score is ONLY a measurement of how complete and up-to-date your records are.\n\n'
            'It is not a medical diagnosis, clinical assessment, treatment recommendation, or disease risk indicator.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('GOT IT'),
            ),
          ],
        );
      },
    );
  }
}
