import 'package:hive_flutter/hive_flutter.dart';

/// HiveService manages Hive local storage initialization and box access.
class HiveService {
  static const String authBoxName = 'auth_box';
  static const String syncQueueBoxName = 'sync_queue_box';
  static const String userBoxName = 'user_box';
  static const String settingsBoxName = 'settings_box';
  static const String consentBoxName = 'consent_box';
  static const String profileBoxName = 'profile_box';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Boxes are independent of each other; open them concurrently once Hive is ready.
    await Future.wait([
      Hive.openBox<Map>(authBoxName),
      Hive.openBox<Map>(syncQueueBoxName),
      Hive.openBox<Map>(userBoxName),
      Hive.openBox<Map>(settingsBoxName),
      Hive.openBox<Map>(consentBoxName),
      Hive.openBox<Map>(profileBoxName),
    ]);
  }

  Box<Map> get authBox => Hive.box<Map>(authBoxName);
  Box<Map> get syncQueueBox => Hive.box<Map>(syncQueueBoxName);
  Box<Map> get userBox => Hive.box<Map>(userBoxName);
  Box<Map> get settingsBox => Hive.box<Map>(settingsBoxName);
  Box<Map> get consentBox => Hive.box<Map>(consentBoxName);
  Box<Map> get profileBox => Hive.box<Map>(profileBoxName);
}
