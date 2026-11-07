import 'package:flutter/material.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import 'profile_form_dialog.dart';

class FamilyProfilesEmptyState extends StatelessWidget {
  const FamilyProfilesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.people_outline,
      title: 'No family profiles created yet.',
      actionLabel: 'Add First Profile',
      onAction: () => ProfileFormDialog.show(context),
    );
  }
}
