import 'package:material_ui/material_ui.dart';

/// DetailHero renders the centered hero visual at the top of a record detail screen.
class DetailHero extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final Widget? statusPill;
  final Widget? badge;
  final double iconSize;
  final double iconBoxSize;
  final double iconBoxRadius;
  final bool isCircular;

  const DetailHero({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.statusPill,
    this.badge,
    this.iconSize = 24.0,
    this.iconBoxSize = 56.0,
    this.iconBoxRadius = 16.0,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular
                  ? null
                  : BorderRadius.circular(iconBoxRadius),
            ),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
          if (badge != null) ...[const SizedBox(height: 10), badge!],
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              height: 1.3,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (statusPill != null) ...[const SizedBox(height: 10), statusPill!],
        ],
      ),
    );
  }
}
