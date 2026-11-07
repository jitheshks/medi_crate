import 'package:flutter/material.dart';

/// DetailSectionHeader renders an uppercase section title with standard typography and letter spacing.
class DetailSectionHeader extends StatelessWidget {
  final String title;
  final double topPadding;
  final double bottomPadding;
  final Color? color;

  const DetailSectionHeader({
    super.key,
    required this.title,
    this.topPadding = 20.0,
    this.bottomPadding = 8.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08 * 10.5,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
