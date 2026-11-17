import '../../../../../core/storage/hive_service.dart';
import '../../models/profile_model.dart';

/// ProfileLocalDataSource handles persistent local CRUD operations for family profiles in Hive.
class ProfileLocalDataSource {
  final HiveService hiveService;

  ProfileLocalDataSource({required this.hiveService});


  Future<List<ProfileModel>> getProfilesForUser(
    String ownerUserId, {
    bool includeArchived = false,
  }) async {
    // Option D isolation requirement: Never expose all profiles when ownerUserId is empty
    if (ownerUserId.trim().isEmpty) {
      return [];
    }

    final box = hiveService.profileBox;
    final profiles = <ProfileModel>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        final profile = ProfileModel.fromMap(map);
        if (profile.ownerUserId == ownerUserId.trim()) {
          if (includeArchived || !profile.isArchived) {
            profiles.add(profile);
          }
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

  Future<ProfileModel?> getProfileById(
    String profileId, {
    required String ownerUserId,
  }) async {
    final trimmedOwner = ownerUserId.trim();
    final trimmedId = profileId.trim();
    if (trimmedOwner.isEmpty || trimmedId.isEmpty) return null;

    final box = hiveService.profileBox;
    final raw = box.get(trimmedId);
    if (raw == null) return null;

    final profile = ProfileModel.fromMap(Map<String, dynamic>.from(raw));
    if (profile.ownerUserId != trimmedOwner) {
      return null;
    }
    return profile;
  }

  Future<ProfileModel?> getProfileByServerId(
    int serverProfileId,
    String ownerUserId,
  ) async {
    if (ownerUserId.trim().isEmpty) return null;
    final box = hiveService.profileBox;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        final profile = ProfileModel.fromMap(map);
        if (profile.ownerUserId == ownerUserId.trim() &&
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
    if (trimmed.isEmpty || ownerUserId.trim().isEmpty) return null;
    final box = hiveService.profileBox;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw);
        final profile = ProfileModel.fromMap(map);
        if (profile.ownerUserId == ownerUserId.trim() &&
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

  static const String _legacyActiveProfileIdKey = 'active_profile_id';

  static String _activeProfileIdKey(String ownerUserId) =>
      'active_profile_id_${ownerUserId.trim()}';

  String? getActiveProfileIdSync(String ownerUserId) {
    final trimmedOwner = ownerUserId.trim();
    if (trimmedOwner.isEmpty) return null;

    final userBox = hiveService.userBox;
    final accountKey = _activeProfileIdKey(trimmedOwner);
    final raw = userBox.get(accountKey);

    if (raw is Map && raw.containsKey('id')) {
      final id = raw['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final profileRaw = hiveService.profileBox.get(id);
        if (profileRaw is Map) {
          final profile = ProfileModel.fromMap(
            Map<String, dynamic>.from(profileRaw),
          );
          if (profile.ownerUserId == trimmedOwner && !profile.isArchived) {
            return id;
          }
        }
      }
    }

    // Legacy migration check:
    final legacyRaw = userBox.get(_legacyActiveProfileIdKey);
    if (legacyRaw is Map && legacyRaw.containsKey('id')) {
      final legacyId = legacyRaw['id']?.toString();
      if (legacyId != null && legacyId.isNotEmpty) {
        final profileRaw = hiveService.profileBox.get(legacyId);
        if (profileRaw is Map) {
          final profile = ProfileModel.fromMap(
            Map<String, dynamic>.from(profileRaw),
          );
          if (profile.ownerUserId == trimmedOwner && !profile.isArchived) {
            return legacyId;
          }
        }
      }
    }

    return null;
  }

  Future<String?> getActiveProfileId(String ownerUserId) async {
    final trimmedOwner = ownerUserId.trim();
    if (trimmedOwner.isEmpty) return null;

    final userBox = hiveService.userBox;
    final accountKey = _activeProfileIdKey(trimmedOwner);
    final raw = userBox.get(accountKey);

    if (raw is Map && raw.containsKey('id')) {
      final id = raw['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final profileRaw = hiveService.profileBox.get(id);
        if (profileRaw is Map) {
          final profile = ProfileModel.fromMap(
            Map<String, dynamic>.from(profileRaw),
          );
          if (profile.ownerUserId == trimmedOwner && !profile.isArchived) {
            return id;
          }
        }
      }
    }

    // Legacy migration check:
    final legacyRaw = userBox.get(_legacyActiveProfileIdKey);
    if (legacyRaw is Map && legacyRaw.containsKey('id')) {
      final legacyId = legacyRaw['id']?.toString();
      if (legacyId != null && legacyId.isNotEmpty) {
        final profileRaw = hiveService.profileBox.get(legacyId);
        if (profileRaw is Map) {
          final profile = ProfileModel.fromMap(
            Map<String, dynamic>.from(profileRaw),
          );
          if (profile.ownerUserId == trimmedOwner && !profile.isArchived) {
            await userBox.put(accountKey, {'id': legacyId});
            await userBox.delete(_legacyActiveProfileIdKey);
            return legacyId;
          }
        }
      }
    }

    return null;
  }

  Future<void> setActiveProfileId({
    required String profileId,
    required String ownerUserId,
  }) async {
    final trimmedOwner = ownerUserId.trim();
    final trimmedId = profileId.trim();

    if (trimmedOwner.isEmpty) {
      throw ArgumentError(
        'ownerUserId cannot be empty when setting active profile ID.',
      );
    }
    if (trimmedId.isEmpty) {
      throw ArgumentError(
        'profileId cannot be empty when setting active profile ID.',
      );
    }

    // TASK 4: Independently validate:
    // 1. Profile exists.
    final profileRaw = hiveService.profileBox.get(trimmedId);
    if (profileRaw == null) {
      throw ArgumentError(
        'Cannot set active profile: Profile "$trimmedId" does not exist in local storage.',
      );
    }

    final profile = ProfileModel.fromMap(
      Map<String, dynamic>.from(profileRaw),
    );

    // 2. Profile belongs to the supplied owner.
    if (profile.ownerUserId != trimmedOwner) {
      throw StateError(
        'Cannot set active profile: Profile "$trimmedId" does not belong to owner "$trimmedOwner".',
      );
    }

    // 3. Profile is not archived.
    if (profile.isArchived) {
      throw StateError(
        'Cannot set active profile: Profile "$trimmedId" is archived.',
      );
    }

    try {
      final userBox = hiveService.userBox;
      if (!userBox.isOpen) return;
      await userBox.put(_activeProfileIdKey(trimmedOwner), {'id': trimmedId});

      if (userBox.isOpen && userBox.containsKey(_legacyActiveProfileIdKey)) {
        await userBox.delete(_legacyActiveProfileIdKey);
      }
    } catch (_) {
      // Safe ignore if box closes concurrently during teardown
    }
  }

  Future<void> clearActiveProfileId([String? ownerUserId]) async {
    try {
      final userBox = hiveService.userBox;
      if (!userBox.isOpen) return;
      if (ownerUserId != null && ownerUserId.trim().isNotEmpty) {
        await userBox.delete(_activeProfileIdKey(ownerUserId.trim()));
      }
      if (userBox.isOpen) {
        await userBox.delete(_legacyActiveProfileIdKey);
      }
    } catch (_) {
      // Safe ignore if box closes concurrently during teardown
    }
  }
}
