import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../models/attachment_item.dart';
import 'attachment_action_sheet.dart';
import 'attachment_preview_screen.dart';

/// Reusable attachment tile widget that can be embedded anywhere in MediCrate
/// (Reports, Consultations, etc.) with automatic local caching check,
/// authenticated background download, preview, and error management.
class ReusableAttachmentTile extends StatefulWidget {
  final AttachmentItem attachment;
  final Future<File?> Function()? onDownload;
  final VoidCallback? onRemove;
  final VoidCallback? onTapOverride;

  const ReusableAttachmentTile({
    super.key,
    required this.attachment,
    this.onDownload,
    this.onRemove,
    this.onTapOverride,
  });

  @override
  State<ReusableAttachmentTile> createState() => _ReusableAttachmentTileState();
}

class _ReusableAttachmentTileState extends State<ReusableAttachmentTile> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final att = widget.attachment;
    final isPdf = att.isPdf;
    final isImg = att.isImage;
    final isLocal = att.isLocalAvailable;

    final iconColor = isPdf
        ? colorScheme.error
        : (isImg ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: isLocal
              ? colorScheme.outline.withValues(alpha: 0.6)
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: widget.onTapOverride ?? _handleTap,
          onLongPress: _handleLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isDownloading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(
                          isPdf
                              ? AppIcons.fileText
                              : (isImg
                                    ? Icons.image_outlined
                                    : Icons.insert_drive_file_outlined),
                          color: iconColor,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        att.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            att.formattedSize,
                            style: AppTypography.caption.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isLocal)
                            Icon(
                              Icons.cloud_download_outlined,
                              size: 13,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.onRemove != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: widget.onRemove,
                  ),
                ] else if (!isLocal && !_isDownloading) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    final att = widget.attachment;
    if (att.isLocalAvailable) {
      _navigateToPreview(File(att.filePath!));
      return;
    }

    if (widget.onDownload == null) {
      context.showErrorSnackBar('No download handler available for this file.');
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final downloadedFile = await widget.onDownload!();
      if (!mounted) return;
      setState(() => _isDownloading = false);

      if (downloadedFile != null && downloadedFile.existsSync()) {
        _navigateToPreview(downloadedFile);
      } else {
        context.showErrorSnackBar(
          'This file is not available locally or on the server.',
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      context.showErrorSnackBar(_downloadErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      context.showErrorSnackBar('Attachment download failed.');
    }
  }

  void _handleLongPress() {
    AttachmentActionSheet.show(
      context,
      attachment: widget.attachment,
      onDownload: widget.onDownload != null
          ? () async {
              setState(() => _isDownloading = true);
              try {
                final file = await widget.onDownload!();
                if (mounted) setState(() => _isDownloading = false);
                if (file != null && mounted) {
                  _navigateToPreview(file);
                }
                return file;
              } catch (_) {
                if (mounted) setState(() => _isDownloading = false);
                return null;
              }
            }
          : null,
    );
  }

  void _navigateToPreview(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewScreen(
          attachment: widget.attachment.copyWith(filePath: file.path),
          localFile: file,
        ),
      ),
    );
  }

  String _downloadErrorMessage(AppException e) {
    if (e.isNetworkError) {
      return 'You appear to be offline. Check your connection and try again.';
    }
    if (e.isNotFound) {
      return 'This attachment is no longer available on the server.';
    }
    if (e.isAuthError || e.isForbidden) {
      return "You don't have permission to download this file.";
    }
    if (e.isServerError) {
      return e.message.isNotEmpty
          ? e.message
          : 'MediCrate is temporarily unavailable. Please try again later.';
    }
    return e.message.isNotEmpty ? e.message : 'Attachment download failed.';
  }
}
