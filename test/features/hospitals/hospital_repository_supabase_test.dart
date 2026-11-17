import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/features/hospitals/data/repositories/hospital_repository.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';

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

class _FakeSupabaseHospitalRemoteDataSource extends SupabaseHospitalRemoteDataSource {
  final List<HospitalModel> remoteHospitals = [];
  bool shouldThrowNetworkError = false;
  HospitalModel? lastCreatedHospital;
  HospitalModel? lastUpdatedHospital;
  String? lastDeletedHospitalId;
  int _idCounter = 0;

  @override
  Future<List<HospitalModel>> fetchHospitals({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? type,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final list = remoteHospitals.where((h) => h.profileId == profileId).toList();
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<HospitalModel?> getHospitalById({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    try {
      return remoteHospitals.firstWhere((h) => h.id == hospitalId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<HospitalModel> createHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedHospital = hospital;
    final cleanId = IdUtils.unprefix(hospital.id);
    _idCounter++;
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : 'b0000000-0000-0000-0000-${_idCounter.toString().padLeft(12, '0')}';
    final created = hospital.copyWith(
      id: effectiveId,
      profileId: profileId,
    );
    remoteHospitals.add(created);
    return created;
  }

  @override
  Future<HospitalModel> updateHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedHospital = hospital;
    final index = remoteHospitals.indexWhere((h) => h.id == hospital.id);
    if (index >= 0) {
      remoteHospitals[index] = hospital;
    } else {
      remoteHospitals.add(hospital);
    }
    return hospital;
  }

  @override
  Future<void> deleteHospital({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastDeletedHospitalId = hospitalId;
    remoteHospitals.removeWhere((h) => h.id == hospitalId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeSupabaseHospitalRemoteDataSource fakeRemoteDataSource;
  late _FakeConnectivityService fakeConnectivity;
  late SyncService syncService;
  late HospitalRepository hospitalRepo;
  bool pullFreshnessBumped = false;

  const ownerUserId = '11111111-2222-3333-4444-555555555555';
  const profileId = '22222222-3333-4444-5555-666666666666';
  const hospitalUuid = '33333333-4444-5555-6666-777777777777';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hospital_repo_test_');
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
    fakeRemoteDataSource = _FakeSupabaseHospitalRemoteDataSource();
    fakeConnectivity = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: fakeConnectivity,
    );

    pullFreshnessBumped = false;
    hospitalRepo = HospitalRepository(
      hiveService: hiveService,
      supabaseRemoteDataSource: fakeRemoteDataSource,
      connectivityService: fakeConnectivity,
      syncService: syncService,
      onPullMerged: () {
        pullFreshnessBumped = true;
      },
    );

    // Seed active session in authBox and active profile in profileBox
    await hiveService.authBox.put('current_user', {
      'id': ownerUserId,
      'user_id': ownerUserId,
      'email': 'hospital_user@example.com',
    });

    final profile = ProfileModel(
      profileId: profileId,
      ownerUserId: ownerUserId,
      fullName: 'Primary User',
      relationship: 'Self',
      isPrimary: true,
    );
    await hiveService.profileBox.put(profileId, profile.toMap());
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HospitalRepository Supabase Integration Tests', () {
    test('1. Sync flags remain active and suspended', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });

    test('2. pullHospitals fetches from Supabase and merges into Hive with freshness signal', () async {
      fakeRemoteDataSource.remoteHospitals.add(
        const HospitalModel(
          id: hospitalUuid,
          profileId: profileId,
          name: 'Mayo Clinic',
          type: 'Clinic',
          city: 'Rochester',
        ),
      );

      await hospitalRepo.pullHospitals(profileId);

      final cached = await hospitalRepo.getHospitalModels(profileId);
      expect(cached.length, equals(1));
      expect(cached.first.name, equals('Mayo Clinic'));
      expect(cached.first.type, equals('Clinic'));
      expect(pullFreshnessBumped, isTrue);
    });

    test('3. getHospitalById reads from Hive first, falls back to Supabase if missing locally', () async {
      fakeRemoteDataSource.remoteHospitals.add(
        const HospitalModel(
          id: hospitalUuid,
          profileId: profileId,
          name: 'Johns Hopkins Hospital',
          type: 'Hospital',
          city: 'Baltimore',
        ),
      );

      final hospital = await hospitalRepo.getHospitalById(profileId, hospitalUuid);
      expect(hospital, isNotNull);
      expect(hospital!.name, equals('Johns Hopkins Hospital'));

      final fromHive = hiveService.userBox.get('hospital_$hospitalUuid');
      expect(fromHive, isNotNull);
      expect(fromHive!['name'], equals('Johns Hopkins Hospital'));
    });

    test('4. saveHospitalModel updates existing Supabase hospital when ID is UUID', () async {
      final existingHosp = const HospitalModel(
        id: hospitalUuid,
        profileId: profileId,
        name: 'Apollo Hospital',
        type: 'Hospital',
        city: 'Bengaluru',
      );
      await hospitalRepo.saveHospitalModel(profileId, existingHosp);

      final updatedHosp = existingHosp.copyWith(
        name: 'Apollo Speciality Hospital',
        phone: '+91-80-22223333',
      );
      final result = await hospitalRepo.saveHospitalModel(profileId, updatedHosp);

      expect(result.name, equals('Apollo Speciality Hospital'));
      expect(fakeRemoteDataSource.lastUpdatedHospital?.name, equals('Apollo Speciality Hospital'));
      expect(hiveService.userBox.get('hospital_$hospitalUuid')?['name'], equals('Apollo Speciality Hospital'));
    });

    test('5. saveHospitalModel creates new hospital in Supabase and normalizes temporary key', () async {
      const newHospital = HospitalModel(
        id: '',
        profileId: profileId,
        name: 'Manipal Hospital',
        type: 'Hospital',
        city: 'Bengaluru',
      );

      final saved = await hospitalRepo.saveHospitalModel(profileId, newHospital);

      expect(saved.id, equals('hospital_b0000000-0000-0000-0000-000000000001'));
      expect(fakeRemoteDataSource.lastCreatedHospital?.name, equals('Manipal Hospital'));
      expect(hiveService.userBox.containsKey('hospital_b0000000-0000-0000-0000-000000000001'), isTrue);
    });

    test('6. deleteHospital enforces dependency check and preserves hospital when consultations exist', () async {
      final hospital = const HospitalModel(
        id: hospitalUuid,
        profileId: profileId,
        name: 'Fortis Hospital',
        type: 'Hospital',
      );
      await hospitalRepo.saveHospitalModel(profileId, hospital);

      // Link consultation to this hospital
      await hiveService.userBox.put('consultation_201', {
        'id': 'consultation_201',
        'profile_id': profileId,
        'hospital_id': hospitalUuid,
        'hospital_name': 'Fortis Hospital',
        'diagnosis': 'Fever',
      });

      // Attempt deletion -> Must throw ResourceHasDependenciesException
      await expectLater(
        hospitalRepo.deleteHospital(profileId, hospitalUuid),
        throwsA(isA<ResourceHasDependenciesException>()),
      );

      // Verify hospital is preserved
      expect(hiveService.userBox.containsKey('hospital_$hospitalUuid'), isTrue);
      expect(fakeRemoteDataSource.lastDeletedHospitalId, isNull);
    });

    test('7. Historical hospital snapshot remains intact in consultation when hospital is deleted without dependencies', () async {
      const targetHospitalId = '88888888-9999-0000-1111-222222222222';
      final hospital = const HospitalModel(
        id: targetHospitalId,
        profileId: profileId,
        name: 'Historic Clinic Facility',
        type: 'Clinic',
      );
      await hospitalRepo.saveHospitalModel(profileId, hospital);

      // Create an unlinked historical consultation that captured the hospital name at visit time
      await hiveService.userBox.put('consultation_historical_2', {
        'id': 'consultation_historical_2',
        'profile_id': profileId,
        'doctor_name': 'Dr. Independent',
        'hospital_id': 'different-facility-id',
        'hospital_name': 'Historic Clinic Facility (Archived Visit Location)',
        'diagnosis': 'Annual physical',
        'visit_date': '2024-06-20',
      });

      // Delete target hospital
      await hospitalRepo.deleteHospital(profileId, targetHospitalId);

      // Verify hospital was deleted from directory
      expect(hiveService.userBox.containsKey('hospital_$targetHospitalId'), isFalse);
      expect(fakeRemoteDataSource.lastDeletedHospitalId, equals(targetHospitalId));

      // Verify historical snapshot in consultation is intact
      final consultation = hiveService.userBox.get('consultation_historical_2');
      expect(consultation, isNotNull);
      expect(consultation!['hospital_name'], equals('Historic Clinic Facility (Archived Visit Location)'));
      expect(consultation['diagnosis'], equals('Annual physical'));
    });

    test('8. Offline save queues mutation and preserves local record', () async {
      fakeConnectivity.isOnline = false;

      const offlineHospital = HospitalModel(
        id: '',
        profileId: profileId,
        name: 'Offline Diagnostic Lab',
        type: 'Lab',
      );

      final result = await hospitalRepo.saveHospitalModel(profileId, offlineHospital);

      expect(result.name, equals('Offline Diagnostic Lab'));
      expect(hiveService.userBox.containsKey(result.id), isTrue);
      expect(hiveService.syncQueueBox.isNotEmpty, isTrue);
    });

    test('9. Cross-user isolation: hospital for profile belonging to another user cannot be pulled or saved to Supabase', () async {
      const otherUserId = '99999999-9999-9999-9999-999999999999';
      const foreignProfileId = '88888888-8888-8888-8888-888888888888';

      // Foreign profile owned by otherUserId stored in profileBox
      await hiveService.profileBox.put('prof_$foreignProfileId', {
        'id': foreignProfileId,
        'user_id': otherUserId,
        'owner_user_id': otherUserId,
        'name': 'Foreign User Profile',
      });

      // Attempting to pull with active user session targeting foreign profile
      final initialCount = fakeRemoteDataSource.remoteHospitals.length;
      await hospitalRepo.pullHospitals(foreignProfileId);

      // Verify no hospitals were pulled or added for foreign profile under this user
      expect(fakeRemoteDataSource.remoteHospitals.length, equals(initialCount));

      // Attempting to save hospital under foreign profile
      const hospitalForForeignProfile = HospitalModel(
        id: '',
        profileId: foreignProfileId,
        name: 'Foreign Clinic Reject',
        type: 'Clinic',
      );

      final saved = await hospitalRepo.saveHospitalModel(
        foreignProfileId,
        hospitalForForeignProfile,
        ownerUserId: ownerUserId,
      );

      // Hospital is saved locally in Hive but NOT synced to Supabase under mismatched profile
      expect(saved.name, equals('Foreign Clinic Reject'));
      expect(fakeRemoteDataSource.lastCreatedHospital?.name, isNot('Foreign Clinic Reject'));
    });

    test('10. Family profile switching maintains strict profile scoping', () async {
      const familyProfileId = '77777777-7777-7777-7777-777777777777';

      // Create a family profile for the same user
      await hiveService.profileBox.put('prof_$familyProfileId', {
        'id': familyProfileId,
        'user_id': ownerUserId,
        'owner_user_id': ownerUserId,
        'name': 'Family Child Profile',
        'is_primary': false,
      });

      // Save a hospital under primary profile
      const primaryHosp = HospitalModel(
        id: '',
        profileId: profileId,
        name: 'Primary City Hospital',
        type: 'Hospital',
      );
      final savedPrimary = await hospitalRepo.saveHospitalModel(profileId, primaryHosp);

      // Save a hospital under family profile
      const familyHosp = HospitalModel(
        id: '',
        profileId: familyProfileId,
        name: 'Family Children Clinic',
        type: 'Clinic',
      );
      final savedFamily = await hospitalRepo.saveHospitalModel(familyProfileId, familyHosp);

      // Query primary profile hospitals
      final primaryHospitals = await hospitalRepo.getHospitalModels(profileId);
      expect(primaryHospitals.any((h) => h.id == savedPrimary.id), isTrue);
      expect(primaryHospitals.any((h) => h.id == savedFamily.id), isFalse);

      // Query family profile hospitals
      final familyHospitals = await hospitalRepo.getHospitalModels(familyProfileId);
      expect(familyHospitals.any((h) => h.id == savedFamily.id), isTrue);
      expect(familyHospitals.any((h) => h.id == savedPrimary.id), isFalse);
    });

    test('11. Supabase network failure falls back safely to local Hive cache', () async {
      final isolatedRepo = HospitalRepository(
        hiveService: hiveService,
        supabaseRemoteDataSource: fakeRemoteDataSource,
        connectivityService: fakeConnectivity,
        syncService: syncService,
      );

      // Trigger Supabase network error
      fakeRemoteDataSource.shouldThrowNetworkError = true;

      // 1. pullHospitals under Supabase failure
      await isolatedRepo.pullHospitals(profileId);

      // 2. saveHospitalModel under Supabase failure
      const hosp = HospitalModel(
        id: '',
        profileId: profileId,
        name: 'Fallback Test Hospital',
        type: 'Hospital',
      );
      final saved = await isolatedRepo.saveHospitalModel(profileId, hosp);
      expect(saved.name, equals('Fallback Test Hospital'));
      expect(hiveService.userBox.containsKey(saved.id), isTrue);

      // 3. deleteHospital under Supabase failure
      await isolatedRepo.deleteHospital(profileId, saved.id);
      expect(hiveService.userBox.containsKey(saved.id), isFalse);
    });
  });
}
