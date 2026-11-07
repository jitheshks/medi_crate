import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

class AppointmentsEmptyState extends StatelessWidget {
  final bool isCompletelyEmpty;
  final VoidCallback? onClear;

  const AppointmentsEmptyState({
    super.key,
    required this.isCompletelyEmpty,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCompletelyEmpty) {
      return AppEmptyState.filtered(
        title: 'No Matching Appointments Found',
        message: 'Try adjusting your search query or status filter.',
        actionLabel: onClear != null ? 'Clear filters' : null,
        onAction: onClear,
      );
    }

    return AppEmptyState(
      icon: AppIcons.calendar,
      title: 'No Appointments Scheduled',
      message: 'Schedule doctor consultations and reviews with reminders to keep your health on track.',
      actionLabel: 'Schedule Appointment',
      actionIcon: Icons.add,
      onAction: () => context.pushGuarded(AppRoutes.newAppointment),
    );
  }
}
