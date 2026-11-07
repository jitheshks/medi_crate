import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';

/// DetailInfoCard renders a structured white card containing information rows or custom children.
class DetailInfoCard extends StatelessWidget {
  final List<Widget>? rows;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  const DetailInfoCard({
    super.key,
    this.rows,
    this.child,
    this.padding,
    this.borderRadius = AppRadius.card,
    this.backgroundColor,
    this.borderColor,
  }) : assert(
         rows != null || child != null,
         'Either rows or child must be provided to DetailInfoCard',
       );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? colorScheme.outline, width: 1),
      ),
      child: child ?? Column(mainAxisSize: MainAxisSize.min, children: rows!),
    );
  }
}
