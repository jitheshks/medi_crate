import 'package:flutter/material.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';

class AppointmentSelectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueText;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final String? actionTooltip;

  const AppointmentSelectorTile({
    super.key,
    required this.icon,
    required this.label,
    required this.valueText,
    required this.isSet,
    required this.onTap,
    this.onClear,
    this.onActionPressed,
    this.actionIcon,
    this.actionTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valueText,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isSet ? FontWeight.w700 : FontWeight.w500,
                        color: isSet
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onClear != null) ...[
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: onClear,
                ),
              ],
              if (onActionPressed != null && actionIcon != null) ...[
                IconButton(
                  icon: Icon(actionIcon, size: 20),
                  color: theme.colorScheme.primary,
                  tooltip: actionTooltip,
                  onPressed: onActionPressed,
                ),
              ],
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
