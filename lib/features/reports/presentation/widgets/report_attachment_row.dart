import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/attachments/models/attachment_item.dart';
import '../../../../shared/attachments/presentation/reusable_attachment_tile.dart';
import '../../data/models/report_model.dart';
import '../providers/reports_providers.dart';

/// Reusable attachment row widget for View Report details screen with R6 download fallback.
class ReportAttachmentRow extends ConsumerWidget {
  final ReportAttachmentModel attachment;
  final String? reportId;
  final String? profileId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ReportAttachmentRow({
    super.key,
    required this.attachment,
    this.reportId,
    this.profileId,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReusableAttachmentTile(
      attachment: AttachmentItem.fromReportAttachment(attachment),
      onTapOverride: onTap,
      onDownload: (reportId != null && profileId != null)
          ? () => ref
                .read(reportRepositoryProvider)
                .getOrDownloadAttachmentFile(
                  profileId: profileId!,
                  reportId: reportId!,
                  attachment: attachment,
                )
          : null,
    );
  }
}
