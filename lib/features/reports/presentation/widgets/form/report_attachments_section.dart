import 'package:flutter/material.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../data/models/report_model.dart';

class ReportAttachmentsSection extends StatelessWidget {
  final List<ReportAttachmentModel> attachments;
  final VoidCallback onAddAttachment;
  final ValueChanged<int> onRemoveAttachment;

  const ReportAttachmentsSection({
    super.key,
    required this.attachments,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
  });

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
              'ATTACHMENTS *',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            TextButton.icon(
              onPressed: onAddAttachment,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add attachment'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (attachments.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              side: BorderSide(color: colorScheme.outline),
            ),
            color: colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No file attachments added yet',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attachments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final att = attachments[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  side: BorderSide(color: colorScheme.outline),
                ),
                color: colorScheme.surface,
                child: ListTile(
                  leading: Icon(AppIcons.paperclip, color: colorScheme.primary),
                  title: Text(
                    att.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    att.size,
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onRemoveAttachment(index),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
