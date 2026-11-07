import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../features/appointments/data/models/appointment_model.dart';
import 'detail_linked_record_card.dart';

/// DetailLinkedAppointmentCard renders a tappable card representing a linked appointment.
class DetailLinkedAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final String? contextLabel;
  final String? subtitle;
  final VoidCallback? onTap;

  const DetailLinkedAppointmentCard({
    super.key,
    required this.appointment,
    this.contextLabel,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semanticColors = context.semanticColors;
    final String effectiveSubtitle;
    if (subtitle != null) {
      effectiveSubtitle = subtitle!;
    } else {
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a')
          .format(appointment.date);
      final contextPart = (contextLabel != null && contextLabel!.isNotEmpty)
          ? ' · $contextLabel'
          : '';
      effectiveSubtitle =
          '$dateStr$contextPart · ${appointment.status.toUpperCase()}';
    }

    return DetailLinkedRecordCard(
      title: appointment.title,
      subtitle: effectiveSubtitle,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: semanticColors.warningContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          AppIcons.calendar,
          color: semanticColors.vitalTemperature,
          size: 20,
        ),
      ),
      onTap:
          onTap ??
          () =>
              context.pushGuarded(AppRoutes.appointmentDetail(appointment.id)),
    );
  }
}
