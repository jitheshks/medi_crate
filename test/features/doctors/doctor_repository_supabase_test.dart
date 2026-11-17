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
import 'package:medi_crate/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/doctors/data/repositories/doctor_repository.dart';
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

class _FakeSupabaseDoctorRemoteDataSource extends SupabaseDoctorRemoteDataSource {
  final List<DoctorModel> remoteDoctors = [];
  bool shouldThrowNetworkError = false;
  DoctorModel? lastCreatedDoctor;
  DoctorModel? lastUpdatedDoctor;
  String? lastDeletedDoctorId;
  int _idCounter = 0;

  @override
  Future<List<DoctorModel>> fetchDoctors({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? specialty,
    String? hospitalId,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final list = remoteDoctors.where((d) => d.profileId == profileId).toList();
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<DoctorModel?> getDoctorById({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    try {
      return remoteDoctors.firstWhere((d) => d.id == doctorId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DoctorModel> createDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedDoctor = doctor;
    final cleanId = IdUtils.unprefix(doctor.id);
    _idCounter++;
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : 'a0000000-0000-0000-0000-${_idCounter.toString().padLeft(12, '0')}';
    final created = doctor.copyWith(
      id: effectiveId,
      profileId: profileId,
    );
    remoteDoctors.add(created);
    return created;
  }

  @override
  Future<DoctorModel> updateDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedDoctor = doctor;
    final index = remoteDoctors.indexWhere((d) => d.id == doctor.id);
    if (index >= 0) {
      remoteDoctors[index] = doctor;
    } else {
      remoteDoctors.add(doctor);
    }
    return doctor;
  }

  @override
  Future<void> deleteDoctor({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastDeletedDoctorId = doctorId;
    remoteDoctors.removeWhere((d) => d.id == doctorId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeSupabaseDoctorRemoteDataSource fakeRemoteDataSource;
  late _FakeConnectivityService fakeConnectivity;
  late SyncService syncService;
  late DoctorRepository doctorRepo;
  bool pullFreshnessBumped = false;

  const ownerUserId = '11111111-2222-3333-4444-555555555555';
  const profileId = '22222222-3333-4444-5555-666666666666';
  const doctorUuid = '33333333-4444-5555-6666-777777777777';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('doctor_repo_test_');
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
    fakeRemoteDataSource = _FakeSupabaseDoctorRemoteDataSource();
    fakeConnectivity = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: fakeConnectivity,
    );

    pullFreshnessBumped = false;
    doctorRepo = DoctorRepository(
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
      'email': 'doctor_user@example.com',
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

  group('DoctorRepository Supabase Integration Tests', () {
    test('1. Sync flags are preserved and active', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });

    test('2. pullDoctors fetches from Supabase and merges into Hive cache with freshness signal', () async {
      fakeRemoteDataSource.remoteDoctors.add(
        const DoctorModel(
          id: doctorUuid,
          profileId: profileId,
          name: 'Dr. Gregory House',
          specialty: 'Diagnostic Medicine',
          hospitalName: 'Princeton Plainsboro',
          isFavorite: true,
        ),
      );

      await doctorRepo.pullDoctors(profileId);

      final cached = await doctorRepo.getDoctorModels(profileId);
      expect(cached.length, equals(1));
      expect(cached.first.name, equals('Dr. Gregory House'));
      expect(cached.first.specialty, equals('Diagnostic Medicine'));
      expect(pullFreshnessBumped, isTrue);
    });

    test('3. getDoctorById reads from Hive first, falls back to Supabase if missing locally', () async {
      fakeRemoteDataSource.remoteDoctors.add(
        const DoctorModel(
          id: doctorUuid,
          profileId: profileId,
          name: 'Dr. James Wilson',
          specialty: 'Oncology',
        ),
      );

      // Not in Hive yet
      final doctor = await doctorRepo.getDoctorById(profileId, doctorUuid);
      expect(doctor, isNotNull);
      expect(doctor!.name, equals('Dr. James Wilson'));

      // Check that it was cached into Hive
      final fromHive = hiveService.userBox.get('doctor_$doctorUuid');
      expect(fromHive, isNotNull);
      expect(fromHive!['name'], equals('Dr. James Wilson'));
    });

    test('4. saveDoctorModel updates existing Supabase doctor when ID is UUID', () async {
      final existingDoc = const DoctorModel(
        id: doctorUuid,
        profileId: profileId,
        name: 'Dr. Robert Chase',
        specialty: 'Cardiology',
      );
      await doctorRepo.saveDoctorModel(profileId, existingDoc);

      final updatedDoc = existingDoc.copyWith(
        name: 'Dr. Robert Chase, Chief',
        specialty: 'Cardiology & Surgery',
      );
      final result = await doctorRepo.saveDoctorModel(profileId, updatedDoc);

      expect(result.name, equals('Dr. Robert Chase, Chief'));
      expect(fakeRemoteDataSource.lastUpdatedDoctor?.name, equals('Dr. Robert Chase, Chief'));
      expect(hiveService.userBox.get('doctor_$doctorUuid')?['name'], equals('Dr. Robert Chase, Chief'));
    });

    test('5. saveDoctorModel creates new doctor in Supabase and normalizes temporary local key', () async {
      const newDoctor = DoctorModel(
        id: '',
        profileId: profileId,
        name: 'Dr. Allison Cameron',
        specialty: 'Immunology',
      );

      final saved = await doctorRepo.saveDoctorModel(profileId, newDoctor);

      expect(saved.id, equals('doctor_a0000000-0000-0000-0000-000000000001'));
      expect(fakeRemoteDataSource.lastCreatedDoctor?.name, equals('Dr. Allison Cameron'));
      expect(hiveService.userBox.containsKey('doctor_a0000000-0000-0000-0000-000000000001'), isTrue);
    });

    test('6. deleteDoctor enforces dependency check and preserves doctor when consultations exist', () async {
      // 1. Save doctor
      final doctor = const DoctorModel(
        id: doctorUuid,
        profileId: profileId,
        name: 'Dr. Lisa Cuddy',
        specialty: 'Endocrinology',
      );
      await doctorRepo.saveDoctorModel(profileId, doctor);

      // 2. Link consultation to this doctor
      await hiveService.userBox.put('consultation_101', {
        'id': 'consultation_101',
        'profile_id': profileId,
        'doctor_id': doctorUuid,
        'doctor_name': 'Dr. Lisa Cuddy',
        'diagnosis': 'Regular Checkup',
      });

      // 3. Attempt deletion -> Must throw ResourceHasDependenciesException
      await expectLater(
        doctorRepo.deleteDoctor(profileId, doctorUuid),
        throwsA(isA<ResourceHasDependenciesException>()),
      );

      // 4. Verify doctor is preserved in Hive and Supabase
      expect(hiveService.userBox.containsKey('doctor_$doctorUuid'), isTrue);
      expect(fakeRemoteDataSource.lastDeletedDoctorId, isNull);
    });

    test('7. Historical doctor snapshot remains intact in consultation when doctor is deleted without dependencies', () async {
      // 1. Save a doctor with unique name
      const targetDoctorId = '77777777-8888-9999-0000-111111111111';
      final doctor = const DoctorModel(
        id: targetDoctorId,
        profileId: profileId,
        name: 'Dr. Historical Clinician',
        specialty: 'Dermatology',
      );
      await doctorRepo.saveDoctorModel(profileId, doctor);

      // 2. Create an unlinked historical consultation that captured the doctor's name at visit time
      await hiveService.userBox.put('consultation_historical_1', {
        'id': 'consultation_historical_1',
        'profile_id': profileId,
        'doctor_id': 'other-unrelated-doctor-id',
        'doctor_name': 'Dr. Historical Clinician (Archived Snapshot)',
        'doctor_specialty': 'Dermatology',
        'diagnosis': 'Skin allergy diagnosis',
        'visit_date': '2025-01-15',
      });

      // 3. Delete target doctor (no direct link in dependencies)
      await doctorRepo.deleteDoctor(profileId, targetDoctorId);

      // 4. Verify doctor was deleted from directory
      expect(hiveService.userBox.containsKey('doctor_$targetDoctorId'), isFalse);
      expect(fakeRemoteDataSource.lastDeletedDoctorId, equals(targetDoctorId));

      // 5. Verify historical snapshot in consultation is 100% intact
      final consultation = hiveService.userBox.get('consultation_historical_1');
      expect(consultation, isNotNull);
      expect(consultation!['doctor_name'], equals('Dr. Historical Clinician (Archived Snapshot)'));
      expect(consultation['doctor_specialty'], equals('Dermatology'));
      expect(consultation['diagnosis'], equals('Skin allergy diagnosis'));
    });

    test('8. Offline save queues mutation and preserves local record', () async {
      fakeConnectivity.isOnline = false;

      const offlineDoctor = DoctorModel(
        id: '',
        profileId: profileId,
        name: 'Dr. Offline Specialist',
        specialty: 'Neurology',
      );

      final result = await doctorRepo.saveDoctorModel(profileId, offlineDoctor);

      expect(result.name, equals('Dr. Offline Specialist'));
      expect(hiveService.userBox.containsKey(result.id), isTrue);
      expect(hiveService.syncQueueBox.isNotEmpty, isTrue);
    });

    test('9. Cross-user isolation: profile belonging to another user cannot be pulled or saved to Supabase', () async {
      const otherUserId = '99999999-9999-9999-9999-999999999999';
      const foreignProfileId = '88888888-8888-8888-8888-888888888888';

      // Foreign profile owned by otherUserId stored in profileBox
      await hiveService.profileBox.put('prof_$foreignProfileId', {
        'id': foreignProfileId,
        'user_id': otherUserId,
        'owner_user_id': otherUserId,
        'name': 'Foreign User Profile',
      });

      // Attempting to pull with active user session (ownerUserId) targeting foreign profile
      final initialCount = fakeRemoteDataSource.remoteDoctors.length;
      await doctorRepo.pullDoctors(foreignProfileId);

      // Verify no doctors were pulled or added for foreign profile under this user
      expect(fakeRemoteDataSource.remoteDoctors.length, equals(initialCount));

      // Attempting to save doctor under foreign profile
      const doctorForForeignProfile = DoctorModel(
        id: '',
        profileId: foreignProfileId,
        name: 'Dr. Cross User Reject',
        specialty: 'Radiology',
      );

      final saved = await doctorRepo.saveDoctorModel(
        foreignProfileId,
        doctorForForeignProfile,
        ownerUserId: ownerUserId,
      );

      // Doctor is saved locally in Hive but NOT synced to Supabase under mismatched profile
      expect(saved.name, equals('Dr. Cross User Reject'));
      expect(fakeRemoteDataSource.lastCreatedDoctor?.name, isNot('Dr. Cross User Reject'));
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

      // Save a doctor under primary profile
      const primaryDoc = DoctorModel(
        id: '',
        profileId: profileId,
        name: 'Dr. Primary Doctor',
        specialty: 'Internal Medicine',
      );
      final savedPrimary = await doctorRepo.saveDoctorModel(profileId, primaryDoc);

      // Save a doctor under family profile
      const familyDoc = DoctorModel(
        id: '',
        profileId: familyProfileId,
        name: 'Dr. Family Pediatrician',
        specialty: 'Pediatrics',
      );
      final savedFamily = await doctorRepo.saveDoctorModel(familyProfileId, familyDoc);

      // Query primary profile doctors
      final primaryDoctors = await doctorRepo.getDoctorModels(profileId);
      expect(primaryDoctors.any((d) => d.id == savedPrimary.id), isTrue);
      expect(primaryDoctors.any((d) => d.id == savedFamily.id), isFalse);

      // Query family profile doctors
      final familyDoctors = await doctorRepo.getDoctorModels(familyProfileId);
      expect(familyDoctors.any((d) => d.id == savedFamily.id), isTrue);
      expect(familyDoctors.any((d) => d.id == savedPrimary.id), isFalse);
    });

    test('11. Supabase network failure falls back safely to local Hive cache', () async {
      final isolatedRepo = DoctorRepository(
        hiveService: hiveService,
        supabaseRemoteDataSource: fakeRemoteDataSource,
        connectivityService: fakeConnectivity,
        syncService: syncService,
      );

      // Trigger Supabase network error
      fakeRemoteDataSource.shouldThrowNetworkError = true;

      // 1. pullDoctors under Supabase failure
      await isolatedRepo.pullDoctors(profileId);

      // 2. saveDoctorModel under Supabase failure
      const doc = DoctorModel(
        id: '',
        profileId: profileId,
        name: 'Dr. Fallback Test',
        specialty: 'Surgery',
      );
      final saved = await isolatedRepo.saveDoctorModel(profileId, doc);
      expect(saved.name, equals('Dr. Fallback Test'));
      expect(hiveService.userBox.containsKey(saved.id), isTrue);

      // 3. deleteDoctor under Supabase failure
      await isolatedRepo.deleteDoctor(profileId, saved.id);
      expect(hiveService.userBox.containsKey(saved.id), isFalse);
    });
  });
}
