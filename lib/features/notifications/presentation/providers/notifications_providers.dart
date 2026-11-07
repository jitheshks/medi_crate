import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

/// Provides the singleton [NotificationRepository] instance backed by HiveService.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return NotificationRepository(hiveService: hiveService);
});

/// AsyncNotifier managing profile-scoped notifications list state and actions.
class NotificationsListNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    final repository = ref.watch(notificationRepositoryProvider);
    return repository.getNotifications(activeProfile.profileId);
  }

  /// Refreshes the notifications list for the active profile.
  Future<void> refresh() async {
    state = const AsyncLoading<List<NotificationModel>>();
    state = await AsyncValue.guard(() async {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) return [];
      final repository = ref.read(notificationRepositoryProvider);
      return repository.getNotifications(activeProfile.profileId);
    });
  }

  /// Marks a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAsRead(activeProfile.profileId, notificationId);

    // Optimistically update list state
    final current = state.value;
    if (current != null) {
      final updated = current.map((notif) {
        if (notif.id == notificationId) {
          return notif.copyWith(isRead: true);
        }
        return notif;
      }).toList();
      state = AsyncValue.data(updated);
    } else {
      await refresh();
    }
  }

  /// Marks all notifications for the active profile as read.
  Future<void> markAllAsRead() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAllAsRead(activeProfile.profileId);

    // Optimistically update all items to read
    final current = state.value;
    if (current != null) {
      final updated = current
          .map((notif) => notif.copyWith(isRead: true))
          .toList();
      state = AsyncValue.data(updated);
    } else {
      await refresh();
    }
  }

  /// Deletes a notification from Hive and updates the local state.
  Future<void> deleteNotification(String notificationId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repository = ref.read(notificationRepositoryProvider);
    await repository.deleteNotification(
      activeProfile.profileId,
      notificationId,
    );

    final current = state.value;
    if (current != null) {
      final updated = current.where((n) => n.id != notificationId).toList();
      state = AsyncValue.data(updated);
    } else {
      await refresh();
    }
  }
}

/// Provides the reactive list of notifications for the active profile.
final notificationsListProvider =
    AsyncNotifierProvider<NotificationsListNotifier, List<NotificationModel>>(
      NotificationsListNotifier.new,
    );

/// Provides the active profile's unread notifications count for badge display.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return 0;

  final notificationsAsync = ref.watch(notificationsListProvider);
  return notificationsAsync.when(
    data: (notifications) => notifications
        .where(
          (notif) =>
              !notif.isRead && notif.profileId == activeProfile.profileId,
        )
        .length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});
