import '../../../../../core/storage/hive_service.dart';
import '../../models/user_model.dart';

/// AuthLocalDataSource manages auth state and user profile caching in Hive.
class AuthLocalDataSource {
  final HiveService _hiveService;

  AuthLocalDataSource(this._hiveService);

  static const String _userKey = 'current_user';
  static const String _sessionKey = 'is_logged_in';

  Future<void> saveUser(UserModel user) async {
    final box = _hiveService.userBox;
    await box.put(_userKey, user.toMap());
    await _hiveService.authBox.put(_sessionKey, {'isLoggedIn': true});
    await _hiveService.authBox.put(_userKey, user.toMap());
  }

  Future<UserModel?> getUser() async {
    final box = _hiveService.userBox;
    final map = box.get(_userKey) ?? _hiveService.authBox.get(_userKey);
    if (map == null) {
      return null;
    }
    return UserModel.fromMap(Map<String, dynamic>.from(map));
  }

  Future<bool> isLoggedIn() async {
    final box = _hiveService.authBox;
    final map = box.get(_sessionKey);
    if (map == null) return false;
    return map['isLoggedIn'] as bool? ?? false;
  }

  Future<void> clearSession() async {
    await _hiveService.userBox.delete(_userKey);
    await _hiveService.userBox.delete('active_profile_id');
    await _hiveService.authBox.delete(_sessionKey);
    await _hiveService.authBox.delete(_userKey);
  }

  Future<void> clearUser() async {
    await clearSession();
  }
}
