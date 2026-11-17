import 'package:material_ui/material_ui.dart';

/// DetailInfoRow renders a single labeled data row with an icon, label, value, and optional tap action.
class DetailInfoRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final double iconSize;
  final double iconBoxSize;
  final double iconBoxRadius;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const DetailInfoRow({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.iconSize = 18.0,
    this.iconBoxSize = 34.0,
    this.iconBoxRadius = 10.0,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayValue = (value != null && value!.trim().isNotEmpty)
        ? value!.trim()
        : '—';

    Widget rowContent = Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: iconBackground ?? colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(iconBoxRadius),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.04 * 10.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      rowContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: rowContent,
      );
    }

    if (showDivider) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          rowContent,
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline,
            indent: 16,
            endIndent: 16,
          ),
        ],
      );
    }

    return rowContent;
  }
}
