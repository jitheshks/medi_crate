import '../../../../core/constants/app_currency.dart';

/// SettingsModel represents all customizable user preferences in MediVault.
class SettingsModel {
  final bool biometricsEnabled;
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool masterNotificationsEnabled;
  final bool medicineRemindersEnabled;
  final bool appointmentRemindersEnabled;
  final bool followUpRemindersEnabled;
  final String dailySummaryTime;
  final bool notificationSoundEnabled;
  final bool notificationVibrationEnabled;
  final String themeMode; // "system", "light", "dark"
  final double textScale; // 0.85 to 1.30
  final bool reducedMotion;
  final String appCurrency; // "INR", "USD", "EUR", "GBP"

  const SettingsModel({
    this.biometricsEnabled = false,
    this.analyticsEnabled = false,
    this.crashReportingEnabled = false,
    this.masterNotificationsEnabled = true,
    this.medicineRemindersEnabled = true,
    this.appointmentRemindersEnabled = true,
    this.followUpRemindersEnabled = true,
    this.dailySummaryTime = '20:00',
    this.notificationSoundEnabled = true,
    this.notificationVibrationEnabled = true,
    this.themeMode = 'system',
    this.textScale = 1.0,
    this.reducedMotion = false,
    this.appCurrency = 'INR',
  });

  factory SettingsModel.defaultSettings({String? initialCurrency}) =>
      SettingsModel(
        appCurrency: initialCurrency ?? AppCurrency.detectDefaultCurrency(),
      );

  SettingsModel copyWith({
    bool? biometricsEnabled,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? masterNotificationsEnabled,
    bool? medicineRemindersEnabled,
    bool? appointmentRemindersEnabled,
    bool? followUpRemindersEnabled,
    String? dailySummaryTime,
    bool? notificationSoundEnabled,
    bool? notificationVibrationEnabled,
    String? themeMode,
    double? textScale,
    bool? reducedMotion,
    String? appCurrency,
  }) {
    return SettingsModel(
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      masterNotificationsEnabled:
          masterNotificationsEnabled ?? this.masterNotificationsEnabled,
      medicineRemindersEnabled:
          medicineRemindersEnabled ?? this.medicineRemindersEnabled,
      appointmentRemindersEnabled:
          appointmentRemindersEnabled ?? this.appointmentRemindersEnabled,
      followUpRemindersEnabled:
          followUpRemindersEnabled ?? this.followUpRemindersEnabled,
      dailySummaryTime: dailySummaryTime ?? this.dailySummaryTime,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationVibrationEnabled:
          notificationVibrationEnabled ?? this.notificationVibrationEnabled,
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      appCurrency: appCurrency ?? this.appCurrency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'biometrics_enabled': biometricsEnabled,
      'analytics_enabled': analyticsEnabled,
      'crash_reporting_enabled': crashReportingEnabled,
      'master_notifications': masterNotificationsEnabled,
      'medicine_reminders': medicineRemindersEnabled,
      'appointment_reminders': appointmentRemindersEnabled,
      'followup_reminders': followUpRemindersEnabled,
      'daily_summary_time': dailySummaryTime,
      'sound_enabled': notificationSoundEnabled,
      'vibration_enabled': notificationVibrationEnabled,
      'theme_mode': themeMode,
      'text_scale': textScale,
      'reduced_motion': reducedMotion,
      'app_currency': appCurrency,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      biometricsEnabled: map['biometrics_enabled'] as bool? ?? false,
      analyticsEnabled: map['analytics_enabled'] as bool? ?? false,
      crashReportingEnabled: map['crash_reporting_enabled'] as bool? ?? false,
      masterNotificationsEnabled: map['master_notifications'] as bool? ?? true,
      medicineRemindersEnabled: map['medicine_reminders'] as bool? ?? true,
      appointmentRemindersEnabled:
          map['appointment_reminders'] as bool? ?? true,
      followUpRemindersEnabled: map['followup_reminders'] as bool? ?? true,
      dailySummaryTime: map['daily_summary_time'] as String? ?? '20:00',
      notificationSoundEnabled: map['sound_enabled'] as bool? ?? true,
      notificationVibrationEnabled: map['vibration_enabled'] as bool? ?? true,
      themeMode: map['theme_mode'] as String? ?? 'system',
      textScale: (map['text_scale'] as num?)?.toDouble() ?? 1.0,
      reducedMotion: map['reduced_motion'] as bool? ?? false,
      appCurrency:
          map['app_currency'] as String? ??
          map['currency'] as String? ??
          AppCurrency.detectDefaultCurrency(),
    );
  }
}
