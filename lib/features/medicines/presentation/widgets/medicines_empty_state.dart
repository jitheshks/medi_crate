import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';

class MedicinesEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  const MedicinesEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.pill,
      iconColor: context.semanticColors.medicineAccent,
      iconContainerColor: context.semanticColors.medicineAccentContainer,
      title: title,
      message: subtitle,
      actionLabel: buttonText,
      actionIcon: Icons.add,
      onAction: onPressed,
    );
  }
}
