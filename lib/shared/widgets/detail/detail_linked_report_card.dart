import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../features/reports/data/models/report_model.dart';
import '../../../features/reports/presentation/widgets/report_type_badge.dart';
import 'detail_linked_record_card.dart';

/// DetailLinkedReportCard renders a tappable card representing a linked medical report.
class DetailLinkedReportCard extends StatelessWidget {
  final ReportModel report;
  final String? subtitle;
  final VoidCallback? onTap;

  const DetailLinkedReportCard({
    super.key,
    required this.report,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(report.date);
    final color = ReportTypeBadge.categoryColor(report.category, context);
    final icon = ReportTypeBadge.categoryIcon(report.category);

    return DetailLinkedRecordCard(
      title: report.title,
      subtitle: subtitle ?? '$dateStr · ${report.category}',
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      onTap:
          onTap ?? () => context.pushGuarded(AppRoutes.reportDetail(report.id)),
    );
  }
}
