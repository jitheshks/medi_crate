import '../../../../../core/storage/hive_service.dart';
import '../../models/profile_model.dart';

/// ProfileLocalDataSource handles persistent local CRUD operations for family profiles in Hive.
class ProfileLocalDataSource {
  final HiveService hiveService;

  ProfileLocalDataSource({required this.hiveService});

  static const String _activeProfileIdKey = 'active_profile_id';

  Future<List<ProfileModel>> getProfilesForUser(String ownerUserId) async {
    final box = hiveService.profileBox;
    final profiles = <ProfileModel>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        final profile = ProfileModel.fromMap(map);
        if (ownerUserId.isEmpty || profile.ownerUserId == ownerUserId) {
          profiles.add(profile);
        }
      }
    }

    profiles.sort((a, b) {
      if (a.isPrimary) return -1;
      if (b.isPrimary) return 1;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return profiles;
  }

  Future<ProfileModel?> getProfileById(String profileId) async {
    final box = hiveService.profileBox;
    final raw = box.get(profileId);
    if (raw == null) return null;
    return ProfileModel.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<ProfileModel?> getProfileByServerId(
    int serverProfileId,
    String ownerUserId,
  ) async {
    final box = hiveService.profileBox;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        final profile = ProfileModel.fromMap(map);
        if ((ownerUserId.isEmpty || profile.ownerUserId == ownerUserId) &&
            profile.serverProfileId == serverProfileId) {
          return profile;
        }
      }
    }
    return null;
  }

  Future<ProfileModel?> getProfileByClientUuid(
    String clientUuid,
    String ownerUserId,
  ) async {
    final trimmed = clientUuid.trim();
    if (trimmed.isEmpty) return null;
    final box = hiveService.profileBox;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        final profile = ProfileModel.fromMap(map);
        if ((ownerUserId.isEmpty || profile.ownerUserId == ownerUserId) &&
            profile.clientUuid == trimmed) {
          return profile;
        }
      }
    }
    return null;
  }

  Future<void> saveProfile(ProfileModel profile) async {
    final box = hiveService.profileBox;
    // If setting as primary, demote other existing primary profiles for this owner
    if (profile.isPrimary) {
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw != null) {
          final map = Map<String, dynamic>.from(raw);
          final existing = ProfileModel.fromMap(map);
          if (existing.ownerUserId == profile.ownerUserId &&
              existing.profileId != profile.profileId &&
              existing.isPrimary) {
            final updated = existing.copyWith(isPrimary: false);
            await box.put(existing.profileId, updated.toMap());
          }
        }
      }
    }
    await box.put(profile.profileId, profile.toMap());
  }

  Future<void> saveProfiles(List<ProfileModel> profiles) async {
    for (final profile in profiles) {
      await saveProfile(profile);
    }
  }

  Future<void> deleteProfile(String profileId) async {
    final box = hiveService.profileBox;
    await box.delete(profileId);
  }

  String? getActiveProfileIdSync() {
    final box = hiveService.userBox;
    final raw = box.get(_activeProfileIdKey);
    if (raw is Map && raw.containsKey('id')) {
      final id = raw['id'] as String?;
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  Future<String?> getActiveProfileId() async {
    return getActiveProfileIdSync();
  }

  Future<void> setActiveProfileId(String profileId) async {
    final box = hiveService.userBox;
    await box.put(_activeProfileIdKey, {'id': profileId});
  }

  Future<void> clearActiveProfileId() async {
    final box = hiveService.userBox;
    await box.delete(_activeProfileIdKey);
  }
}
