import '../preferences/app_preferences_service.dart';

/// NotificationService persists and manages application notification preferences.
class NotificationService {
  final AppPreferencesService preferencesService;

  NotificationService({required this.preferencesService});

  Map<String, dynamic> getNotificationPreferences() {
    final raw = preferencesService.getRawPreferences();
    if (raw.isEmpty) {
      return {
        'master_notifications': true,
        'medicine_reminders': true,
        'appointment_reminders': true,
        'followup_reminders': true,
        'daily_summary_time': '20:00',
        'sound_enabled': true,
        'vibration_enabled': true,
      };
    }
    return raw;
  }

  Future<void> updatePreferences(Map<String, dynamic> newPrefs) async {
    final existing = getNotificationPreferences();
    existing.addAll(newPrefs);
    await preferencesService.savePreferences(existing);
  }
}
