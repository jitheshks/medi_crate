import '../preferences/app_preferences_service.dart';

/// AnalyticsService manages analytics & crash reporting preferences and persistence.
class AnalyticsService {
  final AppPreferencesService preferencesService;

  static const String analyticsKey = 'analytics_enabled';
  static const String crashReportingKey = 'crash_reporting_enabled';

  AnalyticsService({required this.preferencesService});

  bool isAnalyticsEnabled() {
    final map = preferencesService.getRawPreferences();
    return map[analyticsKey] as bool? ?? false;
  }

  bool isCrashReportingEnabled() {
    final map = preferencesService.getRawPreferences();
    return map[crashReportingKey] as bool? ?? false;
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await preferencesService.updateSinglePreference(analyticsKey, enabled);
  }

  Future<void> setCrashReportingEnabled(bool enabled) async {
    await preferencesService.updateSinglePreference(crashReportingKey, enabled);
  }
}
