import '../models/consent_record_model.dart';
import '../models/settings_model.dart';

/// SettingsMapper converts maps to typed settings and consent models.
class SettingsMapper {
  static SettingsModel fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return SettingsModel.defaultSettings();
    }
    return SettingsModel.fromMap(map);
  }

  static Map<String, dynamic> toMap(SettingsModel model) {
    return model.toMap();
  }

  static List<ConsentRecordModel> consentListFromRaw(List<dynamic>? rawList) {
    if (rawList == null || rawList.isEmpty) return [];
    return rawList
        .map(
          (e) =>
              ConsentRecordModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}
