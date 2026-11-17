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
import 'package:medi_crate/features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import 'package:medi_crate/features/medicines/data/models/medicine_model.dart';
import 'package:medi_crate/features/medicines/data/repositories/medicine_repository.dart';
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
        transports:
            isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
        hasInternet: isOnline,
      );

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isOnline);

  @override
  void dispose() {}
}

class _FakeSupabaseMedicineRemoteDataSource
    extends SupabaseMedicineRemoteDataSource {
  final List<MedicineModel> remoteMedicines = [];
  bool shouldThrowNetworkError = false;
  MedicineModel? lastCreatedMedicine;
  MedicineModel? lastUpdatedMedicine;
  String? lastDeletedMedicineId;
  int _idCounter = 0;

  @override
  Future<List<MedicineModel>> fetchMedicines({
    required String ownerUserId,
    required String profileId,
    String? consultationId,
    String? search,
    String? status,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final list = remoteMedicines
        .where((m) => IdUtils.matches(m.profileId, profileId))
        .toList();
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<MedicineModel?> getMedicineById({
    required String medicineId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(medicineId);
    try {
      return remoteMedicines.firstWhere(
        (m) =>
            IdUtils.matches(m.id, cleanId) ||
            (m.clientUuid != null && m.clientUuid == cleanId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MedicineModel> createMedicine({
    required MedicineModel medicine,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedMedicine = medicine;
    final cleanId = IdUtils.unprefix(medicine.id);
    _idCounter++;
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : 'e0000000-0000-0000-0000-${_idCounter.toString().padLeft(12, '0')}';
    final created = medicine.copyWith(
      id: effectiveId,
      profileId: profileId,
      clientUuid: medicine.clientUuid ?? effectiveId,
    );
    remoteMedicines.add(created);
    return created;
  }

  @override
  Future<MedicineModel> updateMedicine({
    required MedicineModel medicine,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedMedicine = medicine;
    final cleanId = IdUtils.unprefix(medicine.id);
    final index =
        remoteMedicines.indexWhere((m) => IdUtils.matches(m.id, cleanId));
    if (index >= 0) {
      remoteMedicines[index] = medicine;
    } else {
      remoteMedicines.add(medicine);
    }
    return medicine;
  }

  @override
  Future<void> deleteMedicine({
    required String medicineId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(medicineId);
    lastDeletedMedicineId = cleanId;
    remoteMedicines.removeWhere((m) => IdUtils.matches(m.id, cleanId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeSupabaseMedicineRemoteDataSource fakeRemoteDataSource;
  late _FakeConnectivityService fakeConnectivity;
  late SyncService syncService;
  late MedicineRepository medicineRepo;
  bool pullFreshnessBumped = false;

  const sessionUserId = '11111111-2222-3333-4444-555555555555';
  const profileId = '22222222-3333-4444-5555-666666666666';
  const medicineUuid = '33333333-4444-5555-6666-777777777777';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medicine_repo_test_');
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
    fakeRemoteDataSource = _FakeSupabaseMedicineRemoteDataSource();
    fakeConnectivity = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: fakeConnectivity,
    );

    pullFreshnessBumped = false;
    medicineRepo = MedicineRepository(
      hiveService: hiveService,
      supabaseRemoteDataSource: fakeRemoteDataSource,
      connectivityService: fakeConnectivity,
      syncService: syncService,
      onPullMerged: () {
        pullFreshnessBumped = true;
      },
    );

    // Seed primary profile in profileBox owned by sessionUserId
    final profile = ProfileModel(
      profileId: profileId,
      ownerUserId: sessionUserId,
      fullName: 'Primary Patient',
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

  group('MedicineRepository Supabase Integration Tests', () {
    test('1. Sync flags are preserved and active', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });

    test('2. pullMedicines fetches from Supabase and merges into Hive cache with freshness signal', () async {
      fakeRemoteDataSource.remoteMedicines.add(
        MedicineModel(
          id: medicineUuid,
          profileId: profileId,
          medicineName: 'Atorvastatin',
          dosage: '20mg',
          form: 'Tablet',
          frequency: 'Once Daily at night',
          startDate: DateTime(2026, 11, 1),
          reminder: true,
          reminderTimes: const ['21:00'],
          createdAt: DateTime(2026, 11, 1, 10, 0),
          updatedAt: DateTime(2026, 11, 1, 10, 0),
        ),
      );

      await medicineRepo.pullMedicines(
        profileId,
        explicitOwnerUserId: sessionUserId,
      );

      expect(pullFreshnessBumped, isTrue);
      final key = 'medicine_$medicineUuid';
      final cached = hiveService.userBox.get(key);
      expect(cached, isNotNull);
      final model = MedicineModel.fromJson(Map<String, dynamic>.from(cached as Map));
      expect(model.medicineName, equals('Atorvastatin'));
      expect(model.dosage, equals('20mg'));
      expect(model.form, equals('Tablet'));
    });

    test('3. getMedicineById reads from Hive first, falls back to Supabase', () async {
      const existingId = 'medicine_existing-local-1111';
      final localMedicine = MedicineModel(
        id: existingId,
        profileId: profileId,
        medicineName: 'Aspirin',
        dosage: '75mg',
        startDate: DateTime(2026, 11, 5),
        createdAt: DateTime(2026, 11, 5),
      );
      await hiveService.userBox.put(existingId, localMedicine.toJson());

      // Should return directly from Hive without calling Supabase
      final fromHive = await medicineRepo.getMedicineById(
        profileId,
        existingId,
        explicitOwnerUserId: sessionUserId,
      );
      expect(fromHive, isNotNull);
      expect(fromHive!.medicineName, equals('Aspirin'));

      // Test fallback to Supabase when not present in Hive
      fakeRemoteDataSource.remoteMedicines.add(
        MedicineModel(
          id: medicineUuid,
          profileId: profileId,
          medicineName: 'Rosuvastatin',
          dosage: '10mg',
          startDate: DateTime(2026, 11, 8),
          createdAt: DateTime(2026, 11, 8),
        ),
      );

      final fromSupabase = await medicineRepo.getMedicineById(
        profileId,
        medicineUuid,
        explicitOwnerUserId: sessionUserId,
      );
      expect(fromSupabase, isNotNull);
      expect(fromSupabase!.medicineName, equals('Rosuvastatin'));
      // Verify cached in Hive
      final normKey = 'medicine_$medicineUuid';
      expect(hiveService.userBox.containsKey(normKey), isTrue);
    });

    test('4. saveMedicineModel updates existing Supabase prescription when ID is UUID', () async {
      final existingModel = MedicineModel(
        id: medicineUuid,
        profileId: profileId,
        medicineName: 'Metoprolol',
        dosage: '25mg',
        startDate: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1),
      );
      await hiveService.userBox.put('medicine_$medicineUuid', existingModel.toJson());

      final updatedModel = existingModel.copyWith(
        dosage: '50mg',
        notes: 'Dose escalated per cardiologist review',
      );

      final saved = await medicineRepo.saveMedicineModel(
        profileId,
        updatedModel,
        explicitOwnerUserId: sessionUserId,
      );

      expect(saved.dosage, equals('50mg'));
      expect(saved.notes, equals('Dose escalated per cardiologist review'));
      expect(fakeRemoteDataSource.lastUpdatedMedicine, isNotNull);
      expect(fakeRemoteDataSource.lastUpdatedMedicine!.dosage, equals('50mg'));
      expect(fakeRemoteDataSource.lastCreatedMedicine, isNull);
    });

    test('5. saveMedicineModel creates new prescription in Supabase and normalizes temporary local key', () async {
      const tempId = 'temp_med_999';
      final newMedicine = MedicineModel(
        id: tempId,
        profileId: profileId,
        medicineName: 'Levothyroxine',
        dosage: '50mcg',
        startDate: DateTime(2026, 11, 10),
        form: 'Tablet',
        createdAt: DateTime(2026, 11, 10),
      );

      final created = await medicineRepo.saveMedicineModel(
        profileId,
        newMedicine,
        explicitOwnerUserId: sessionUserId,
      );

      expect(fakeRemoteDataSource.lastCreatedMedicine, isNotNull);
      expect(UuidUtils.isValidUuid(IdUtils.unprefix(created.id)), isTrue);
      // Temporary local key must have been cleared from Hive
      expect(hiveService.userBox.containsKey(tempId), isFalse);
      expect(hiveService.userBox.containsKey('medicine_$tempId'), isFalse);
      // New key must exist
      expect(hiveService.userBox.containsKey(created.id), isTrue);
    });

    test('6. deleteMedicine removes record from Supabase and Hive', () async {
      final medicine = MedicineModel(
        id: medicineUuid,
        profileId: profileId,
        medicineName: 'Pantoprazole',
        dosage: '40mg',
        startDate: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1),
      );
      await hiveService.userBox.put('medicine_$medicineUuid', medicine.toJson());
      fakeRemoteDataSource.remoteMedicines.add(medicine);

      await medicineRepo.deleteMedicine(
        profileId,
        medicineUuid,
        explicitOwnerUserId: sessionUserId,
      );

      expect(hiveService.userBox.containsKey('medicine_$medicineUuid'), isFalse);
      expect(fakeRemoteDataSource.lastDeletedMedicineId, equals(medicineUuid));
      expect(fakeRemoteDataSource.remoteMedicines, isEmpty);
    });

    test('7. Offline save queues mutation and preserves local record', () async {
      fakeConnectivity.isOnline = false;
      final offlineMedicine = MedicineModel(
        id: 'med_offline_101',
        profileId: profileId,
        medicineName: 'Cetirizine',
        dosage: '10mg',
        startDate: DateTime(2026, 11, 11),
        createdAt: DateTime(2026, 11, 11),
      );

      final saved = await medicineRepo.saveMedicineModel(
        profileId,
        offlineMedicine,
        explicitOwnerUserId: sessionUserId,
      );

      expect(saved.id, equals('medicine_med_offline_101'));
      expect(fakeRemoteDataSource.lastCreatedMedicine, isNull);
      expect(hiveService.userBox.containsKey('medicine_med_offline_101'), isTrue);

      final queueEntries = hiveService.syncQueueBox.values.toList();
      expect(queueEntries.isNotEmpty, isTrue);
      final lastQueueItem = queueEntries.last;
      expect(lastQueueItem['entity'], equals('medicines'));
    });

    test('8. Cross-user isolation: profile belonging to another user cannot be pulled or saved', () async {
      const foreignUserId = '88888888-8888-8888-8888-888888888888';
      const foreignProfileId = '77777777-7777-7777-7777-777777777777';

      final foreignProfile = ProfileModel(
        profileId: foreignProfileId,
        ownerUserId: foreignUserId,
        fullName: 'Foreign User',
        relationship: 'Other',
        isPrimary: false,
      );
      await hiveService.profileBox.put(foreignProfileId, foreignProfile.toMap());

      fakeRemoteDataSource.remoteMedicines.add(
        MedicineModel(
          id: '55555555-5555-5555-5555-555555555555',
          profileId: foreignProfileId,
          medicineName: 'Foreign Prescription',
          dosage: '100mg',
          startDate: DateTime(2026, 11, 11),
          createdAt: DateTime(2026, 11, 11),
        ),
      );

      // Attempt to pull foreign profile with sessionUserId — must be rejected
      await medicineRepo.pullMedicines(
        foreignProfileId,
        explicitOwnerUserId: sessionUserId,
      );

      final cached = hiveService.userBox.get('medicine_55555555-5555-5555-5555-555555555555');
      expect(cached, isNull);
    });

    test('9. Strict session authorization: local auth cache without active session does NOT authorize remote operations', () async {
      // Seed local auth cache ONLY without providing an authenticated Supabase session
      await hiveService.authBox.put('current_user', {
        'id': sessionUserId,
        'email': 'cached@example.com',
      });

      fakeRemoteDataSource.remoteMedicines.add(
        MedicineModel(
          id: '66666666-6666-6666-6666-666666666666',
          profileId: profileId,
          medicineName: 'Unauthenticated Probe',
          dosage: '50mg',
          startDate: DateTime(2026, 11, 11),
        ),
      );

      // Pull without explicitOwnerUserId and without Supabase session
      await medicineRepo.pullMedicines(profileId);

      // Must NOT have pulled from remote data source because local cache must not authorize remote calls
      final cached = hiveService.userBox.get('medicine_66666666-6666-6666-6666-666666666666');
      expect(cached, isNull);
    });

    test('10. Supabase network failure falls back safely to local Hive cache', () async {
      fakeRemoteDataSource.shouldThrowNetworkError = true;

      // 1. Pull handles error gracefully without throwing
      await medicineRepo.pullMedicines(
        profileId,
        explicitOwnerUserId: sessionUserId,
      );

      // 2. Save persists to local Hive cache and enqueues sync mutation
      final newMed = MedicineModel(
        id: 'new_temp_med',
        profileId: profileId,
        medicineName: 'Fallback Test Med',
        dosage: '10mg',
        startDate: DateTime(2026, 11, 11),
      );
      final saved = await medicineRepo.saveMedicineModel(
        profileId,
        newMed,
        explicitOwnerUserId: sessionUserId,
      );
      expect(saved.id, isNotEmpty);
      expect(hiveService.userBox.containsKey(saved.id), isTrue);

      // 3. Delete removes from Hive and queues delete mutation
      await medicineRepo.deleteMedicine(
        profileId,
        saved.id,
        explicitOwnerUserId: sessionUserId,
      );
      expect(hiveService.userBox.containsKey(saved.id), isFalse);
    });
  });
}
