import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

class ConsultationsEmptyState extends StatelessWidget {
  final bool isCompletelyEmpty;
  final VoidCallback onClearFilters;

  const ConsultationsEmptyState({
    super.key,
    required this.isCompletelyEmpty,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompletelyEmpty) {
      return AppEmptyState(
        icon: AppIcons.stethoscope,
        title: 'No consultations recorded yet.',
        message: 'Keep track of your clinical visits, doctor notes, diagnoses, and follow-up schedules in one place.',
      );
    }

    return AppEmptyState.filtered(
      title: 'No consultations match your filters.',
      message: 'Try searching for a different term or clear active search and status filters.',
      onAction: onClearFilters,
      actionLabel: 'Clear Filters',
    );
  }
}
