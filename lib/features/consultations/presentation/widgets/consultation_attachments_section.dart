import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../data/models/consultation_attachment.dart';
import 'consultation_attachment_tile.dart';
import 'consultation_section_header.dart';

/// ConsultationAttachmentsSection handles picking, listing, and removing attachments
/// in the Add/Edit Consultation form.
class ConsultationAttachmentsSection extends StatelessWidget {
  final List<ConsultationAttachment> attachments;
  final ValueChanged<List<ConsultationAttachment>> onAttachmentsChanged;
  final String? profileId;

  const ConsultationAttachmentsSection({
    super.key,
    required this.attachments,
    required this.onAttachmentsChanged,
    this.profileId,
  });

  Future<void> _pickFiles(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      final updatedList = List<ConsultationAttachment>.from(attachments);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      String? targetDir;
      if (profileId != null && profileId!.isNotEmpty) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final dir = Directory(
            '${appDir.path}/profiles/$profileId/consultations/attachments',
          );
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          targetDir = dir.path;
        } catch (_) {}
      }

      for (int i = 0; i < pickedFiles.length; i++) {
        final xfile = pickedFiles[i];
        final uniqueId = 'att_${timestamp}_$i';
        final originalName = xfile.name.isNotEmpty
            ? xfile.name
            : xfile.path.split('/').last;

        int sizeKb = 1;
        String filePath = xfile.path;
        try {
          final file = File(xfile.path);
          if (await file.exists()) {
            final bytes = await file.length();
            final calcKb = (bytes / 1024).round();
            sizeKb = calcKb > 0 ? calcKb : 1;

            if (targetDir != null) {
              final destPath = '$targetDir/${uniqueId}_$originalName';
              await file.copy(destPath);
              filePath = destPath;
            }
          }
        } catch (_) {}

        final ext = originalName.contains('.')
            ? originalName.split('.').last.toLowerCase()
            : 'jpg';

        updatedList.add(
          ConsultationAttachment(
            id: uniqueId,
            name: originalName,
            sizeKB: sizeKb,
            filePath: filePath,
            fileType: 'image/$ext',
          ),
        );
      }

      onAttachmentsChanged(updatedList);
    } catch (_) {
      if (!context.mounted) return;
      context.showErrorSnackBar(
        "We couldn't process the selected files. Please try again.",
      );
    }
  }

  void _removeAttachment(String attachmentId) {
    final updatedList = attachments
        .where((item) => item.id != attachmentId)
        .toList();
    onAttachmentsChanged(updatedList);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ConsultationSectionHeader(label: 'Attachments (Optional)'),
        InkWell(
          onTap: () => _pickFiles(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: colorScheme.outline,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_upward_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Add prescription or report photo',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...attachments.map(
            (att) => ConsultationAttachmentTile(
              attachment: att,
              onRemove: () => _removeAttachment(att.id),
            ),
          ),
        ],
      ],
    );
  }
}
