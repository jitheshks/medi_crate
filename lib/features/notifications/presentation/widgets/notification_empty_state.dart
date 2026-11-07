import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: AppIcons.bell,
      title: "You're all caught up.",
      message: 'New reminders and record updates will show up here.',
    );
  }
}
