import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../data/models/insights_summary_model.dart';

class ConsultationsActivityCard extends StatelessWidget {
  final ConsultationSummaryData summary;

  const ConsultationsActivityCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONSULTATIONS',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            InkWell(
              onTap: () => context.pushGuarded(AppRoutes.consultations),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Text(
                    'View History',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
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
        InkWell(
          onTap: () {
            if (summary.latestConsultation != null) {
              context.pushGuarded(
                AppRoutes.consultationDetail(summary.latestConsultation!.id),
              );
            } else {
              context.pushGuarded(AppRoutes.consultations);
            }
          },
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
            child: summary.totalCount == 0
                ? Text(
                    'No consultations recorded yet.',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.latestConsultation?.diagnosis ??
                            'General Health Consultation',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildSubtitleText(),
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
    );
  }

  String _buildSubtitleText() {
    final parts = <String>[];
    if (summary.latestConsultation != null) {
      parts.add(
        'Last visit ${DateFormat('dd MMM yyyy').format(summary.latestConsultation!.visitDate)}',
      );
    }
    parts.add('${summary.totalCount} total');
    if (summary.topDoctorName != null && summary.topDoctorName!.isNotEmpty) {
      parts.add('Most seen: ${summary.topDoctorName}');
    }
    return parts.join(' · ');
  }
}
