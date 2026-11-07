import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_providers.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_empty_state.dart';

/// NotificationsScreen displays real-time, profile-scoped in-app notifications and alerts.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unreadCount > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.home),
        ),
        title: Text(
          'Notifications',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: hasUnread
                ? () {
                    ref
                        .read(notificationsListProvider.notifier)
                        .markAllAsRead();
                  }
                : null,
            child: Text(
              'Mark all read',
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasUnread
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: PulsingVaultLogo()),
        error: (err, stack) => AppErrorState(
          error: err,
          title: 'Unable to Load Notifications',
          onRetry: () => ref.read(notificationsListProvider.notifier).refresh(),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const NotificationEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: notifications.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationCard(
                notification: notification,
                onTap: () => _handleNotificationTap(context, ref, notification),
              );
            },
          );
        },
      ),
    );
  }

  /// Handles notification tap: marks as read and deep-links to destination if applicable.
  Future<void> _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) async {
    if (!notification.isRead) {
      await ref
          .read(notificationsListProvider.notifier)
          .markAsRead(notification.id);
    }

    if (!context.mounted) return;

    final linkType = notification.linkType?.toLowerCase();
    final linkId = notification.linkId;

    if (linkType == 'appointment' && linkId != null && linkId.isNotEmpty) {
      context.pushGuarded(AppRoutes.appointmentDetail(linkId));
    } else if (linkType == 'report' && linkId != null && linkId.isNotEmpty) {
      context.pushGuarded(AppRoutes.reportDetail(linkId));
    } else if (linkType == 'medicine' && linkId != null && linkId.isNotEmpty) {
      context.pushGuarded(AppRoutes.medicineDetail(linkId));
    } else if (linkType == 'measurement' ||
        linkType == 'measurements' ||
        linkType == 'vital' ||
        linkType == 'vitals') {
      context.pushGuarded(AppRoutes.measurements);
    }
  }
}
