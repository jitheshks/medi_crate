import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import 'package:medi_crate/features/vitals/data/models/measurement_model.dart';
import 'package:medi_crate/features/vitals/data/repositories/measurement_repository.dart';

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

class _FakeSupabaseVitalsRemoteDataSource
    extends SupabaseVitalsRemoteDataSource {
  final List<MeasurementModel> remoteMeasurements = [];
  bool shouldThrowNetworkError = false;
  MeasurementModel? lastCreatedMeasurement;
  MeasurementModel? lastUpdatedMeasurement;
  String? lastDeletedMeasurementId;
  int _idCounter = 0;

  @override
  Future<List<MeasurementModel>> fetchMeasurements({
    required String ownerUserId,
    required String profileId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    var list = remoteMeasurements
        .where((m) => IdUtils.matches(m.profileId, profileId))
        .toList();
    if (type != null && type.isNotEmpty) {
      list = list.where((m) => m.type.toLowerCase() == type.toLowerCase()).toList();
    }
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<MeasurementModel?> getMeasurementById({
    required String measurementId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(measurementId);
    try {
      return remoteMeasurements.firstWhere(
        (m) =>
            IdUtils.matches(m.id, cleanId) ||
            (m.clientUuid != null && m.clientUuid == cleanId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MeasurementModel> createMeasurement({
    required MeasurementModel measurement,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedMeasurement = measurement;
    final cleanId = IdUtils.unprefix(measurement.id);
    _idCounter++;
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : 'e0000000-0000-0000-0000-${_idCounter.toString().padLeft(12, '0')}';
    final created = measurement.copyWith(
      id: effectiveId,
      profileId: profileId,
      clientUuid: measurement.clientUuid ?? effectiveId,
    );
    remoteMeasurements.add(created);
    return created;
  }

  @override
  Future<MeasurementModel> updateMeasurement({
    required MeasurementModel measurement,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedMeasurement = measurement;
    final cleanId = IdUtils.unprefix(measurement.id);
    final updated = measurement.copyWith(id: cleanId);
    final index =
        remoteMeasurements.indexWhere((m) => IdUtils.matches(m.id, cleanId));
    if (index >= 0) {
      remoteMeasurements[index] = updated;
    } else {
      remoteMeasurements.add(updated);
    }
    return updated;
  }

  @override
  Future<void> deleteMeasurement({
    required String measurementId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(measurementId);
    lastDeletedMeasurementId = cleanId;
    remoteMeasurements.removeWhere((m) => IdUtils.matches(m.id, cleanId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late SyncService syncService;
  late _FakeConnectivityService connectivityService;
  late _FakeSupabaseVitalsRemoteDataSource fakeSupabaseDataSource;
  late MeasurementRepository repository;

  const testUserId = '00000000-0000-0000-0000-000000000001';
  const testProfileUuid = '11111111-2222-3333-4444-555555555555';
  const foreignProfileUuid = '99999999-8888-7777-6666-555555555555';
  const foreignUserId = '00000000-0000-0000-0000-000000000009';

  final testProfile = ProfileModel(
    profileId: testProfileUuid,
    serverProfileId: 101,
    ownerUserId: testUserId,
    fullName: 'Test Patient',
    relationship: 'Self',
    isPrimary: true,
    allergies: const [],
    chronicConditions: const [],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final foreignProfile = ProfileModel(
    profileId: foreignProfileUuid,
    serverProfileId: 999,
    ownerUserId: foreignUserId,
    fullName: 'Foreign Patient',
    relationship: 'Spouse',
    isPrimary: false,
    allergies: const [],
    chronicConditions: const [],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vitals_repo_supabase_test_');
    Hive.init(tempDir.path);

    for (final boxName in const [
      HiveService.authBoxName,
      HiveService.syncQueueBoxName,
      HiveService.userBoxName,
      HiveService.settingsBoxName,
      HiveService.consentBoxName,
      HiveService.profileBoxName,
    ]) {
      await Hive.openBox<Map>(boxName);
    }

    hiveService = HiveService();
    connectivityService = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: connectivityService,
    );
    fakeSupabaseDataSource = _FakeSupabaseVitalsRemoteDataSource();

    // Verify sync suspension flags are strictly maintained
    expect(SyncService.isRemoteSyncEnabled, isFalse);
    expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

    await hiveService.profileBox.put(testProfile.profileId, testProfile.toMap());
    await hiveService.profileBox.put(
      foreignProfile.profileId,
      foreignProfile.toMap(),
    );

    repository = MeasurementRepository(
      hiveService: hiveService,
      syncService: syncService,
      supabaseRemoteDataSource: fakeSupabaseDataSource,
      connectivityService: connectivityService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MeasurementRepository Supabase Integration Tests (V0–V5)', () {
    test('1. getMeasurementModels returns local Hive cache immediately', () async {
      final localMeasurement = MeasurementModel(
        id: 'measurement_1',
        profileId: testProfileUuid,
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '120 / 80',
        systolic: 120.0,
        diastolic: 80.0,
        unit: 'mmHg',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 8, 0),
      );
      await hiveService.userBox.put('measurement_1', localMeasurement.toMap());

      final results = await repository.getMeasurementModels(testProfileUuid);

      expect(results.length, equals(1));
      expect(results.first.id, equals('measurement_1'));
      expect(results.first.systolic, equals(120.0));
    });

    test('2. pullMeasurements merges Supabase records into Hive cache and triggers onPullMerged', () async {
      bool pullMergedCalled = false;
      final repoWithCallback = MeasurementRepository(
        hiveService: hiveService,
        syncService: syncService,
        supabaseRemoteDataSource: fakeSupabaseDataSource,
        connectivityService: connectivityService,
        onPullMerged: () => pullMergedCalled = true,
      );

      final remoteVital = MeasurementModel(
        id: 'a0000000-0000-0000-0000-000000000001',
        profileId: testProfileUuid,
        type: 'heart_rate',
        title: 'Heart Rate',
        value: '75',
        numericValue: 75.0,
        unit: 'bpm',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 9, 0),
      );
      fakeSupabaseDataSource.remoteMeasurements.add(remoteVital);

      await repoWithCallback.pullMeasurements(
        testProfileUuid,
        explicitOwnerUserId: testUserId,
      );

      expect(pullMergedCalled, isTrue);
      final cached = hiveService.userBox.get('measurement_${remoteVital.id}');
      expect(cached, isNotNull);
      expect(cached!['type'], equals('heart_rate'));
      expect(cached['numeric_value'], equals(75.0));
    });

    test('3. pullMeasurements respects PendingMutationGuard and preserves uncommitted local edits', () async {
      final vitalId = 'b0000000-0000-0000-0000-000000000002';
      final localMeasurement = MeasurementModel(
        id: 'measurement_$vitalId',
        profileId: testProfileUuid,
        type: 'blood_glucose',
        title: 'Blood Glucose',
        value: '110',
        numericValue: 110.0,
        unit: 'mg/dL',
        status: 'NORMAL',
        glucoseContext: 'fasting',
        recordedAt: DateTime.utc(2026, 11, 10, 7, 0),
      );
      await hiveService.userBox.put('measurement_$vitalId', localMeasurement.toMap());

      // Simulate an uncommitted pending update mutation in sync queue
      await syncService.addToQueue(
        SyncQueueItem(
          id: 'sync_vital_pending_1',
          entity: 'measurement',
          operation: 'update',
          payload: localMeasurement.toMap(),
        ),
      );

      // Server has stale value of 140
      final staleServerVital = localMeasurement.copyWith(
        numericValue: 140.0,
        value: '140',
        status: 'ABOVE REFERENCE',
      );
      fakeSupabaseDataSource.remoteMeasurements.add(staleServerVital);

      await repository.pullMeasurements(
        testProfileUuid,
        explicitOwnerUserId: testUserId,
      );

      // Local edit must NOT be overwritten by stale server record
      final cached = hiveService.userBox.get('measurement_$vitalId');
      expect(cached!['numeric_value'], equals(110.0));
      expect(cached['value'], equals('110'));
    });

    test('4. getMeasurementById returns local Hive first, queries Supabase when absent', () async {
      final remoteVital = MeasurementModel(
        id: 'c0000000-0000-0000-0000-000000000003',
        profileId: testProfileUuid,
        type: 'spo2',
        title: 'SpO₂',
        value: '99',
        numericValue: 99.0,
        unit: '%',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 10, 0),
      );
      fakeSupabaseDataSource.remoteMeasurements.add(remoteVital);

      final fetched = await repository.getMeasurementById(
        testProfileUuid,
        remoteVital.id,
        explicitOwnerUserId: testUserId,
      );

      expect(fetched, isNotNull);
      expect(fetched!.numericValue, equals(99.0));
      expect(fetched.type, equals('spo2'));

      // Verify it was cached locally into userBox
      final cached = hiveService.userBox.get('measurement_${remoteVital.id}');
      expect(cached, isNotNull);
    });

    test('5. saveMeasurementModel creates new vital in Supabase, swaps key, and clears sync queue', () async {
      final newMeasurement = MeasurementModel(
        id: '', // New local measurement
        profileId: testProfileUuid,
        type: 'temperature',
        title: 'Temperature',
        value: '37.1',
        numericValue: 37.1,
        unit: '°C',
        status: 'WITHIN REFERENCE',
        recordedAt: DateTime.utc(2026, 11, 10, 11, 0),
      );

      final saved = await repository.saveMeasurementModel(
        newMeasurement,
        explicitOwnerUserId: testUserId,
      );

      expect(UuidUtils.isValidUuid(saved.id), isTrue);
      expect(fakeSupabaseDataSource.remoteMeasurements.length, equals(1));
      expect(fakeSupabaseDataSource.lastCreatedMeasurement, isNotNull);
      expect(fakeSupabaseDataSource.lastCreatedMeasurement!.numericValue, equals(37.1));

      // Key must be saved in userBox with new UUID key
      final cached = hiveService.userBox.get('measurement_${saved.id}');
      expect(cached, isNotNull);
      expect(cached!['numeric_value'], equals(37.1));

      // Queue item must be cleaned up after successful remote synchronization
      expect(hiveService.syncQueueBox.length, equals(0));
    });

    test('6. saveMeasurementModel updates existing vital in Supabase', () async {
      final existingId = 'd0000000-0000-0000-0000-000000000004';
      final existingModel = MeasurementModel(
        id: existingId,
        profileId: testProfileUuid,
        type: 'respiratory_rate',
        title: 'Respiratory Rate',
        value: '18',
        numericValue: 18.0,
        unit: 'br/min',
        status: 'NORMAL',
        notes: 'Initial check',
        recordedAt: DateTime.utc(2026, 11, 10, 12, 0),
      );
      fakeSupabaseDataSource.remoteMeasurements.add(existingModel);
      await hiveService.userBox.put('measurement_$existingId', existingModel.toMap());

      final updatedModel = existingModel.copyWith(
        notes: 'Updated after resting 5 minutes',
        numericValue: 16.0,
        value: '16',
      );

      final result = await repository.saveMeasurementModel(
        updatedModel,
        explicitOwnerUserId: testUserId,
      );

      expect(result.id, equals(existingId));
      expect(result.notes, equals('Updated after resting 5 minutes'));
      expect(fakeSupabaseDataSource.lastUpdatedMeasurement, isNotNull);
      expect(fakeSupabaseDataSource.lastUpdatedMeasurement!.notes, equals('Updated after resting 5 minutes'));

      final cached = hiveService.userBox.get('measurement_$existingId');
      expect(cached!['notes'], equals('Updated after resting 5 minutes'));
    });

    test('7. saveMeasurementModel offline queues mutation when offline without network', () async {
      connectivityService.isOnline = false;

      final vital = MeasurementModel(
        id: '',
        profileId: testProfileUuid,
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '125 / 82',
        systolic: 125.0,
        diastolic: 82.0,
        unit: 'mmHg',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 13, 0),
      );

      final saved = await repository.saveMeasurementModel(
        vital,
        explicitOwnerUserId: testUserId,
      );

      // Model returned with local ID
      expect(saved.id.startsWith('measurement_'), isTrue);
      // Saved in Hive userBox
      expect(hiveService.userBox.containsKey(saved.id), isTrue);
      // Queued in sync queue for later synchronization
      expect(hiveService.syncQueueBox.length, equals(1));
      expect(fakeSupabaseDataSource.remoteMeasurements.isEmpty, isTrue);
    });

    test('8. deleteMeasurement deletes from Hive and Supabase when online', () async {
      final vitalId = 'e0000000-0000-0000-0000-000000000005';
      final model = MeasurementModel(
        id: vitalId,
        profileId: testProfileUuid,
        type: 'spo2',
        title: 'SpO₂',
        value: '97',
        numericValue: 97.0,
        unit: '%',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 14, 0),
      );
      fakeSupabaseDataSource.remoteMeasurements.add(model);
      await hiveService.userBox.put('measurement_$vitalId', model.toMap());

      await repository.deleteMeasurement(
        testProfileUuid,
        vitalId,
        explicitOwnerUserId: testUserId,
      );

      expect(hiveService.userBox.containsKey('measurement_$vitalId'), isFalse);
      expect(fakeSupabaseDataSource.lastDeletedMeasurementId, equals(vitalId));
      expect(fakeSupabaseDataSource.remoteMeasurements.isEmpty, isTrue);
    });

    test('9. deleteMeasurement queues delete mutation when offline', () async {
      connectivityService.isOnline = false;
      final vitalId = 'f0000000-0000-0000-0000-000000000006';
      final model = MeasurementModel(
        id: vitalId,
        profileId: testProfileUuid,
        type: 'heart_rate',
        title: 'Heart Rate',
        value: '68',
        numericValue: 68.0,
        unit: 'bpm',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 15, 0),
      );
      fakeSupabaseDataSource.remoteMeasurements.add(model);
      await hiveService.userBox.put('measurement_$vitalId', model.toMap());

      await repository.deleteMeasurement(
        testProfileUuid,
        vitalId,
        explicitOwnerUserId: testUserId,
      );

      expect(hiveService.userBox.containsKey('measurement_$vitalId'), isFalse);
      expect(hiveService.syncQueueBox.length, equals(1));
      final queued = hiveService.syncQueueBox.values.first;
      expect(queued['operation'], equals('delete'));
    });

    test('10. Strict authenticated session authorization rejects unauthenticated operations', () async {
      // Without authenticated session or explicitOwnerUserId, remote pull must not execute
      await repository.pullMeasurements(testProfileUuid);
      expect(fakeSupabaseDataSource.remoteMeasurements.isEmpty, isTrue);

      final unauthMeasurement = MeasurementModel(
        id: '',
        profileId: testProfileUuid,
        type: 'bmi',
        title: 'BMI',
        value: '22.0',
        numericValue: 22.0,
        unit: 'kg/m²',
        status: 'Normal range',
        recordedAt: DateTime.utc(2026, 11, 10, 16, 0),
      );

      final result = await repository.saveMeasurementModel(unauthMeasurement);
      // Should save locally in Hive, but NOT hit Supabase without an authenticated session
      expect(result.id.startsWith('measurement_'), isTrue);
      expect(fakeSupabaseDataSource.remoteMeasurements.isEmpty, isTrue);
    });

    test('11. Profile UUID validation isolates profiles and rejects foreign profiles', () async {
      final foreignMeasurement = MeasurementModel(
        id: '',
        profileId: foreignProfileUuid, // Belongs to foreignUserId
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '135 / 88',
        systolic: 135.0,
        diastolic: 88.0,
        unit: 'mmHg',
        status: 'HIGH',
        recordedAt: DateTime.utc(2026, 11, 10, 17, 0),
      );

      // Attempting to save foreign profile with testUserId session
      final result = await repository.saveMeasurementModel(
        foreignMeasurement,
        explicitOwnerUserId: testUserId, // Mismatched user session
      );

      // Must be rejected by _resolveProfileUuid and not sent to Supabase
      expect(result.id.startsWith('measurement_'), isTrue);
      expect(fakeSupabaseDataSource.remoteMeasurements.isEmpty, isTrue);
    });

    test('12. Supabase failure NEVER falls back to legacy Laravel remote data source', () async {
      fakeSupabaseDataSource.shouldThrowNetworkError = true;

      final vital = MeasurementModel(
        id: '',
        profileId: testProfileUuid,
        type: 'blood_glucose',
        title: 'Blood Glucose',
        value: '100',
        numericValue: 100.0,
        unit: 'mg/dL',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 18, 0),
      );

      await repository.saveMeasurementModel(
        vital,
        explicitOwnerUserId: testUserId,
      );

      // Legacy Laravel data source must NOT be called
    });

    test('13. Historical vital measurements preservation (multiple measurements across dates are preserved)', () async {
      // Vital records across consecutive days for same vital type (Blood Pressure)
      final day1 = MeasurementModel(
        id: '10000000-0000-0000-0000-000000000001',
        profileId: testProfileUuid,
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '120 / 80',
        systolic: 120.0,
        diastolic: 80.0,
        unit: 'mmHg',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 8, 8, 0),
      );
      final day2 = MeasurementModel(
        id: '10000000-0000-0000-0000-000000000002',
        profileId: testProfileUuid,
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '124 / 82',
        systolic: 124.0,
        diastolic: 82.0,
        unit: 'mmHg',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 9, 8, 0),
      );
      final day3 = MeasurementModel(
        id: '10000000-0000-0000-0000-000000000003',
        profileId: testProfileUuid,
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '128 / 84',
        systolic: 128.0,
        diastolic: 84.0,
        unit: 'mmHg',
        status: 'NORMAL',
        recordedAt: DateTime.utc(2026, 11, 10, 8, 0),
      );

      fakeSupabaseDataSource.remoteMeasurements.addAll([day1, day2, day3]);

      await repository.pullMeasurements(
        testProfileUuid,
        explicitOwnerUserId: testUserId,
      );

      final allModels = await repository.getMeasurementModels(testProfileUuid);

      // All 3 historical records must exist, sorted chronologically descending
      expect(allModels.length, equals(3));
      expect(allModels[0].id, equals('measurement_${day3.id}'));
      expect(allModels[1].id, equals('measurement_${day2.id}'));
      expect(allModels[2].id, equals('measurement_${day1.id}'));
      expect(allModels[0].systolic, equals(128.0));
      expect(allModels[1].systolic, equals(124.0));
      expect(allModels[2].systolic, equals(120.0));
    });
  });
}
