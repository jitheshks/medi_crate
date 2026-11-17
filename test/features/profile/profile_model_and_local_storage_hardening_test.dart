import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
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

  final userA = UserModel(
    id: 'user-uuid-A',
    name: 'User Alpha',
    email: 'alpha@example.com',
  );

  final userB = UserModel(
    id: 'user-uuid-B',
    name: 'User Beta',
    email: 'beta@example.com',
  );

  final profileA1 = ProfileModel(
    profileId: 'prof-A-self',
    ownerUserId: 'user-uuid-A',
    fullName: 'Alpha Self',
    relationship: 'Self',
    gender: 'Male',
    dateOfBirth: '1990-01-01',
    bloodGroup: 'O+',
    height: 180.0,
    weight: 75.0,
    photo: 'path/to/photo.jpg',
    notes: 'Initial alpha notes',
    relationshipOther: null,
    isPrimary: true,
  );

  final profileA2 = ProfileModel(
    profileId: 'prof-A-father',
    ownerUserId: 'user-uuid-A',
    fullName: 'Alpha Father',
    relationship: 'Father',
    isPrimary: false,
  );

  final profileB1 = ProfileModel(
    profileId: 'prof-B-self',
    ownerUserId: 'user-uuid-B',
    fullName: 'Beta Self',
    relationship: 'Self',
    isPrimary: true,
  );

  final profileB2 = ProfileModel(
    profileId: 'prof-B-child',
    ownerUserId: 'user-uuid-B',
    fullName: 'Beta Child',
    relationship: 'Other',
    relationshipOther: 'Adopted Child',
    isPrimary: false,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('profile_hardening_test_');
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
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthNotifier(initialState: authState)),
        hiveServiceProvider.overrideWithValue(hiveService),
        profileLocalDataSourceProvider.overrideWithValue(localDataSource),
        supabaseProfileRemoteDataSourceProvider.overrideWithValue(fakeRemoteDataSource),
        connectivityServiceProvider.overrideWithValue(fakeConnectivity),
        syncServiceProvider.overrideWithValue(syncService),
        profileRepositoryProvider.overrideWithValue(profileRepo),
      ],
    );
  }

  group('TASK 1 — ProfileModel.copyWith Clear Flags', () {
    test('1. Clearing gender via copyWith(clearGender: true)', () {
      expect(profileA1.gender, 'Male');
      final cleared = profileA1.copyWith(clearGender: true);
      expect(cleared.gender, isNull);
      expect(cleared.dateOfBirth, profileA1.dateOfBirth);
      expect(cleared.bloodGroup, profileA1.bloodGroup);
    });

    test('2. Clearing date of birth via copyWith(clearDateOfBirth: true)', () {
      expect(profileA1.dateOfBirth, '1990-01-01');
      final cleared = profileA1.copyWith(clearDateOfBirth: true);
      expect(cleared.dateOfBirth, isNull);
      expect(cleared.gender, profileA1.gender);
    });

    test('3. Clearing blood group via copyWith(clearBloodGroup: true)', () {
      expect(profileA1.bloodGroup, 'O+');
      final cleared = profileA1.copyWith(clearBloodGroup: true);
      expect(cleared.bloodGroup, isNull);
      expect(cleared.gender, profileA1.gender);
    });

    test('4. Clearing height and weight via copyWith(clearHeight: true, clearWeight: true)', () {
      expect(profileA1.height, 180.0);
      expect(profileA1.weight, 75.0);
      final cleared = profileA1.copyWith(clearHeight: true, clearWeight: true);
      expect(cleared.height, isNull);
      expect(cleared.weight, isNull);
      expect(cleared.fullName, profileA1.fullName);
    });

    test('5. Clearing notes via copyWith(clearNotes: true)', () {
      expect(profileA1.notes, 'Initial alpha notes');
      final cleared = profileA1.copyWith(clearNotes: true);
      expect(cleared.notes, isNull);
    });

    test('6. Clearing relationshipOther via copyWith(clearRelationshipOther: true)', () {
      expect(profileB2.relationshipOther, 'Adopted Child');
      final cleared = profileB2.copyWith(clearRelationshipOther: true);
      expect(cleared.relationshipOther, isNull);
      expect(cleared.relationship, 'Other');
    });

    test('7. Existing values preserved when clear flags are false', () {
      final unchanged = profileA1.copyWith();
      expect(unchanged.gender, 'Male');
      expect(unchanged.dateOfBirth, '1990-01-01');
      expect(unchanged.bloodGroup, 'O+');
      expect(unchanged.height, 180.0);
      expect(unchanged.weight, 75.0);
      expect(unchanged.photo, 'path/to/photo.jpg');
      expect(unchanged.notes, 'Initial alpha notes');

      // Supplying new values overrides without clearing others
      final partialUpdate = profileA1.copyWith(gender: 'Female');
      expect(partialUpdate.gender, 'Female');
      expect(partialUpdate.dateOfBirth, '1990-01-01');
      expect(partialUpdate.bloodGroup, 'O+');
    });

    test('8. Existing clearPhoto and clearServerProfileId behavior preserved', () {
      expect(profileA1.photo, isNotNull);
      final clearedPhoto = profileA1.copyWith(clearPhoto: true);
      expect(clearedPhoto.photo, isNull);
      expect(clearedPhoto.fullName, profileA1.fullName);

      final withServerId = profileA1.copyWith(serverProfileId: 101);
      expect(withServerId.serverProfileId, 101);
      final clearedServerId = withServerId.copyWith(clearServerProfileId: true);
      expect(clearedServerId.serverProfileId, isNull);
    });
  });

  group('TASK 2 & 3 — Account-Scoped Active Profile & Owner Isolation', () {
    test('9. Independent active profile IDs for two accounts (user_A vs user_B)', () async {
      await localDataSource.saveProfiles([profileA1, profileA2, profileB1, profileB2]);

      // User A selects profileA2
      await localDataSource.setActiveProfileId(
        profileId: profileA2.profileId,
        ownerUserId: userA.id,
      );

      // User B selects profileB2
      await localDataSource.setActiveProfileId(
        profileId: profileB2.profileId,
        ownerUserId: userB.id,
      );

      // Verify each user has their own independent active profile ID in Hive
      expect(await localDataSource.getActiveProfileId(userA.id), profileA2.profileId);
      expect(await localDataSource.getActiveProfileId(userB.id), profileB2.profileId);

      expect(localDataSource.getActiveProfileIdSync(userA.id), profileA2.profileId);
      expect(localDataSource.getActiveProfileIdSync(userB.id), profileB2.profileId);
    });

    test('10. Account switching without profile leakage', () async {
      await localDataSource.saveProfiles([profileA1, profileA2, profileB1]);

      // User A selects father profile
      await localDataSource.setActiveProfileId(
        profileId: profileA2.profileId,
        ownerUserId: userA.id,
      );

      // User A logs out and session is cleared
      await profileRepo.clearSessionProfileData(userA.id);
      expect(await localDataSource.getActiveProfileId(userA.id), isNull);

      // User B logs in: User B's active profile falls back to Beta Self, never User A's Father
      final containerB = createContainer(currentUser: userB);
      await containerB.read(profilesListProvider.future);

      final activeB = containerB.read(activeProfileProvider);
      expect(activeB, isNotNull);
      expect(activeB!.ownerUserId, userB.id);
      expect(activeB.profileId, profileB1.profileId);
      expect(activeB.fullName, 'Beta Self');
    });

    test('11. Safe handling of legacy global key (migrated only when owned & active; ignored if unowned/archived)', () async {
      await localDataSource.saveProfiles([profileA1, profileA2]);

      // Scenario 1: Legacy key contains profile owned by User A and active -> should migrate
      await hiveService.userBox.put('active_profile_id', {'id': profileA2.profileId});
      expect(hiveService.userBox.containsKey('active_profile_id'), isTrue);

      final activeA = await localDataSource.getActiveProfileId(userA.id);
      expect(activeA, profileA2.profileId);
      // Legacy key migrated to account-scoped key and purged from global key
      expect(hiveService.userBox.containsKey('active_profile_id'), isFalse);
      expect(
        hiveService.userBox.get('active_profile_id_${userA.id}'),
        {'id': profileA2.profileId},
      );

      // Scenario 2: Legacy key contains profile belonging to another user (User B) -> should NOT migrate for User A
      await hiveService.userBox.put('active_profile_id', {'id': profileB1.profileId});
      final activeForUserA = await localDataSource.getActiveProfileId(userA.id);
      // User A does not own profileB1, so returns previously set active profile (or null if none)
      expect(activeForUserA, profileA2.profileId);

      // Scenario 3: Legacy key contains an archived profile -> ignored, not migrated
      final archivedA = profileA2.copyWith(isArchived: true, archivedAt: DateTime.now());
      await localDataSource.saveProfile(archivedA);
      await hiveService.userBox.delete('active_profile_id_${userA.id}');
      await hiveService.userBox.put('active_profile_id', {'id': archivedA.profileId});

      final activeAfterArchived = await localDataSource.getActiveProfileId(userA.id);
      expect(activeAfterArchived, isNull);
    });

    test('12. Rejecting a profile belonging to another owner in getProfileById and setActiveProfileId', () async {
      await localDataSource.saveProfiles([profileA1, profileB1]);

      // getProfileById returns null when ownerUserId does not match
      final fetchedForWrongOwner = await localDataSource.getProfileById(
        profileB1.profileId,
        ownerUserId: userA.id,
      );
      expect(fetchedForWrongOwner, isNull);

      final fetchedForCorrectOwner = await localDataSource.getProfileById(
        profileB1.profileId,
        ownerUserId: userB.id,
      );
      expect(fetchedForCorrectOwner, isNotNull);
      expect(fetchedForCorrectOwner!.profileId, profileB1.profileId);

      // setActiveProfileId throws StateError when profile belongs to another owner
      expect(
        () => localDataSource.setActiveProfileId(
          profileId: profileB1.profileId,
          ownerUserId: userA.id,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('does not belong to owner'),
        )),
      );
    });
  });

  group('TASK 4 — Harden setActiveProfileId & Local Lookup Validation', () {
    test('13. Rejecting archived profiles in local lookup/selection', () async {
      final archivedProfile = profileA2.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
      );
      await localDataSource.saveProfiles([profileA1, archivedProfile]);

      // setActiveProfileId throws StateError on archived profile
      expect(
        () => localDataSource.setActiveProfileId(
          profileId: archivedProfile.profileId,
          ownerUserId: userA.id,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('archived'),
        )),
      );

      // getActiveProfileId ignores archived profile if stored in userBox
      await hiveService.userBox.put(
        'active_profile_id_${userA.id}',
        {'id': archivedProfile.profileId},
      );
      expect(await localDataSource.getActiveProfileId(userA.id), isNull);
      expect(localDataSource.getActiveProfileIdSync(userA.id), isNull);
    });

    test('14. Invalid setter calls preserving previous active profile', () async {
      await localDataSource.saveProfiles([profileA1, profileA2, profileB1]);

      // Set initially valid active profile
      await localDataSource.setActiveProfileId(
        profileId: profileA1.profileId,
        ownerUserId: userA.id,
      );
      expect(await localDataSource.getActiveProfileId(userA.id), profileA1.profileId);

      // Attempt 1: Non-existent profile
      expect(
        () => localDataSource.setActiveProfileId(
          profileId: 'non-existent-prof-id',
          ownerUserId: userA.id,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await localDataSource.getActiveProfileId(userA.id), profileA1.profileId);

      // Attempt 2: Another owner's profile
      expect(
        () => localDataSource.setActiveProfileId(
          profileId: profileB1.profileId,
          ownerUserId: userA.id,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await localDataSource.getActiveProfileId(userA.id), profileA1.profileId);

      // Attempt 3: Archived profile
      final archived = profileA2.copyWith(isArchived: true, archivedAt: DateTime.now());
      await localDataSource.saveProfile(archived);
      expect(
        () => localDataSource.setActiveProfileId(
          profileId: archived.profileId,
          ownerUserId: userA.id,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await localDataSource.getActiveProfileId(userA.id), profileA1.profileId);
    });

    test('15. Primary Self fallback after invalid or archived selection in Riverpod', () async {
      final archived = profileA2.copyWith(isArchived: true, archivedAt: DateTime.now());
      await localDataSource.saveProfiles([profileA1, archived]);

      // Storing archived or corrupt profile directly in Hive simulates stale state
      await hiveService.userBox.put(
        'active_profile_id_${userA.id}',
        {'id': archived.profileId},
      );

      final container = createContainer(currentUser: userA);
      await container.read(profilesListProvider.future);

      final active = container.read(activeProfileProvider);
      expect(active, isNotNull);
      expect(active!.profileId, profileA1.profileId);
      expect(active.isPrimary, isTrue);
      expect(active.fullName, 'Alpha Self');

      // Attempting to select an archived profile via notifier throws StateError
      expect(
        () => container.read(activeProfileProvider.notifier).selectProfile(archived),
        throwsA(isA<StateError>()),
      );
      // Active remains primary Self
      expect(container.read(activeProfileProvider)?.profileId, profileA1.profileId);
    });
  });
}
