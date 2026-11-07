import '../../../../core/storage/hive_service.dart';
import '../models/notification_model.dart';

/// NotificationRepository manages profile-scoped notifications in Hive local storage.
class NotificationRepository {
  final HiveService hiveService;

  NotificationRepository({required this.hiveService});

  /// Normalizes key prefix for notification storage in userBox.
  String _normalizeNotificationId(String rawId) {
    if (rawId.startsWith('notification_')) return rawId;
    return 'notification_$rawId';
  }

  /// Retrieves typed [NotificationModel] list scoped to [profileId], sorted newest-first.
  Future<List<NotificationModel>> getNotifications(String profileId) async {
    if (profileId.isEmpty) return [];

    final box = hiveService.userBox;
    final notifications = <NotificationModel>[];

    for (final key in box.keys) {
      if (key.toString().startsWith('notification_')) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          if (map['profile_id'] == profileId || map['profileId'] == profileId) {
            notifications.add(NotificationModel.fromJson(map));
          }
        }
      }
    }

    // Sort newest-first
    notifications.sort((a, b) => b.date.compareTo(a.date));
    return notifications;
  }

  /// Fetches a single typed [NotificationModel] by ID for [profileId].
  Future<NotificationModel?> getNotificationById(
    String profileId,
    String notificationId,
  ) async {
    final key = _normalizeNotificationId(notificationId);
    final box = hiveService.userBox;
    final val = box.get(key);
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      if (map['profile_id'] == profileId || map['profileId'] == profileId) {
        return NotificationModel.fromJson(map);
      }
    }
    return null;
  }

  /// Saves a notification into Hive for [profileId].
  Future<NotificationModel> saveNotification(
    NotificationModel notification,
  ) async {
    final key = _normalizeNotificationId(notification.id);
    final payload = notification.toJson();
    payload['id'] = notification.id;
    payload['profile_id'] = notification.profileId;

    final box = hiveService.userBox;
    await box.put(key, payload);
    return notification;
  }

  /// Marks a single notification as read.
  Future<void> markAsRead(String profileId, String notificationId) async {
    final key = _normalizeNotificationId(notificationId);
    final box = hiveService.userBox;
    final val = box.get(key);
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      if (map['profile_id'] == profileId || map['profileId'] == profileId) {
        map['is_read'] = true;
        map['updated_at'] = DateTime.now().toIso8601String();
        await box.put(key, map);
      }
    }
  }

  /// Marks all notifications for [profileId] as read.
  Future<void> markAllAsRead(String profileId) async {
    if (profileId.isEmpty) return;

    final box = hiveService.userBox;
    for (final key in box.keys) {
      if (key.toString().startsWith('notification_')) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          if ((map['profile_id'] == profileId ||
                  map['profileId'] == profileId) &&
              (map['is_read'] == false || map['isRead'] == false)) {
            map['is_read'] = true;
            map['updated_at'] = DateTime.now().toIso8601String();
            await box.put(key, map);
          }
        }
      }
    }
  }

  /// Calculates the count of unread notifications for [profileId].
  Future<int> getUnreadCount(String profileId) async {
    if (profileId.isEmpty) return 0;

    final box = hiveService.userBox;
    int unreadCount = 0;

    for (final key in box.keys) {
      if (key.toString().startsWith('notification_')) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          if (map['profile_id'] == profileId || map['profileId'] == profileId) {
            final isRead = map['is_read'] ?? map['isRead'] ?? false;
            if (isRead == false || isRead.toString() == 'false') {
              unreadCount++;
            }
          }
        }
      }
    }

    return unreadCount;
  }

  /// Deletes a notification from Hive.
  Future<void> deleteNotification(
    String profileId,
    String notificationId,
  ) async {
    final key = _normalizeNotificationId(notificationId);
    final box = hiveService.userBox;
    final val = box.get(key);
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      if (map['profile_id'] == profileId || map['profileId'] == profileId) {
        await box.delete(key);
      }
    }
  }
}
