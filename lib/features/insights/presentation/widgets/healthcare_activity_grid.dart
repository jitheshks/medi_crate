import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/insights_summary_model.dart';

/// HealthcareActivityGrid displays a 2x2 or 4x1 card grid for Consultations,
/// Appointments, Reports Added, and Vitals Logged matching reference screens.
class HealthcareActivityGrid extends StatelessWidget {
  final InsightsSummaryModel summary;

  const HealthcareActivityGrid({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final activityItems = [
      _ActivityItem(
        icon: AppIcons.stethoscope,
        count: summary.totalConsultations,
        label: 'CONSULTATIONS',
      ),
      _ActivityItem(
        icon: AppIcons.calendar,
        count: summary.totalAppointments,
        label: 'APPOINTMENTS',
      ),
      _ActivityItem(
        icon: AppIcons.fileText,
        count: summary.totalReports,
        label: 'REPORTS ADDED',
      ),
      _ActivityItem(
        icon: AppIcons.activity,
        count: summary.totalVitalsLogged,
        label: 'VITALS LOGGED',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final isNarrow = constraints.maxWidth < 360;
        final crossAxisCount = isWide ? 4 : 2;
        final childAspectRatio = isWide ? 1.35 : (isNarrow ? 1.05 : 1.25);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activityItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isNarrow ? AppSpacing.sm : AppSpacing.md,
            mainAxisSpacing: isNarrow ? AppSpacing.sm : AppSpacing.md,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = activityItems[index];
            return Container(
              padding: EdgeInsets.all(isNarrow ? AppSpacing.sm : AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${item.count}',
                      style: AppTypography.h1.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    item.label,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final int count;
  final String label;

  _ActivityItem({required this.icon, required this.count, required this.label});
}
