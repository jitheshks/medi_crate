import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';

/// UpcomingAppointmentsSection renders the next scheduled appointment or empty CTA.
class UpcomingAppointmentsSection extends StatelessWidget {
  final String? appointmentId;
  final String? title;
  final DateTime? date;
  final String? doctorName;
  final int upcomingCount;

  const UpcomingAppointmentsSection({
    super.key,
    this.appointmentId,
    this.title,
    this.date,
    this.doctorName,
    this.upcomingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAppointment =
        appointmentId != null &&
        appointmentId!.isNotEmpty &&
        title != null &&
        title!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                upcomingCount > 0
                    ? 'Upcoming Appointments ($upcomingCount)'
                    : 'Upcoming Appointments',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.pushGuarded(AppRoutes.appointments),
              child: Text(
                'View all >',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasAppointment)
          _buildEmptyState(context)
        else
          _buildAppointmentCard(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.calendar,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No upcoming appointments scheduled',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep track of your scheduled consultations and follow-up visits.',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 180,
            height: 42,
            child: PrimaryButton(
              text: 'Plan appointment',
              onPressed: () => context.pushGuarded(AppRoutes.appointmentNew),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = date != null
        ? DateFormat('d MMM yyyy · HH:mm').format(date!)
        : '';
    final doctor = (doctorName != null && doctorName!.isNotEmpty)
        ? doctorName!
        : 'Doctor';

    return InkWell(
      onTap: () {
        if (appointmentId != null && appointmentId!.isNotEmpty) {
          context.pushGuarded(AppRoutes.appointmentDetail(appointmentId!));
        } else {
          context.pushGuarded(AppRoutes.appointments);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title!,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate.isNotEmpty ? '$formattedDate · $doctor' : doctor,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
