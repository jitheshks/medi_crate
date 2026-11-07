import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/attachments/models/attachment_item.dart';
import '../../../../shared/attachments/presentation/reusable_attachment_tile.dart';
import '../../data/models/consultation_attachment.dart';

/// ConsultationAttachmentTile displays a single attachment with icon, name, size,
/// offline status, preview/download capability, and optional removal action.
class ConsultationAttachmentTile extends StatelessWidget {
  final ConsultationAttachment attachment;
  final VoidCallback? onRemove;
  final Future<File?> Function()? onDownload;
  final VoidCallback? onTap;

  const ConsultationAttachmentTile({
    super.key,
    required this.attachment,
    this.onRemove,
    this.onDownload,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ReusableAttachmentTile(
      attachment: AttachmentItem.fromConsultationAttachment(attachment),
      onRemove: onRemove,
      onDownload: onDownload,
      onTapOverride: onTap,
    );
  }
}
