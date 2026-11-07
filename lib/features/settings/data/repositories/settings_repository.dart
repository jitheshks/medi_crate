import '../datasources/local/settings_local_datasource.dart';
import '../datasources/remote/settings_remote_datasource.dart';
import '../models/consent_record_model.dart';
import '../models/settings_model.dart';

/// SettingsRepository is the single source of truth for app settings and local storage info.
class SettingsRepository {
  final SettingsLocalDataSource localDataSource;
  final SettingsRemoteDataSource remoteDataSource;

  SettingsRepository({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  SettingsModel getSettings() {
    return localDataSource.getSettings();
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await localDataSource.saveSettings(settings);
    try {
      await remoteDataSource.pushSettings(settings);
    } catch (_) {}
  }

  List<ConsentRecordModel> getConsentHistory() {
    return localDataSource.getConsentHistory();
  }

  Future<void> recordConsent(ConsentRecordModel consent) async {
    await localDataSource.recordConsent(consent);
  }

  Future<Map<String, int>> getStorageBreakdown() async {
    return await localDataSource.getStorageBreakdown();
  }

  Future<void> clearCache() async {
    await localDataSource.clearCache();
  }
}
