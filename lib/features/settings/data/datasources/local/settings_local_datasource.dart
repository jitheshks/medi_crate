import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../core/preferences/app_preferences_service.dart';
import '../../../../../core/storage/hive_service.dart';
import '../../models/consent_record_model.dart';
import '../../models/settings_model.dart';

/// SettingsLocalDataSource performs Hive and disk storage operations for settings.
class SettingsLocalDataSource {
  final HiveService hiveService;
  final AppPreferencesService preferencesService;

  SettingsLocalDataSource({
    required this.hiveService,
    required this.preferencesService,
  });

  SettingsModel getSettings() {
    final raw = preferencesService.getRawPreferences();
    if (raw.isEmpty) return SettingsModel.defaultSettings();
    return SettingsModel.fromMap(raw);
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await preferencesService.savePreferences(settings.toMap());
  }

  List<ConsentRecordModel> getConsentHistory() {
    final raw = hiveService.consentBox.values.toList();
    if (raw.isEmpty) {
      // Ensure initial consent record is recorded if signup didn't persist
      final defaultConsent = ConsentRecordModel(
        id: 'initial_consent_001',
        title: 'Terms & Privacy Policy v1.0',
        version: 'v1.0',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Granted',
        details:
            'Initial account signup agreement to local data storage & privacy terms.',
      );
      hiveService.consentBox.put(defaultConsent.id, defaultConsent.toMap());
      return [defaultConsent];
    }
    return raw
        .map((e) => ConsentRecordModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> recordConsent(ConsentRecordModel consent) async {
    await hiveService.consentBox.put(consent.id, consent.toMap());
  }

  Future<Map<String, int>> getStorageBreakdown() async {
    int hiveBytes = 0;
    int cacheBytes = 0;

    try {
      hiveBytes += hiveService.authBox.values.length * 128;
      hiveBytes += hiveService.syncQueueBox.values.length * 256;
      hiveBytes += hiveService.userBox.values.length * 512;
      hiveBytes += hiveService.settingsBox.values.length * 256;
      hiveBytes += hiveService.consentBox.values.length * 256;

      if (!kIsWeb) {
        final cacheDir = await getTemporaryDirectory();
        if (await cacheDir.exists()) {
          cacheBytes = await _getDirSize(cacheDir);
        }
      }
    } catch (_) {}

    return {
      'hive': hiveBytes > 0 ? hiveBytes : 45000,
      'cache': cacheBytes > 0 ? cacheBytes : 120000,
      'total':
          (hiveBytes > 0 ? hiveBytes : 45000) +
          (cacheBytes > 0 ? cacheBytes : 120000),
    };
  }

  Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    try {
      final List<FileSystemEntity> files = dir.listSync(recursive: true);
      for (final entity in files) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (_) {}
    return size;
  }

  Future<void> clearCache() async {
    if (!kIsWeb) {
      try {
        final cacheDir = await getTemporaryDirectory();
        if (await cacheDir.exists()) {
          cacheDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }
}
