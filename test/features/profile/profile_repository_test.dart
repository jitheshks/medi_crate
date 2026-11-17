import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/profile/data/datasources/local/profile_local_data_source.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/data/repositories/profile_repository.dart';

class _FakeConnectivityService implements ConnectivityService {
  bool isOnline = true;

  @override
  Future<bool> checkConnectivity() async => isOnline;

  @override
  Future<bool> checkInternetAccess() async => isOnline;

  @override
  Future<List<ConnectivityResult>> getTransports() async =>
      isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none];

  @override
  Future<NetworkStatusModel> getDetailedStatus() async => NetworkStatusModel(
        transports: isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
        hasInternet: isOnline,
      );

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isOnline);

  @override
  void dispose() {}
}

class _FakeSupabaseProfileRemoteDataSource extends SupabaseProfileRemoteDataSource {
  final List<ProfileModel> remoteProfiles = [];
  bool shouldThrowNetworkError = false;

  @override
  Future<List<ProfileModel>> fetchProfiles({
    required String ownerUserId,
    bool includeArchived = false,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    return remoteProfiles.where((p) {
      if (p.ownerUserId != ownerUserId) return false;
      if (!includeArchived && p.isArchived) return false;
      return true;
    }).toList();
  }

  @override
  Future<ProfileModel?> getProfileById({
    required String profileId,
    required String ownerUserId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    return remoteProfiles
        .where((p) => p.profileId == profileId && p.ownerUserId == ownerUserId)
        .firstOrNull;
  }

  @override
  Future<ProfileModel> createFamilyProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final created = profile.copyWith(
      profileId: 'server-uuid-${DateTime.now().microsecondsSinceEpoch}',
      ownerUserId: ownerUserId,
      isPrimary: false,
    );
    remoteProfiles.add(created);
    return created;
  }

  @override
  Future<ProfileModel> updateProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final index = remoteProfiles.indexWhere((p) => p.profileId == profile.profileId);
    if (index >= 0) {
      remoteProfiles[index] = profile;
    } else {
      remoteProfiles.add(profile);
    }
    return profile;
  }

  @override
  Future<ProfileModel> archiveProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final index = remoteProfiles.indexWhere(
      (p) => p.profileId == profileId && p.ownerUserId == ownerUserId,
    );
    if (index >= 0) {
      final archived = remoteProfiles[index].copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
      );
      remoteProfiles[index] = archived;
      return archived;
    }
    throw const NotFoundException('Profile not found');
  }

  @override
  Future<ProfileModel> restoreProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final index = remoteProfiles.indexWhere(
      (p) => p.profileId == profileId && p.ownerUserId == ownerUserId,
    );
    if (index >= 0) {
      final restored = remoteProfiles[index].copyWith(
        isArchived: false,
        clearArchivedAt: true,
      );
      remoteProfiles[index] = restored;
      return restored;
    }
    throw const NotFoundException('Profile not found');
  }

  @override
  Future<ProfileModel> uploadProfilePhoto({
    required String profileId,
    required String ownerUserId,
    required File photoFile,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final index = remoteProfiles.indexWhere(
      (p) => p.profileId == profileId && p.ownerUserId == ownerUserId,
    );
    if (index >= 0) {
      final updated = remoteProfiles[index].copyWith(
        photo: '$ownerUserId/$profileId/uploaded.jpg',
      );
      remoteProfiles[index] = updated;
      return updated;
    }
    throw const NotFoundException('Profile not found');
  }

  @override
  Future<ProfileModel> deleteProfilePhoto({
    required String profileId,
    required String ownerUserId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final index = remoteProfiles.indexWhere(
      (p) => p.profileId == profileId && p.ownerUserId == ownerUserId,
    );
    if (index >= 0) {
      final updated = remoteProfiles[index].copyWith(clearPhoto: true);
      remoteProfiles[index] = updated;
      return updated;
    }
    throw const NotFoundException('Profile not found');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late ProfileLocalDataSource localDataSource;
  late _FakeSupabaseProfileRemoteDataSource fakeRemoteDataSource;
  late _FakeConnectivityService fakeConnectivity;
  late SyncService syncService;
  late ProfileRepository profileRepo;

  final primaryProfile = ProfileModel(
    profileId: 'prof-uuid-primary-1',
    ownerUserId: 'user-1',
    fullName: 'Jane Doe',
    relationship: 'Self',
    isPrimary: true,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('profile_repo_test_');
    Hive.init(tempDir.path);

    for (final boxName in const [
      HiveService.authBoxName,
      HiveService.syncQueueBoxName,
      HiveService.userBoxName,
      HiveService.settingsBoxName,
      HiveService.profileBoxName,
    ]) {
      await Hive.openBox<Map>(boxName);
    }

    hiveService = HiveService();
    localDataSource = ProfileLocalDataSource(hiveService: hiveService);
    fakeRemoteDataSource = _FakeSupabaseProfileRemoteDataSource();
    fakeConnectivity = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: fakeConnectivity,
    );

    profileRepo = ProfileRepository(
      localDataSource: localDataSource,
      remoteDataSource: fakeRemoteDataSource,
      connectivityService: fakeConnectivity,
      syncService: syncService,
      hiveService: hiveService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ProfileRepository Caching & Operations', () {
    test('getProfiles retrieves profiles strictly scoped by ownerUserId from local Hive', () async {
      await localDataSource.saveProfile(primaryProfile);
      await localDataSource.saveProfile(
        ProfileModel(
          profileId: 'prof-uuid-other-user',
          ownerUserId: 'user-2',
          fullName: 'Stranger',
          relationship: 'Self',
          isPrimary: true,
        ),
      );

      final user1Profiles = await profileRepo.getProfiles('user-1');
      expect(user1Profiles.length, 1);
      expect(user1Profiles.first.fullName, 'Jane Doe');

      final user2Profiles = await profileRepo.getProfiles('user-2');
      expect(user2Profiles.length, 1);
      expect(user2Profiles.first.fullName, 'Stranger');
    });

    test('pullProfiles fetches from remote and caches to Hive when online', () async {
      fakeConnectivity.isOnline = true;
      fakeRemoteDataSource.remoteProfiles.addAll([
        primaryProfile,
        ProfileModel(
          profileId: 'prof-uuid-mother-1',
          ownerUserId: 'user-1',
          fullName: 'Eleanor Vance',
          relationship: 'Mother',
          isPrimary: false,
        ),
      ]);

      await profileRepo.pullProfiles('user-1');

      final cached = await localDataSource.getProfilesForUser('user-1');
      expect(cached.length, 2);
      expect(cached.first.isPrimary, isTrue);
      expect(cached.last.relationship, 'Mother');
    });

    test('pullProfiles cleans up provisional prof_primary_ key if real UUID primary is retrieved', () async {
      fakeConnectivity.isOnline = true;
      // Provisional local profile stored on first launch
      await localDataSource.saveProfile(
        ProfileModel(
          profileId: 'prof_primary_user-1',
          ownerUserId: 'user-1',
          fullName: 'Jane Doe',
          relationship: 'Self',
          isPrimary: true,
        ),
      );

      // Supabase returns authoritative UUID primary profile
      fakeRemoteDataSource.remoteProfiles.add(primaryProfile);

      await profileRepo.pullProfiles('user-1');

      final cached = await localDataSource.getProfilesForUser('user-1');
      expect(cached.length, 1);
      expect(cached.first.profileId, 'prof-uuid-primary-1');
      expect(await localDataSource.getProfileById('prof_primary_user-1', ownerUserId: 'user-1'), isNull);
    });

    test('createProfile calls remote when online and updates Hive cache', () async {
      fakeConnectivity.isOnline = true;
      final newFamily = ProfileModel(
        profileId: '',
        ownerUserId: 'user-1',
        fullName: 'Father Vance',
        relationship: 'Father',
        isPrimary: false,
      );

      final created = await profileRepo.createProfile(newFamily);

      expect(created.profileId, startsWith('server-uuid-'));
      expect(created.isPrimary, isFalse);

      final cached = await localDataSource.getProfilesForUser('user-1');
      expect(cached.any((p) => p.profileId == created.profileId), isTrue);
    });

    test('createProfile throws NetworkException when offline', () async {
      fakeConnectivity.isOnline = false;
      final newFamily = ProfileModel(
        profileId: '',
        ownerUserId: 'user-1',
        fullName: 'Father Vance',
        relationship: 'Father',
        isPrimary: false,
      );

      expect(
        () => profileRepo.createProfile(newFamily),
        throwsA(isA<NetworkException>()),
      );
    });

    test('updateProfile updates remote when online and updates Hive cache', () async {
      fakeConnectivity.isOnline = true;
      await localDataSource.saveProfile(primaryProfile);

      final updated = primaryProfile.copyWith(fullName: 'Jane Vance');
      final result = await profileRepo.updateProfile(updated);

      expect(result.fullName, 'Jane Vance');
      final cached = await localDataSource.getProfileById(
        primaryProfile.profileId,
        ownerUserId: primaryProfile.ownerUserId,
      );
      expect(cached?.fullName, 'Jane Vance');
    });

    test('updateProfile throws NetworkException when offline', () async {
      fakeConnectivity.isOnline = false;
      await localDataSource.saveProfile(primaryProfile);

      final updated = primaryProfile.copyWith(fullName: 'Jane Vance');
      expect(
        () => profileRepo.updateProfile(updated),
        throwsA(isA<NetworkException>()),
      );
    });

    test('deleteProfile throws StateError on primary profile', () async {
      await localDataSource.saveProfile(primaryProfile);
      expect(
        () => profileRepo.deleteProfile(primaryProfile.profileId),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteProfile throws UnsupportedError on secondary profile to protect clinical records', () async {
      final family = ProfileModel(
        profileId: 'family-1',
        ownerUserId: 'user-1',
        fullName: 'Son',
        relationship: 'Son',
        isPrimary: false,
      );
      await localDataSource.saveProfile(family);

      expect(
        () => profileRepo.deleteProfile(family.profileId),
        throwsA(isA<UnsupportedError>()),
      );

      // Verify the profile was NOT deleted from local storage
      expect(
        await localDataSource.getProfileById('family-1', ownerUserId: 'user-1'),
        isNotNull,
      );
    });

    test('setPrimaryProfile throws UnsupportedError preserving invariant', () async {
      final family = ProfileModel(
        profileId: 'family-1',
        ownerUserId: 'user-1',
        fullName: 'Son',
        relationship: 'Son',
        isPrimary: false,
      );
      expect(
        () => profileRepo.setPrimaryProfile(family),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('active profile ID is stored and retrieved locally without network', () async {
      await localDataSource.saveProfile(primaryProfile);
      await profileRepo.setActiveProfileId(
        profileId: primaryProfile.profileId,
        ownerUserId: primaryProfile.ownerUserId,
      );
      expect(
        await profileRepo.getActiveProfileId(primaryProfile.ownerUserId),
        primaryProfile.profileId,
      );

      await profileRepo.clearSessionProfileData(primaryProfile.ownerUserId);
      expect(
        await profileRepo.getActiveProfileId(primaryProfile.ownerUserId),
        isNull,
      );
    });

    test('ensureDefaultProfile returns existing primary if available', () async {
      await localDataSource.saveProfile(primaryProfile);

      final user = UserModel(
        id: 'user-1',
        name: 'Jane Doe',
        email: 'jane@example.com',
      );

      final profile = await profileRepo.ensureDefaultProfile(user);
      expect(profile.profileId, primaryProfile.profileId);
      expect(profile.isPrimary, isTrue);
    });

    test('archiveProfile throws StateError on primary profile', () async {
      await localDataSource.saveProfile(primaryProfile);

      expect(
        () => profileRepo.archiveProfile(
          primaryProfile.profileId,
          ownerUserId: primaryProfile.ownerUserId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('archiveProfile throws NetworkException when offline', () async {
      final family = ProfileModel(
        profileId: 'family-offline-1',
        ownerUserId: 'user-1',
        fullName: 'Daughter',
        relationship: 'Daughter',
        isPrimary: false,
      );
      await localDataSource.saveProfile(family);
      fakeConnectivity.isOnline = false;

      expect(
        () => profileRepo.archiveProfile(
          family.profileId,
          ownerUserId: family.ownerUserId,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('archiveProfile archives remote and updates Hive cache on success', () async {
      final family = ProfileModel(
        profileId: 'family-online-1',
        ownerUserId: 'user-1',
        fullName: 'Daughter',
        relationship: 'Daughter',
        isPrimary: false,
        isArchived: false,
      );
      await localDataSource.saveProfile(family);
      fakeRemoteDataSource.remoteProfiles.add(family);

      final archived = await profileRepo.archiveProfile(
        family.profileId,
        ownerUserId: family.ownerUserId,
      );

      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, isNotNull);

      final cached = await localDataSource.getProfileById(
        family.profileId,
        ownerUserId: family.ownerUserId,
      );
      expect(cached?.isArchived, isTrue);
    });

    test('restoreProfile throws StateError on primary profile', () async {
      await localDataSource.saveProfile(primaryProfile);

      expect(
        () => profileRepo.restoreProfile(
          primaryProfile.profileId,
          ownerUserId: primaryProfile.ownerUserId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('restoreProfile throws NetworkException when offline', () async {
      final family = ProfileModel(
        profileId: 'family-offline-restore',
        ownerUserId: 'user-1',
        fullName: 'Brother',
        relationship: 'Brother',
        isPrimary: false,
        isArchived: true,
      );
      await localDataSource.saveProfile(family);
      fakeConnectivity.isOnline = false;

      expect(
        () => profileRepo.restoreProfile(
          family.profileId,
          ownerUserId: family.ownerUserId,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('restoreProfile restores remote and updates Hive cache on success', () async {
      final family = ProfileModel(
        profileId: 'family-online-restore',
        ownerUserId: 'user-1',
        fullName: 'Brother',
        relationship: 'Brother',
        isPrimary: false,
        isArchived: true,
        archivedAt: DateTime.now(),
      );
      await localDataSource.saveProfile(family);
      fakeRemoteDataSource.remoteProfiles.add(family);

      final restored = await profileRepo.restoreProfile(
        family.profileId,
        ownerUserId: family.ownerUserId,
      );

      expect(restored.isArchived, isFalse);
      expect(restored.archivedAt, isNull);

      final cached = await localDataSource.getProfileById(
        family.profileId,
        ownerUserId: family.ownerUserId,
      );
      expect(cached?.isArchived, isFalse);
    });

    test('getArchivedProfiles returns only archived profiles for ownerUserId', () async {
      final active = ProfileModel(
        profileId: 'prof-active-1',
        ownerUserId: 'user-1',
        fullName: 'Active Son',
        relationship: 'Son',
        isPrimary: false,
        isArchived: false,
      );
      final archived = ProfileModel(
        profileId: 'prof-archived-1',
        ownerUserId: 'user-1',
        fullName: 'Archived Uncle',
        relationship: 'Uncle',
        isPrimary: false,
        isArchived: true,
      );
      final otherUserArchived = ProfileModel(
        profileId: 'prof-archived-user-2',
        ownerUserId: 'user-2',
        fullName: 'Other User Archived',
        relationship: 'Aunt',
        isPrimary: false,
        isArchived: true,
      );

      await localDataSource.saveProfile(active);
      await localDataSource.saveProfile(archived);
      await localDataSource.saveProfile(otherUserArchived);

      final result = await profileRepo.getArchivedProfiles('user-1');
      expect(result.length, 1);
      expect(result.first.profileId, 'prof-archived-1');
      expect(result.first.fullName, 'Archived Uncle');
    });

    test('uploadProfilePhoto throws StateError if profile is archived in Hive', () async {
      final archived = ProfileModel(
        profileId: 'family-archived-photo',
        ownerUserId: 'user-1',
        fullName: 'Archived Aunt',
        relationship: 'Aunt',
        isPrimary: false,
        isArchived: true,
      );
      await localDataSource.saveProfile(archived);

      final photoFile = File('${tempDir.path}/test_upload.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      expect(
        () => profileRepo.uploadProfilePhoto(
          archived.profileId,
          photoFile,
          ownerUserId: archived.ownerUserId,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot modify avatar for an archived profile'),
        )),
      );
    });

    test('uploadProfilePhoto throws NetworkException when offline', () async {
      final active = ProfileModel(
        profileId: 'family-active-offline',
        ownerUserId: 'user-1',
        fullName: 'Active Cousin',
        relationship: 'Cousin',
        isPrimary: false,
        isArchived: false,
      );
      await localDataSource.saveProfile(active);
      fakeConnectivity.isOnline = false;

      final photoFile = File('${tempDir.path}/test_upload.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      expect(
        () => profileRepo.uploadProfilePhoto(
          active.profileId,
          photoFile,
          ownerUserId: active.ownerUserId,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('uploadProfilePhoto updates remote photo and caches in Hive on success', () async {
      final active = ProfileModel(
        profileId: 'family-active-upload',
        ownerUserId: 'user-1',
        fullName: 'Active Cousin',
        relationship: 'Cousin',
        isPrimary: false,
        isArchived: false,
      );
      await localDataSource.saveProfile(active);
      fakeRemoteDataSource.remoteProfiles.add(active);

      final photoFile = File('${tempDir.path}/test_upload.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      final updated = await profileRepo.uploadProfilePhoto(
        active.profileId,
        photoFile,
        ownerUserId: active.ownerUserId,
      );

      expect(updated.photo, 'user-1/family-active-upload/uploaded.jpg');
      final cached = await localDataSource.getProfileById(
        active.profileId,
        ownerUserId: active.ownerUserId,
      );
      expect(cached?.photo, 'user-1/family-active-upload/uploaded.jpg');
    });

    test('deleteProfilePhoto throws StateError if profile is archived in Hive', () async {
      final archived = ProfileModel(
        profileId: 'family-archived-delete',
        ownerUserId: 'user-1',
        fullName: 'Archived Aunt',
        relationship: 'Aunt',
        isPrimary: false,
        isArchived: true,
        photo: 'user-1/family-archived-delete/uploaded.jpg',
      );
      await localDataSource.saveProfile(archived);

      expect(
        () => profileRepo.deleteProfilePhoto(
          archived.profileId,
          ownerUserId: archived.ownerUserId,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot modify avatar for an archived profile'),
        )),
      );
    });

    test('deleteProfilePhoto throws NetworkException when offline', () async {
      final active = ProfileModel(
        profileId: 'family-delete-offline',
        ownerUserId: 'user-1',
        fullName: 'Active Cousin',
        relationship: 'Cousin',
        isPrimary: false,
        isArchived: false,
        photo: 'user-1/family-delete-offline/uploaded.jpg',
      );
      await localDataSource.saveProfile(active);
      fakeConnectivity.isOnline = false;

      expect(
        () => profileRepo.deleteProfilePhoto(
          active.profileId,
          ownerUserId: active.ownerUserId,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('deleteProfilePhoto clears remote photo and updates Hive cache on success', () async {
      final active = ProfileModel(
        profileId: 'family-active-delete-success',
        ownerUserId: 'user-1',
        fullName: 'Active Cousin',
        relationship: 'Cousin',
        isPrimary: false,
        isArchived: false,
        photo: 'user-1/family-active-delete-success/uploaded.jpg',
      );
      await localDataSource.saveProfile(active);
      fakeRemoteDataSource.remoteProfiles.add(active);

      final updated = await profileRepo.deleteProfilePhoto(
        active.profileId,
        ownerUserId: active.ownerUserId,
      );

      expect(updated.photo, isNull);
      final cached = await localDataSource.getProfileById(
        active.profileId,
        ownerUserId: active.ownerUserId,
      );
      expect(cached?.photo, isNull);
    });
  });
}
