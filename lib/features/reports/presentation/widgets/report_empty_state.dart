import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

/// Reusable empty state view when no reports match search or profile filters.
class ReportEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ReportEmptyState({
    super.key,
    this.title = 'No reports available.',
    this.subtitle = 'Diagnostic lab tests, prescriptions, and imaging files for this profile will appear here.',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.fileText,
      title: title,
      message: subtitle,
      actionLabel: actionLabel,
      actionIcon: Icons.add,
      onAction: onAction,
    );
  }
}
