import 'package:flutter/material.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

class VitalsEmptyState extends StatelessWidget {
  const VitalsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.activity,
      title: 'No measurements yet',
      message:
          'Start tracking your health measurements to keep your health record up to date.',
      actionLabel: 'Add Measurement',
      actionIcon: Icons.add,
      onAction: () => context.pushGuarded(AppRoutes.addMeasurement),
    );
  }
}

class VitalsFilteredEmptyState extends StatelessWidget {
  final VoidCallback onClearFilters;

  const VitalsFilteredEmptyState({super.key, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState.filtered(
      title: 'No measurements found',
      message: 'No measurements match your current search or filter.',
      onAction: onClearFilters,
      actionLabel: 'Clear Filters',
    );
  }
}
