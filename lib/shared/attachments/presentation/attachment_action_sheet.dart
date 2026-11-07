import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../widgets/sheets/app_bottom_sheet.dart';
import '../models/attachment_item.dart';
import '../services/attachment_launcher.dart';
import 'attachment_preview_screen.dart';

/// Bottom sheet displaying contextual actions for an attachment:
/// Preview, Open with External App, Share, and Re-download.
class AttachmentActionSheet extends StatelessWidget {
  final AttachmentItem attachment;
  final Future<File?> Function()? onDownload;

  const AttachmentActionSheet({
    super.key,
    required this.attachment,
    this.onDownload,
  });

  static Future<void> show(
    BuildContext context, {
    required AttachmentItem attachment,
    Future<File?> Function()? onDownload,
  }) {
    return AppBottomSheet.show(
      context: context,
      builder: (ctx) =>
          AttachmentActionSheet(attachment: attachment, onDownload: onDownload),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLocal = attachment.isLocalAvailable;
    final isPreviewable = attachment.isPdf || attachment.isImage;

    return AppBottomSheet(
      showDragHandle: true,
      showCloseButton: false,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (attachment.isPdf
                              ? colorScheme.error
                              : colorScheme.primary)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  attachment.isPdf
                      ? AppIcons.fileText
                      : (attachment.isImage
                            ? Icons.image_outlined
                            : Icons.insert_drive_file_outlined),
                  color: attachment.isPdf
                      ? colorScheme.error
                      : colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          attachment.formattedSize,
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isLocal
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLocal ? 'Offline Ready' : 'On Server',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isLocal
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (isPreviewable && isLocal)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Preview'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AttachmentPreviewScreen(
                      attachment: attachment,
                      localFile: File(attachment.filePath!),
                    ),
                  ),
                );
              },
            ),
          if (isLocal) ...[
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open with External App'),
              onTap: () async {
                Navigator.of(context).pop();
                final res = await AttachmentLauncher.openFile(
                  attachment.filePath!,
                );
                if (context.mounted && res.status != OpenFileStatus.success) {
                  context.showErrorSnackBar(res.message);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share File'),
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await AttachmentLauncher.shareFile(
                  filePath: attachment.filePath!,
                  mimeType: attachment.fileType,
                  subject: attachment.name,
                );
                if (!ok && context.mounted) {
                  context.showErrorSnackBar('Unable to share this file.');
                }
              },
            ),
          ],
          if (onDownload != null)
            ListTile(
              leading: Icon(isLocal ? Icons.refresh : Icons.download_outlined),
              title: Text(isLocal ? 'Re-download File' : 'Download File'),
              onTap: () async {
                Navigator.of(context).pop();
                await onDownload!();
              },
            ),
        ],
      ),
    );
  }
}
