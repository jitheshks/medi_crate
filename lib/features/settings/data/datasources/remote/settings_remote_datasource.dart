import '../../models/settings_model.dart';

/// SettingsRemoteDataSource handles remote settings synchronization contract.
class SettingsRemoteDataSource {
  Future<void> pushSettings(SettingsModel settings) async {
    // Stub remote settings sync operation
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<SettingsModel?> fetchSettings() async {
    // Stub remote settings fetch operation
    await Future.delayed(const Duration(milliseconds: 100));
    return null;
  }
}
