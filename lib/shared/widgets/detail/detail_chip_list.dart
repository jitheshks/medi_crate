import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';

/// DetailChipList renders a wrap layout of rounded metadata chips.
class DetailChipList extends StatelessWidget {
  final List<String> chips;
  final Color? chipBackgroundColor;
  final Color? chipTextColor;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;

  const DetailChipList({
    super.key,
    required this.chips,
    this.chipBackgroundColor,
    this.chipTextColor,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 11.0, vertical: 5.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveBg = chipBackgroundColor ?? colorScheme.primaryContainer;
    final effectiveTextColor = chipTextColor ?? colorScheme.onPrimaryContainer;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: chips.map((chipText) {
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            chipText,
            style: TextStyle(
              color: effectiveTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }
}
