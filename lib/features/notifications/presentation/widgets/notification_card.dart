import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnread = !notification.isRead;

    final (iconData, iconColor, iconBgColor) = _getCategoryStyle(
      notification.type,
      context,
    );

    final cardBgColor = isUnread
        ? colorScheme.primaryContainer.withValues(alpha: 0.25)
        : colorScheme.surface;

    final borderColor = isUnread
        ? colorScheme.primary.withValues(alpha: 0.25)
        : colorScheme.outline.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor, width: isUnread ? 1.2 : 1.0),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: AppTypography.h3.copyWith(
                          fontSize: 15,
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.description,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            DateFormat('d MMM yyyy · HH:mm')
                                .format(notification.date),
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _getCategoryStyle(
    NotificationType type,
    BuildContext context,
  ) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case NotificationType.appointment:
        return (
          Icons.event_outlined,
          semantic.departmentAccent,
          semantic.departmentAccentContainer,
        );
      case NotificationType.medicine:
        return (
          Icons.medication_outlined,
          semantic.medicineAccent,
          semantic.medicineAccentContainer,
        );
      case NotificationType.measurement:
        return (
          Icons.monitor_heart_outlined,
          semantic.vitalHeartRate,
          semantic.vitalHeartRateContainer,
        );
      case NotificationType.report:
        return (
          Icons.description_outlined,
          colorScheme.primary,
          colorScheme.primaryContainer,
        );
    }
  }
}
