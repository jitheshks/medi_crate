import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

/// Reusable empty state view when no timeline events exist or match filters.
class TimelineEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const TimelineEmptyState({
    super.key,
    this.title = 'No medical history yet.',
    this.subtitle = 'Consultations, diagnostic lab reports, vitals, prescriptions, and appointments for this profile will appear here chronologically.',
    this.actionLabel = 'Create your first health record',
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.calendar,
      title: title,
      message: subtitle,
      actionLabel: actionLabel,
      actionIcon: Icons.add,
      onAction: onAction,
    );
  }
}
