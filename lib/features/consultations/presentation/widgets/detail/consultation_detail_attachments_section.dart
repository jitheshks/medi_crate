import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../data/models/consultation_model.dart';
import '../../providers/consultation_providers.dart';
import '../consultation_attachment_tile.dart';

class ConsultationDetailAttachmentsSection extends ConsumerWidget {
  final ConsultationModel consultation;

  const ConsultationDetailAttachmentsSection({
    super.key,
    required this.consultation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final attachments = consultation.attachments;

    if (attachments.isEmpty) {
      return DashedCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No attachments on this consultation.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: attachments
          .map(
            (att) => ConsultationAttachmentTile(
              attachment: att,
              onDownload: () => ref
                  .read(consultationRepositoryProvider)
                  .getOrDownloadAttachmentFile(
                    profileId: consultation.profileId,
                    consultationId: consultation.id,
                    attachment: att,
                  ),
            ),
          )
          .toList(),
    );
  }
}
