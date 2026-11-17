import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../widgets/feedback/pulsing_vault_logo.dart';
import '../models/attachment_item.dart';
import '../services/attachment_launcher.dart';

/// Full-screen viewer for medical attachments supporting PDF documents,
/// high-resolution zoomable images, and actions for saving/downloading, external opening, and sharing.
class AttachmentPreviewScreen extends StatefulWidget {
  final AttachmentItem attachment;
  final File? localFile;
  final Future<File?> Function()? onDownload;

  const AttachmentPreviewScreen({
    super.key,
    required this.attachment,
    this.localFile,
    this.onDownload,
  });

  @override
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<AttachmentPreviewScreen> {
  File? _currentFile;
  bool _isSaving = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentFile = _resolveEffectiveFile();
  }

  File? _resolveEffectiveFile() {
    if (widget.localFile != null && widget.localFile!.existsSync()) {
      return widget.localFile;
    }
    if (widget.attachment.filePath != null &&
        widget.attachment.filePath!.isNotEmpty) {
      final f = File(widget.attachment.filePath!);
      if (f.existsSync()) return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final file = _currentFile ?? _resolveEffectiveFile();
    final fileExists = file != null && file.existsSync();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h3.copyWith(
                color: colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            Text(
              widget.attachment.formattedSize,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (fileExists) ...[
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: 'Download / Save to Device',
              onPressed: _isSaving ? null : () => _handleSaveToDevice(file),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Attachment',
              onPressed: () => _handleShare(context, file.path),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open Externally',
              onPressed: () => _handleOpenExternally(context, file.path),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: !fileExists
            ? _buildMissingFileState(context)
            : widget.attachment.isPdf
            ? _buildPdfViewer(context, file)
            : widget.attachment.isImage
            ? _buildImageViewer(context, file)
            : _buildUnsupportedFormatState(context, file.path),
      ),
    );
  }

  Widget _buildPdfViewer(BuildContext context, File file) {
    return PdfPreview(
      build: (PdfPageFormat format) async {
        return await file.readAsBytes();
      },
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: widget.attachment.name,
      loadingWidget: const Center(child: PulsingVaultLogo()),
      onError: (ctx, error) => _buildErrorWidget(
        ctx,
        'Unable to render this PDF file. It may be corrupt or encrypted.',
      ),
    );
  }

  Widget _buildImageViewer(BuildContext context, File file) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(20),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) =>
                    _buildErrorWidget(ctx, 'Unable to render this image file.'),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissingFileState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'File Not Cached Locally',
              style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'This attachment has not been downloaded to your device storage yet.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.onDownload != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isDownloading ? null : _handleDownloadFromRemote,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_download_rounded, size: 18),
                label: Text(
                  _isDownloading ? 'Downloading...' : 'Download Attachment',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleDownloadFromRemote() async {
    if (widget.onDownload == null || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final downloaded = await widget.onDownload!();
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        if (downloaded != null && downloaded.existsSync()) {
          _currentFile = downloaded;
        }
      });
      if (downloaded != null && downloaded.existsSync()) {
        context.showSuccessSnackBar('Attachment downloaded successfully.');
      } else {
        context.showErrorSnackBar('Unable to download attachment.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      context.showErrorSnackBar('Download failed: $e');
    }
  }

  Future<void> _handleSaveToDevice(File file) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final result = await AttachmentLauncher.saveAttachmentToDevice(
        localFile: file,
        fileName: widget.attachment.name,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result.success) {
        context.showSuccessSnackBar(result.message);
      } else {
        context.showErrorSnackBar(result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showErrorSnackBar('Failed to save file: $e');
    }
  }

  Widget _buildUnsupportedFormatState(BuildContext context, String path) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = widget.attachment.fileExtension.toUpperCase();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: colorScheme.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.fileText, size: 56, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  widget.attachment.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.h3.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Format: $ext • ${widget.attachment.formattedSize}',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'In-app preview is not available for .$ext files. '
                  'You can save, open this document using a compatible external app, or share it.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _handleSaveToDevice(File(path)),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Save to Device'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _handleOpenExternally(context, path),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open File'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _handleShare(context, path),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Display Attachment',
              style: AppTypography.h3.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOpenExternally(BuildContext context, String path) async {
    final result = await AttachmentLauncher.openFile(path);
    if (!context.mounted) return;
    if (result.status != OpenFileStatus.success) {
      context.showErrorSnackBar(result.message);
    }
  }

  Future<void> _handleShare(BuildContext context, String path) async {
    final success = await AttachmentLauncher.shareFile(
      filePath: path,
      mimeType: widget.attachment.fileType,
      subject: widget.attachment.name,
    );
    if (!success && context.mounted) {
      context.showErrorSnackBar('Unable to share this file.');
    }
  }
}
