import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';

/// SettingsGroupCard wraps a section with an uppercase header and bordered container.
class SettingsGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroupCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outline, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
