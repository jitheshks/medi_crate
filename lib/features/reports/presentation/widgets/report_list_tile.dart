import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../data/models/report_model.dart';
import 'report_type_badge.dart';

/// Reusable report list item widget representing a diagnostic report card.
class ReportListTile extends StatelessWidget {
  final ReportModel report;
  final VoidCallback? onTap;

  const ReportListTile({super.key, required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('d MMM yyyy').format(report.date);
    final doctorText =
        (report.doctorName != null && report.doctorName!.trim().isNotEmpty)
        ? report.doctorName!
        : 'Unassigned';
    final hospitalText =
        (report.hospitalName != null && report.hospitalName!.trim().isNotEmpty)
        ? report.hospitalName!
        : 'Unassigned Hospital';

    final categoryColor = ReportTypeBadge.categoryColor(
      report.category,
      context,
    );
    final categoryIcon = ReportTypeBadge.categoryIcon(report.category);
    final hasAttachments = report.attachments.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label:
          '${report.title}, ${report.category}, $formattedDate, $doctorText, $hospitalText',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colorScheme.outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap:
                onTap ??
                () => context.pushGuarded(AppRoutes.reportDetail(report.id)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leading Icon Box
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 14),

                  // Middle details column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Badge & Attachment indicator row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: ReportTypeBadge(category: report.category),
                            ),
                            if (hasAttachments) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.paperclip,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${report.attachments.length}',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Metadata line (Date · Doctor · Hospital)
                        Text(
                          '$formattedDate · $doctorText · $hospitalText',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Trailing Chevron
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Icon(
                      AppIcons.chevronRight,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
