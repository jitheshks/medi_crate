import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../data/models/consultation_model.dart';
import '../../providers/consultation_providers.dart';

class ConsultationDetailFollowUpCard extends ConsumerWidget {
  final ConsultationModel consultation;

  const ConsultationDetailFollowUpCard({super.key, required this.consultation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticColors = context.semanticColors;

    if (!consultation.isFollowUpRequired || consultation.followUpDate == null) {
      return DashedCard(
        child: Center(
          child: Text(
            'No follow-up scheduled.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final followUpDate = consultation.followUpDate!;
    final now = DateTime.now();
    final isDone = consultation.isFollowUpDone;
    final isOverdue =
        !isDone &&
        DateTime(
          followUpDate.year,
          followUpDate.month,
          followUpDate.day,
        ).isBefore(DateTime(now.year, now.month, now.day));

    final Color borderColor;
    final Color backgroundColor;
    final Color statusColor;
    final String statusLabel;
    final String actionBtnLabel;

    if (isDone) {
      borderColor = semanticColors.success.withValues(alpha: 0.5);
      backgroundColor = semanticColors.successContainer;
      statusColor = semanticColors.success;
      statusLabel = 'FOLLOW-UP DONE';
      actionBtnLabel = 'MARK PENDING';
    } else if (isOverdue) {
      borderColor = colorScheme.error.withValues(alpha: 0.5);
      backgroundColor = colorScheme.errorContainer;
      statusColor = colorScheme.error;
      statusLabel = 'FOLLOW-UP OVERDUE';
      actionBtnLabel = 'MARK DONE';
    } else {
      borderColor = semanticColors.warningBorder;
      backgroundColor = semanticColors.warningContainer;
      statusColor = semanticColors.vitalTemperature;
      statusLabel = 'FOLLOW-UP PENDING';
      actionBtnLabel = 'MARK DONE';
    }

    final formattedFollowUp = DateFormat('dd MMM yyyy').format(followUpDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  formattedFollowUp,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              DetailStatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: () async {
                final newStatus = !isDone;
                await ref
                    .read(consultationsListNotifierProvider.notifier)
                    .updateFollowUpStatus(consultation.id, isDone: newStatus);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor, width: 1.5),
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionBtnLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
