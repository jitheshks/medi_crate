import 'package:flutter/material.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// Clean container card wrapper for structured sections in View Report screen.
class ReportInfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  const ReportInfoCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tr = trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.toUpperCase(),
              style: AppTypography.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            ?tr,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: child,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
