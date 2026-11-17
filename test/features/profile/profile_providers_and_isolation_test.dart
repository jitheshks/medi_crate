import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_profile_query_helper.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/datasources/local/profile_local_data_source.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/data/repositories/profile_repository.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> checkConnectivity() async => true;

  @override
  Future<bool> checkInternetAccess() async => true;

  @override
  Future<List<ConnectivityResult>> getTransports() async => [ConnectivityResult.wifi];

  @override
  Future<NetworkStatusModel> getDetailedStatus() async =>
      const NetworkStatusModel(transports: [ConnectivityResult.wifi], hasInternet: true);

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);

  @override
  void dispose() {}
}

class _FakeSupabaseProfileRemoteDataSource extends SupabaseProfileRemoteDataSource {
  final List<ProfileModel> profiles = [];

  @override
  Future<List<ProfileModel>> fetchProfiles({
    required String ownerUserId,
    bool includeArchived = false,
  }) async {
    return profiles.where((p) {
      if (p.ownerUserId != ownerUserId) return false;
      if (!includeArchived && p.isArchived) return false;
      return true;
    }).toList();
  }

  @override
  Future<ProfileModel> createFamilyProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    final created = profile.copyWith(
      profileId: 'server-${DateTime.now().microsecondsSinceEpoch}',
      ownerUserId: ownerUserId,
      isPrimary: false,
    );
    profiles.add(created);
    return created;
  }

  @override
  Future<ProfileModel> archiveProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    final idx = profiles.indexWhere(
      (p) => p.profileId == profileId && p.ownerUserId == ownerUserId,
    );
    if (idx >= 0) {
      final archived = profiles[idx].copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
      );
      profiles[idx] = archived;
      return archived;
    }
    throw const NotFoundException('Profile not found');
  }

  @override
  Future<ProfileModel> restoreProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    final idx = profiles.indexWhere(
      (p) => p.profileId == profileId && p.ownerUserId == ownerUserId,
    );
    if (idx >= 0) {
      final restored = profiles[idx].copyWith(
        isArchived: false,
        clearArchivedAt: true,
      );
      profiles[idx] = restored;
      return restored;
    }
    throw const NotFoundException('Profile not found');
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  _FakeAuthNotifier({required this.initialState});

  @override
  AuthState build() => initialState;
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

  final user1 = UserModel(
    id: 'user-uuid-1',
    name: 'Jane Doe',
    email: 'jane@example.com',
  );

  final user2 = UserModel(
    id: 'user-uuid-2',
    name: 'Alice Smith',
    email: 'alice@example.com',
  );

  final selfProfile = ProfileModel(
    profileId: 'prof-self-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Jane Doe',
    relationship: 'Self',
    isPrimary: true,
  );

  final fatherProfile = ProfileModel(
    profileId: 'prof-father-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Robert Doe',
    relationship: 'Father',
    isPrimary: false,
  );

  final motherProfile = ProfileModel(
    profileId: 'prof-mother-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Eleanor Doe',
    relationship: 'Mother',
    isPrimary: false,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('profile_providers_test_');
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

  ProviderContainer createContainer({UserModel? currentUser}) {
    final authState = AuthState(
      isLoading: false,
      isAuthenticated: currentUser != null,
      user: currentUser,
    );

    final container = ProviderContainer(
      overrides: [
        hiveServiceProvider.overrideWithValue(hiveService),
        connectivityServiceProvider.overrideWithValue(fakeConnectivity),
        profileLocalDataSourceProvider.overrideWithValue(localDataSource),
        supabaseProfileRemoteDataSourceProvider.overrideWithValue(fakeRemoteDataSource),
        profileRepositoryProvider.overrideWithValue(profileRepo),
        authControllerProvider.overrideWith(
          () => _FakeAuthNotifier(initialState: authState),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Profile State Management & Clinical Data Isolation', () {
    test('profilesListProvider loads cached profiles and activeProfileProvider defaults to primary Self', () async {
      await localDataSource.saveProfiles([selfProfile, fatherProfile, motherProfile]);

      final container = createContainer(currentUser: user1);

      final profiles = await container.read(profilesListProvider.future);
      expect(profiles.length, 3);

      final active = container.read(activeProfileProvider);
      expect(active, isNotNull);
      expect(active!.profileId, selfProfile.profileId);
      expect(active.isPrimary, isTrue);
    });

    test('active profile switching sequence (Self -> Father -> Mother -> Self)', () async {
      await localDataSource.saveProfiles([selfProfile, fatherProfile, motherProfile]);

      final container = createContainer(currentUser: user1);
      await container.read(profilesListProvider.future);

      final activeNotifier = container.read(activeProfileProvider.notifier);

      // 1. Initial is Self
      expect(container.read(activeProfileProvider)?.profileId, selfProfile.profileId);

      // 2. Switch to Father
      await activeNotifier.selectProfile(fatherProfile);
      expect(container.read(activeProfileProvider)?.profileId, fatherProfile.profileId);
      expect(await localDataSource.getActiveProfileId(user1.id), fatherProfile.profileId);

      // 3. Switch to Mother
      await activeNotifier.selectProfile(motherProfile);
      expect(container.read(activeProfileProvider)?.profileId, motherProfile.profileId);
      expect(await localDataSource.getActiveProfileId(user1.id), motherProfile.profileId);

      // 4. Switch back to Self
      await activeNotifier.selectProfile(selfProfile);
      expect(container.read(activeProfileProvider)?.profileId, selfProfile.profileId);
      expect(await localDataSource.getActiveProfileId(user1.id), selfProfile.profileId);
    });

    test('recovers safely when stored active profile ID is invalid or deleted', () async {
      await localDataSource.saveProfiles([selfProfile, fatherProfile]);
      // Manually write an obsolete or corrupted active profile ID directly to user box
      await hiveService.userBox.put(
        'active_profile_id_${user1.id}',
        {'id': 'non-existent-profile-id'},
      );

      final container = createContainer(currentUser: user1);
      await container.read(profilesListProvider.future);

      // ActiveProfileNotifier should automatically fall back to primary Self
      final active = container.read(activeProfileProvider);
      expect(active, isNotNull);
      expect(active!.profileId, selfProfile.profileId);
      expect(active.isPrimary, isTrue);
    });

    test('account switching cleans active profile and isolates user data', () async {
      // User 1 logs in and switches to Father
      await localDataSource.saveProfiles([selfProfile, fatherProfile]);
      await localDataSource.setActiveProfileId(
        profileId: fatherProfile.profileId,
        ownerUserId: user1.id,
      );

      final container1 = createContainer(currentUser: user1);
      await container1.read(profilesListProvider.future);
      expect(container1.read(activeProfileProvider)?.profileId, fatherProfile.profileId);

      // User 1 signs out: clearSessionProfileData is called
      await profileRepo.clearSessionProfileData(user1.id);
      expect(await localDataSource.getActiveProfileId(user1.id), isNull);

      // User 2 logs in with their own profile
      final user2Self = ProfileModel(
        profileId: 'prof-user2-self',
        ownerUserId: 'user-uuid-2',
        fullName: 'Alice Smith',
        relationship: 'Self',
        isPrimary: true,
      );
      await localDataSource.saveProfile(user2Self);

      final container2 = createContainer(currentUser: user2);
      final user2Profiles = await container2.read(profilesListProvider.future);
      expect(user2Profiles.length, 1);
      expect(user2Profiles.first.fullName, 'Alice Smith');

      // User 2's active profile defaults to Alice Smith, not User 1's Father
      final active2 = container2.read(activeProfileProvider);
      expect(active2?.profileId, user2Self.profileId);
      expect(active2?.fullName, 'Alice Smith');
    });

    test('clinical records in Hive are strictly isolated by profileId', () async {
      final userBox = hiveService.userBox;

      // Seed clinical records for Self (consultation 101) and Father (consultation 102)
      await userBox.put('con_101', {
        'id': '101',
        'profile_id': selfProfile.profileId,
        'doctor_name': 'Dr. House',
        'diagnosis': 'Seasonal Flu',
      });
      await userBox.put('con_102', {
        'id': '102',
        'profile_id': fatherProfile.profileId,
        'doctor_name': 'Dr. Watson',
        'diagnosis': 'Hypertension Followup',
      });

      // Query for Self
      final selfRecords = HiveProfileQueryHelper.getRecordsForProfile(
        userBox: userBox,
        keyPrefix: 'con_',
        profileId: selfProfile.profileId,
      );
      expect(selfRecords.length, 1);
      expect(selfRecords.first['doctor_name'], 'Dr. House');

      // Query for Father
      final fatherRecords = HiveProfileQueryHelper.getRecordsForProfile(
        userBox: userBox,
        keyPrefix: 'con_',
        profileId: fatherProfile.profileId,
      );
      expect(fatherRecords.length, 1);
      expect(fatherRecords.first['doctor_name'], 'Dr. Watson');

      // Query for Mother (has no records)
      final motherRecords = HiveProfileQueryHelper.getRecordsForProfile(
        userBox: userBox,
        keyPrefix: 'con_',
        profileId: motherProfile.profileId,
      );
      expect(motherRecords.isEmpty, isTrue);
    });

    test('ActiveProfileNotifier ignores archived profile and falls back to primary Self', () async {
      final archivedMember = ProfileModel(
        profileId: 'archived-uuid-2',
        ownerUserId: user1.id,
        fullName: 'Archived Member',
        relationship: 'Father',
        isPrimary: false,
        isArchived: true,
        archivedAt: DateTime.now(),
      );

      await localDataSource.saveProfiles([selfProfile, archivedMember]);
      await hiveService.userBox.put(
        'active_profile_id_${user1.id}',
        {'id': archivedMember.profileId},
      );

      final container = createContainer(currentUser: user1);
      await container.read(profilesListProvider.future);

      // Verify activeProfileProvider automatically falls back to primary Self
      final active = container.read(activeProfileProvider);
      expect(active?.profileId, selfProfile.profileId);
      expect(active?.fullName, 'Jane Doe');

      // Verify the fallback profile ID was persisted in Hive, purging the archived ID
      final persistedActiveId = localDataSource.getActiveProfileIdSync(user1.id);
      expect(persistedActiveId, selfProfile.profileId);

      // Attempting to select an archived profile must throw StateError
      expect(
        () => container.read(activeProfileProvider.notifier).selectProfile(archivedMember),
        throwsA(isA<StateError>()),
      );
    });

    test('ProfilesListNotifier.archiveProfile excludes profile and falls back active to primary Self', () async {
      final familyProfile = ProfileModel(
        profileId: 'family-active-to-archive',
        ownerUserId: user1.id,
        fullName: 'Active Family Member',
        relationship: 'Son',
        isPrimary: false,
        isArchived: false,
      );

      await localDataSource.saveProfiles([selfProfile, familyProfile]);
      fakeRemoteDataSource.profiles.addAll([selfProfile, familyProfile]);

      final container = createContainer(currentUser: user1);
      await container.read(profilesListProvider.future);

      // Select family member as active
      await container.read(activeProfileProvider.notifier).selectProfile(familyProfile);
      expect(container.read(activeProfileProvider)?.profileId, familyProfile.profileId);

      // Archive family member
      final archived = await container
          .read(profilesListProvider.notifier)
          .archiveProfile(familyProfile.profileId);
      expect(archived.isArchived, isTrue);

      // Active profile automatically switched to primary Self
      expect(container.read(activeProfileProvider)?.profileId, selfProfile.profileId);

      // Active profiles list excludes archived
      final activeList = container.read(profilesListProvider).value ?? [];
      expect(activeList.any((p) => p.profileId == familyProfile.profileId), isFalse);

      // Archived list provider contains archived profile
      final archivedList = await container.read(archivedProfilesListProvider.future);
      expect(archivedList.any((p) => p.profileId == familyProfile.profileId), isTrue);
    });

    test('ProfilesListNotifier.restoreProfile restores profile and updates both providers', () async {
      final archivedFamily = ProfileModel(
        profileId: 'family-archived-to-restore',
        ownerUserId: user1.id,
        fullName: 'Archived Family Member',
        relationship: 'Daughter',
        isPrimary: false,
        isArchived: true,
        archivedAt: DateTime.now(),
      );

      await localDataSource.saveProfiles([selfProfile, archivedFamily]);
      fakeRemoteDataSource.profiles.addAll([selfProfile, archivedFamily]);

      final container = createContainer(currentUser: user1);
      await container.read(profilesListProvider.future);

      // Initially active list excludes archivedFamily
      final initialActive = container.read(profilesListProvider).value ?? [];
      expect(initialActive.any((p) => p.profileId == archivedFamily.profileId), isFalse);

      // Initially archived list includes archivedFamily
      final initialArchived = await container.read(archivedProfilesListProvider.future);
      expect(initialArchived.any((p) => p.profileId == archivedFamily.profileId), isTrue);

      // Restore
      final restored = await container
          .read(profilesListProvider.notifier)
          .restoreProfile(archivedFamily.profileId);
      expect(restored.isArchived, isFalse);

      // Active list now includes restored profile
      final updatedActive = container.read(profilesListProvider).value ?? [];
      expect(updatedActive.any((p) => p.profileId == archivedFamily.profileId), isTrue);

      // Archived list now excludes restored profile
      final updatedArchived = await container.read(archivedProfilesListProvider.future);
      expect(updatedArchived.any((p) => p.profileId == archivedFamily.profileId), isFalse);
    });
  });
}
