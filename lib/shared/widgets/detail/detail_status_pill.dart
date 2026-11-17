import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_radius.dart';

/// DetailStatusPill renders a standardized rounded status badge with a tinted background.
class DetailStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const DetailStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.fontSize = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.10);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
