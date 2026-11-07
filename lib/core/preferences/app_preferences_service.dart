import '../storage/hive_service.dart';

/// AppPreferencesService isolates key-value persistence for global application preferences.
class AppPreferencesService {
  final HiveService hiveService;

  static const String preferencesKey = 'preferences';

  AppPreferencesService({required this.hiveService});

  Map<String, dynamic> getRawPreferences() {
    try {
      final raw = hiveService.settingsBox.get(preferencesKey);
      if (raw == null) return {};
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return {};
    }
  }

  Future<void> savePreferences(Map<String, dynamic> preferencesMap) async {
    try {
      await hiveService.settingsBox.put(preferencesKey, preferencesMap);
    } catch (_) {}
  }

  Future<void> updateSinglePreference(String key, dynamic value) async {
    final existing = getRawPreferences();
    existing[key] = value;
    await savePreferences(existing);
  }
}
