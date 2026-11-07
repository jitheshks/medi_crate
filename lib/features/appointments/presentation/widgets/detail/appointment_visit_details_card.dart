import 'package:flutter/material.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_currency.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../data/models/appointment_model.dart';

class AppointmentVisitDetailsCard extends StatelessWidget {
  final AppointmentModel appointment;
  final String formattedDateTime;

  const AppointmentVisitDetailsCard({
    super.key,
    required this.appointment,
    required this.formattedDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      DetailInfoRow(
        icon: AppIcons.stethoscope,
        label: 'DOCTOR',
        value: appointment.doctorName,
        onTap: appointment.doctorId != null
            ? () => context.pushGuarded(
                AppRoutes.doctorProfile(appointment.doctorId!),
              )
            : null,
        showDivider: true,
      ),
    ];

    if (appointment.hospitalName != null &&
        appointment.hospitalName!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: AppIcons.hospital,
          label: 'HOSPITAL / CLINIC',
          value: appointment.hospitalName!,
          onTap: appointment.hospitalId != null
              ? () => context.pushGuarded(
                  AppRoutes.hospitalProfile(appointment.hospitalId!),
                )
              : null,
          showDivider: true,
        ),
      );
    }

    if (appointment.department != null && appointment.department!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: AppIcons.calendar,
          label: 'DEPARTMENT',
          value: appointment.department!,
          showDivider: true,
        ),
      );
    }

    rows.add(
      DetailInfoRow(
        icon: Icons.access_time,
        label: 'DATE & TIME',
        value: formattedDateTime,
        showDivider: true,
      ),
    );

    rows.add(
      DetailInfoRow(
        icon: Icons.notifications_none,
        label: 'REMINDER',
        value: appointment.reminderEnabled ? 'ENABLED' : 'DISABLED',
        valueColor: appointment.reminderEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        showDivider: appointment.cost != null && appointment.cost! > 0,
      ),
    );

    if (appointment.cost != null && appointment.cost! > 0) {
      final symbol = AppCurrency.getSymbol(appointment.currency);
      rows.add(
        DetailInfoRow(
          icon: Icons.payments_outlined,
          label: 'APPOINTMENT COST',
          value: '$symbol ${appointment.cost!.toStringAsFixed(0)}',
          valueColor: Theme.of(context).colorScheme.onSurface,
          showDivider: false,
        ),
      );
    }

    return DetailInfoCard(rows: rows);
  }
}
