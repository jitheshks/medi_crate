import 'package:flutter/material.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

/// AppEmptyState provides a standardized, pure presentation empty-state card
/// supporting both standard and filtered/search variants.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final Color? iconColor;
  final Color? iconContainerColor;
  final bool showIconContainer;
  final bool isFiltered;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
    this.iconColor,
    this.iconContainerColor,
    this.showIconContainer = true,
    this.isFiltered = false,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  const AppEmptyState.filtered({
    super.key,
    this.icon = Icons.search_off_rounded,
    this.title = 'No results found',
    this.message = 'Try adjusting your search query or active filters.',
    this.actionLabel = 'Clear filters',
    this.onAction,
    this.actionIcon = Icons.filter_alt_off,
    this.iconColor,
    this.iconContainerColor,
    this.showIconContainer = false,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  }) : isFiltered = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveIconColor =
        iconColor ??
        (isFiltered ? colorScheme.onSurfaceVariant : colorScheme.primary);

    final effectiveContainerColor =
        iconContainerColor ??
        (isFiltered
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary.withValues(alpha: 0.12));

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Semantics(
          container: true,
          label: '$title. ${message ?? ''}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showIconContainer)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: effectiveContainerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: effectiveIconColor),
                )
              else
                Icon(icon, size: 44, color: effectiveIconColor),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: AppTypography.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                if (isFiltered)
                  OutlinedButton.icon(
                    onPressed: onAction,
                    icon: actionIcon != null
                        ? Icon(actionIcon, size: 18)
                        : const SizedBox.shrink(),
                    label: Text(actionLabel!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: onAction,
                    icon: actionIcon != null
                        ? Icon(actionIcon, size: 18)
                        : const SizedBox.shrink(),
                    label: Text(actionLabel!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
