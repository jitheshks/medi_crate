import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  final service = LocalNotificationService();
  return service;
});

/// LocalNotificationService schedules and cancels device-level local alarms
/// and push notifications for appointments and medication dosing.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  LocalNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;
  bool get isInitialized => _isInitialized;

  /// Initializes the local notification plugin and timezones.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped: ${details.payload}');
        },
      );
      _isInitialized = true;
    } on Object catch (e) {
      debugPrint('LocalNotificationService initialization failed: $e');
    }
  }

  /// Requests system notification permissions where applicable.
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? true;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final darwinImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await darwinImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
    } on Object catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Generates a deterministic positive 32-bit integer notification ID from a string key.
  int getNotificationId(String key) {
    return key.hashCode & 0x7FFFFFFF;
  }

  /// Schedules an appointment reminder ahead of the scheduled time.
  Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String title,
    required String doctorOrHospital,
    required DateTime appointmentDateTime,
    int minutesBefore = 30,
  }) async {
    await initialize();

    final id = getNotificationId(appointmentId);
    final reminderTime = appointmentDateTime.subtract(
      Duration(minutes: minutesBefore),
    );
    final now = DateTime.now();

    // If appointment is already in the past, do not schedule
    if (appointmentDateTime.isBefore(now)) {
      return;
    }

    final targetTime = reminderTime.isAfter(now)
        ? reminderTime
        : now.add(const Duration(seconds: 5));

    final tzTarget = tz.TZDateTime.from(targetTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'medicrate_appointments',
      'Appointment Reminders',
      channelDescription:
          'Notifications for upcoming doctor and clinic appointments',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Upcoming Appointment: $title',
        body: 'Appointment with $doctorOrHospital in $minutesBefore minutes.',
        scheduledDate: tzTarget,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment:$appointmentId',
      );
    } on Object catch (e) {
      debugPrint('Failed to schedule appointment notification: $e');
    }
  }

  /// Cancels a scheduled appointment reminder.
  Future<void> cancelAppointmentReminder(String appointmentId) async {
    await initialize();
    final id = getNotificationId(appointmentId);
    try {
      await _notificationsPlugin.cancel(id: id);
    } on Object catch (e) {
      debugPrint('Failed to cancel appointment notification $id: $e');
    }
  }

  /// Schedules daily repeating medicine reminder notifications for each configured time.
  Future<void> scheduleMedicineReminders({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> reminderTimes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await initialize();

    // First cancel any existing reminder slots for this medicine
    await cancelMedicineReminders(medicineId);

    if (reminderTimes.isEmpty) return;

    final now = DateTime.now();
    if (endDate != null &&
        endDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return; // Medicine course completed
    }

    const androidDetails = AndroidNotificationDetails(
      'medicrate_medicines',
      'Medicine Reminders',
      channelDescription: 'Daily dose reminders for your active medications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    for (int i = 0; i < reminderTimes.length; i++) {
      final time = reminderTimes[i];
      final slotId = getNotificationId('${medicineId}_slot_$i');

      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      try {
        await _notificationsPlugin.zonedSchedule(
          id: slotId,
          title: 'Medicine Reminder: $medicineName',
          body: 'Time to take $dosage of $medicineName.',
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'medicine:$medicineId',
        );
      } on Object catch (e) {
        debugPrint('Failed to schedule medicine notification slot $i: $e');
      }
    }
  }

  /// Cancels all reminder slots for a medicine.
  Future<void> cancelMedicineReminders(
    String medicineId, {
    int maxSlots = 8,
  }) async {
    await initialize();
    for (int i = 0; i < maxSlots; i++) {
      final slotId = getNotificationId('${medicineId}_slot_$i');
      try {
        await _notificationsPlugin.cancel(id: slotId);
      } on Object catch (_) {}
    }
  }

  /// Cancels all scheduled local notifications.
  Future<void> cancelAll() async {
    await initialize();
    try {
      await _notificationsPlugin.cancelAll();
    } on Object catch (_) {}
  }
}
