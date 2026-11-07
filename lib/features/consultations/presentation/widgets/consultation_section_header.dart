import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';

/// Section header displaying uppercase label for consultation form sections.
class ConsultationSectionHeader extends StatelessWidget {
  final String label;

  const ConsultationSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
