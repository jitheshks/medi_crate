import 'package:flutter/material.dart';
import 'package:medivalut/core/constants/app_icons.dart';
import 'package:medivalut/core/constants/app_spacing.dart';
import 'package:medivalut/core/constants/app_typography.dart';

/// Pure presentation card tile for entity summaries.
class EntityTileCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? phone;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const EntityTileCard({
    super.key,
    required this.title,
    this.subtitle,
    this.phone,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final hasPhone = phone != null && phone!.isNotEmpty;

    final Widget? subtitleWidget;
    if (hasSubtitle || hasPhone) {
      subtitleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSubtitle) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (hasPhone) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  AppIcons.phone,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    phone!,
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    } else {
      subtitleWidget = null;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline, width: 1.2),
      ),
      color: colorScheme.surface,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: subtitleWidget,
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
      ),
    );
  }
}
