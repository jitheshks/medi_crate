import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../data/models/insights_summary_model.dart';

class AppointmentsActivityCard extends StatelessWidget {
  final AppointmentSummaryData summary;

  const AppointmentsActivityCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Appointments',
              style: AppTypography.h3.copyWith(
                fontSize: 17,
                color: colorScheme.onSurface,
              ),
            ),
            GestureDetector(
              onTap: () => context.go(AppRoutes.appointments),
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

        // 2x2 Grid of Status Count Cards matching reference UI
        Row(
          children: [
            Expanded(
              child: _buildCountTile(
                context,
                count: summary.upcomingCount,
                label: 'UPCOMING',
                textColor: colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildCountTile(
                context,
                count: summary.completedCount,
                label: 'COMPLETED',
                textColor: semanticColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildCountTile(
                context,
                count: summary.cancelledCount,
                label: 'CANCELLED',
                textColor: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildCountTile(
                context,
                count: summary.missedCount,
                label: 'MISSED',
                textColor: semanticColors.vitalTemperature,
              ),
            ),
          ],
        ),

        // Next Appointment Snippet Card
        if (summary.nextUpcomingAppointment != null) ...[
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => context.pushGuarded(
              AppRoutes.appointmentDetail(summary.nextUpcomingAppointment!.id),
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
                    'Next: ${summary.nextUpcomingAppointment!.title}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(summary.nextUpcomingAppointment!.date)} · ${summary.nextUpcomingAppointment!.doctorName}',
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

  Widget _buildCountTile(
    BuildContext context, {
    required int count,
    required String label,
    required Color textColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
            '$count',
            style: AppTypography.h1.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
