import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/export/export_service.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/preferences/app_preferences_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/local/settings_local_datasource.dart';
import '../../data/datasources/remote/settings_remote_datasource.dart';
import '../../data/models/consent_record_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/repositories/settings_repository.dart';

final appPreferencesServiceProvider = Provider<AppPreferencesService>((ref) {
  return AppPreferencesService(hiveService: ref.watch(hiveServiceProvider));
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(
    preferencesService: ref.watch(appPreferencesServiceProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    preferencesService: ref.watch(appPreferencesServiceProvider),
  );
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(hiveService: ref.watch(hiveServiceProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final prefs = ref.watch(appPreferencesServiceProvider);
  final localDS = SettingsLocalDataSource(
    hiveService: hive,
    preferencesService: prefs,
  );
  final remoteDS = SettingsRemoteDataSource();
  return SettingsRepository(
    localDataSource: localDS,
    remoteDataSource: remoteDS,
  );
});

class SettingsController extends StateNotifier<SettingsModel> {
  final SettingsRepository repository;
  final AnalyticsService analyticsService;
  final NotificationService notificationService;

  SettingsController({
    required this.repository,
    required this.analyticsService,
    required this.notificationService,
  }) : super(repository.getSettings());

  Future<void> updateSettings(SettingsModel newSettings) async {
    state = newSettings;
    await repository.saveSettings(newSettings);
    await analyticsService.setAnalyticsEnabled(newSettings.analyticsEnabled);
    await analyticsService.setCrashReportingEnabled(
      newSettings.crashReportingEnabled,
    );
    await notificationService.updatePreferences(newSettings.toMap());
  }

  Future<void> setThemeMode(String mode) async {
    final updated = state.copyWith(themeMode: mode);
    await updateSettings(updated);
  }

  Future<void> setAppCurrency(String currency) async {
    final updated = state.copyWith(appCurrency: currency);
    await updateSettings(updated);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsModel>((ref) {
      return SettingsController(
        repository: ref.watch(settingsRepositoryProvider),
        analyticsService: ref.watch(analyticsServiceProvider),
        notificationService: ref.watch(notificationServiceProvider),
      );
    });

final appCurrencyProvider = Provider<String>((ref) {
  return ref.watch(settingsControllerProvider).appCurrency;
});

final consentHistoryProvider = Provider<List<ConsentRecordModel>>((ref) {
  return ref.watch(settingsRepositoryProvider).getConsentHistory();
});

final storageUsageProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return await repo.getStorageBreakdown();
});

final appPackageInfoProvider =
    FutureProvider.autoDispose<PackageInfo>((ref) async {
      return await PackageInfo.fromPlatform();
    });

