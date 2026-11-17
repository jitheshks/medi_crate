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
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
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
  late ProfileLocalDataSource profileLocalDataSource;
  late SupabaseProfileRemoteDataSource remoteDataSource;
  late _FakeConnectivityService connectivityService;
  late SyncService syncService;
  late ProfileRepository profileRepo;
  late ConsultationRepository consultationRepo;

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
    tempDir = await Directory.systemTemp.createTemp('clinical_isolation_test_');
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
    profileLocalDataSource = ProfileLocalDataSource(hiveService: hiveService);
    remoteDataSource = SupabaseProfileRemoteDataSource();
    connectivityService = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: connectivityService,
    );

    profileRepo = ProfileRepository(
      localDataSource: profileLocalDataSource,
      remoteDataSource: remoteDataSource,
      connectivityService: connectivityService,
      syncService: syncService,
      hiveService: hiveService,
    );

    consultationRepo = ConsultationRepository(
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
        connectivityServiceProvider.overrideWithValue(connectivityService),
        profileLocalDataSourceProvider.overrideWithValue(profileLocalDataSource),
        profileRepositoryProvider.overrideWithValue(profileRepo),
        consultationRepositoryProvider.overrideWithValue(consultationRepo),
        authControllerProvider.overrideWith(
          () => _FakeAuthNotifier(initialState: authState),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Clinical Multi-Profile Isolation End-to-End Workflow', () {
    test('profile switching reactivity and clinical record segregation', () async {
      // 1. Seed user 1 profiles: Self, Father, Mother
      await profileLocalDataSource.saveProfiles([selfProfile, fatherProfile, motherProfile]);

      final container = createContainer(currentUser: user1);

      // Verify initial active profile defaults to Self
      final activeNotifier = container.read(activeProfileProvider.notifier);
      await container.read(profilesListProvider.future);
      expect(container.read(activeProfileProvider)?.profileId, selfProfile.profileId);

      // 2. Switch to Father
      await activeNotifier.selectProfile(fatherProfile);
      expect(container.read(activeProfileProvider)?.profileId, fatherProfile.profileId);

      // 3. Create a consultation under active profile (Father)
      final consultationNotifier = container.read(consultationsListNotifierProvider.notifier);
      final newConsultation = ConsultationModel(
        id: 'con-101',
        profileId: fatherProfile.profileId,
        doctorName: 'Dr. Gregory House',
        chiefComplaint: 'High BP',
        diagnosis: 'Stage 1 Hypertension',
        visitDate: DateTime.parse('2026-11-10T10:00:00Z'),
        createdAt: DateTime.now(),
      );

      final saved = await consultationNotifier.saveConsultation(newConsultation);
      expect(saved.profileId, fatherProfile.profileId);

      // Verify consultations for Father shows 1 record
      final fatherConsultations = await container.read(consultationsListNotifierProvider.future);
      expect(fatherConsultations.length, 1);
      expect(fatherConsultations.first.diagnosis, 'Stage 1 Hypertension');

      // 4. Switch to Mother (Self -> Father -> Mother)
      await activeNotifier.selectProfile(motherProfile);
      expect(container.read(activeProfileProvider)?.profileId, motherProfile.profileId);

      // Verify Mother's consultations list is empty (Father's consultation is strictly isolated)
      final motherConsultations = await container.read(consultationsListNotifierProvider.future);
      expect(motherConsultations.isEmpty, isTrue);

      // 5. Switch to Self (Mother -> Self)
      await activeNotifier.selectProfile(selfProfile);
      expect(container.read(activeProfileProvider)?.profileId, selfProfile.profileId);

      // Verify Self's consultations list is empty
      final selfConsultations = await container.read(consultationsListNotifierProvider.future);
      expect(selfConsultations.isEmpty, isTrue);

      // 6. Switch back to Father: consultation is still intact
      await activeNotifier.selectProfile(fatherProfile);
      final restoredFatherConsultations = await container.read(consultationsListNotifierProvider.future);
      expect(restoredFatherConsultations.length, 1);
      expect(restoredFatherConsultations.first.doctorName, 'Dr. Gregory House');
    });

    test('application restart restores previously selected active profile from Hive', () async {
      await profileLocalDataSource.saveProfiles([selfProfile, fatherProfile, motherProfile]);
      // Persist Father as active profile in Hive
      await profileLocalDataSource.setActiveProfileId(
        profileId: fatherProfile.profileId,
        ownerUserId: user1.id,
      );

      // Simulate new app launch / container restart
      final newContainer = createContainer(currentUser: user1);
      await newContainer.read(profilesListProvider.future);

      final active = newContainer.read(activeProfileProvider);
      expect(active, isNotNull);
      expect(active!.profileId, fatherProfile.profileId);
      expect(active.fullName, 'Robert Doe');
    });

    test('invalid stored active profile ID recovers by falling back to Self primary profile', () async {
      await profileLocalDataSource.saveProfiles([selfProfile, fatherProfile]);
      // Store corrupted/stale profile ID directly in user box to test recovery
      await hiveService.userBox.put(
        'active_profile_id_${user1.id}',
        {'id': 'corrupted-non-existent-profile'},
      );

      final container = createContainer(currentUser: user1);
      await container.read(profilesListProvider.future);

      final active = container.read(activeProfileProvider);
      expect(active, isNotNull);
      expect(active!.profileId, selfProfile.profileId);
      expect(active.isPrimary, isTrue);
    });

    test('sign-out and switch to another account completely isolates clinical data', () async {
      // User 1 logs in, has records under Father profile
      await profileLocalDataSource.saveProfiles([selfProfile, fatherProfile]);
      await profileLocalDataSource.setActiveProfileId(
        profileId: fatherProfile.profileId,
        ownerUserId: user1.id,
      );
      await consultationRepo.saveConsultationModel(
        fatherProfile.profileId,
        ConsultationModel(
          id: 'con-user1',
          profileId: fatherProfile.profileId,
          doctorName: 'Dr. John Watson',
          chiefComplaint: 'Checkup',
          diagnosis: 'Diabetes Followup',
          visitDate: DateTime.parse('2026-11-10T10:00:00Z'),
          createdAt: DateTime.now(),
        ),
      );

      // User 1 signs out: session profile state is cleared
      await profileRepo.clearSessionProfileData(user1.id);
      expect(await profileLocalDataSource.getActiveProfileId(user1.id), isNull);

      // User 2 signs in
      final user2Self = ProfileModel(
        profileId: 'prof-user2-self',
        ownerUserId: 'user-uuid-2',
        fullName: 'Alice Smith',
        relationship: 'Self',
        isPrimary: true,
      );
      await profileLocalDataSource.saveProfile(user2Self);

      final container2 = createContainer(currentUser: user2);
      await container2.read(profilesListProvider.future);

      final active2 = container2.read(activeProfileProvider);
      expect(active2?.profileId, user2Self.profileId);
      expect(active2?.fullName, 'Alice Smith');

      // User 2's consultations list has 0 records (User 1's records are inaccessible)
      final user2Consultations = await container2.read(consultationsListNotifierProvider.future);
      expect(user2Consultations.isEmpty, isTrue);
    });
  });
}
