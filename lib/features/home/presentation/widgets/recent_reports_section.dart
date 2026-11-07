import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';

/// RecentReportsSection renders lab & diagnostic report preview items or Upload CTA.
class RecentReportsSection extends StatelessWidget {
  final String? reportId;
  final String? title;
  final DateTime? date;
  final String? category;
  final String? doctorName;
  final String? hospitalName;

  const RecentReportsSection({
    super.key,
    this.reportId,
    this.title,
    this.date,
    this.category,
    this.doctorName,
    this.hospitalName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasReport =
        reportId != null &&
        reportId!.isNotEmpty &&
        title != null &&
        title!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recent Reports',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.pushGuarded(AppRoutes.reports),
              child: Text(
                'View all >',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasReport)
          _buildEmptyState(context)
        else
          _buildReportCard(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No medical reports uploaded.',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.pushGuarded(AppRoutes.reportAdd),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            icon: const SizedBox.shrink(),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upload Report',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = date != null
        ? DateFormat('d MMM yyyy').format(date!)
        : '';
    final subInfo = [
      if (formattedDate.isNotEmpty) formattedDate,
      if (category != null && category!.isNotEmpty) category!,
      if (doctorName != null && doctorName!.isNotEmpty) doctorName!,
      if (hospitalName != null && hospitalName!.isNotEmpty) hospitalName!,
    ].join(' · ');

    return InkWell(
      onTap: () {
        if (reportId != null && reportId!.isNotEmpty) {
          context.pushGuarded(AppRoutes.reportDetail(reportId!));
        } else {
          context.pushGuarded(AppRoutes.reports);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title!,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (subInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subInfo,
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
