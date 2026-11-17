import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../features/consultations/data/models/consultation_model.dart';
import 'detail_linked_record_card.dart';

/// DetailLinkedConsultationCard renders a tappable card representing a linked consultation.
class DetailLinkedConsultationCard extends StatelessWidget {
  final ConsultationModel consultation;
  final String? contextLabel;
  final String? subtitle;
  final VoidCallback? onTap;

  const DetailLinkedConsultationCard({
    super.key,
    required this.consultation,
    this.contextLabel,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String effectiveSubtitle;
    if (subtitle != null) {
      effectiveSubtitle = subtitle!;
    } else {
      final dateStr = DateFormat('dd MMM yyyy').format(consultation.visitDate);
      if (contextLabel != null && contextLabel!.isNotEmpty) {
        effectiveSubtitle = '$dateStr · $contextLabel';
      } else {
        effectiveSubtitle = dateStr;
      }
    }

    return DetailLinkedRecordCard(
      title: consultation.diagnosis.isNotEmpty
          ? consultation.diagnosis
          : 'Consultation',
      subtitle: effectiveSubtitle,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(AppIcons.stethoscope, color: colorScheme.primary, size: 20),
      ),
      onTap:
          onTap ??
          () => context.pushGuarded(
            AppRoutes.consultationDetail(consultation.id),
          ),
    );
  }
}
