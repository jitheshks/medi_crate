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
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
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

class _FakeSupabaseConsultationRemoteDataSource
    extends SupabaseConsultationRemoteDataSource {
  final List<ConsultationModel> remoteConsultations = [];
  bool shouldThrowNetworkError = false;
  ConsultationModel? lastCreatedConsultation;
  ConsultationModel? lastUpdatedConsultation;
  String? lastDeletedConsultationId;
  int _idCounter = 0;

  @override
  Future<List<ConsultationModel>> fetchConsultations({
    required String ownerUserId,
    required String profileId,
    String? doctorId,
    String? hospitalId,
    String? search,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final list = remoteConsultations
        .where((c) => IdUtils.matches(c.profileId, profileId))
        .toList();
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<ConsultationModel?> getConsultationById({
    required String consultationId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(consultationId);
    try {
      return remoteConsultations.firstWhere(
        (c) =>
            IdUtils.matches(c.id, cleanId) ||
            (c.clientUuid != null && c.clientUuid == cleanId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ConsultationModel> createConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedConsultation = consultation;
    final cleanId = IdUtils.unprefix(consultation.id);
    _idCounter++;
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : 'c0000000-0000-0000-0000-${_idCounter.toString().padLeft(12, '0')}';
    final created = consultation.copyWith(
      id: effectiveId,
      profileId: profileId,
      clientUuid: consultation.clientUuid ?? effectiveId,
    );
    remoteConsultations.add(created);
    return created;
  }

  @override
  Future<ConsultationModel> updateConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedConsultation = consultation;
    final cleanId = IdUtils.unprefix(consultation.id);
    final index = remoteConsultations
        .indexWhere((c) => IdUtils.matches(c.id, cleanId));
    if (index >= 0) {
      remoteConsultations[index] = consultation;
    } else {
      remoteConsultations.add(consultation);
    }
    return consultation;
  }

  @override
  Future<void> deleteConsultation({
    required String consultationId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(consultationId);
    lastDeletedConsultationId = cleanId;
    remoteConsultations.removeWhere((c) => IdUtils.matches(c.id, cleanId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeSupabaseConsultationRemoteDataSource fakeRemoteDataSource;
  late _FakeConnectivityService fakeConnectivity;
  late SyncService syncService;
  late ConsultationRepository consultationRepo;
  bool pullFreshnessBumped = false;

  const ownerUserId = '11111111-2222-3333-4444-555555555555';
  const profileId = '22222222-3333-4444-5555-666666666666';
  const consultationUuid = '33333333-4444-5555-6666-777777777777';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('consultation_repo_test_');
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
    fakeRemoteDataSource = _FakeSupabaseConsultationRemoteDataSource();
    fakeConnectivity = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: fakeConnectivity,
    );

    pullFreshnessBumped = false;
    consultationRepo = ConsultationRepository(
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
      'email': 'primary@example.com',
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

  group('ConsultationRepository Supabase Integration Tests', () {
    test('1. Sync flags are preserved and active', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });

    test('2. pullConsultations fetches from Supabase and merges into Hive cache with freshness signal', () async {
      fakeRemoteDataSource.remoteConsultations.add(
        ConsultationModel(
          id: consultationUuid,
          profileId: profileId,
          doctorName: 'Dr. Gregory House',
          hospitalName: 'Princeton Plainsboro',
          visitDate: DateTime(2026, 11, 10),
          chiefComplaint: 'Severe headache and fever',
          diagnosis: 'Viral meningitis',
          clinicalNotes: 'Hydration and close monitoring',
          createdAt: DateTime(2026, 11, 10, 10, 0),
        ),
      );

      await consultationRepo.pullConsultations(profileId);

      expect(pullFreshnessBumped, isTrue);
      final key = 'consultation_$consultationUuid';
      final cached = hiveService.userBox.get(key);
      expect(cached, isNotNull);
      final model = ConsultationModel.fromJson(Map<String, dynamic>.from(cached as Map));
      expect(model.doctorName, equals('Dr. Gregory House'));
      expect(model.chiefComplaint, equals('Severe headache and fever'));
      expect(model.diagnosis, equals('Viral meningitis'));
    });

    test('3. getConsultationById reads from Hive first, falls back to Supabase', () async {
      const existingId = 'consultation_existing-local-1111';
      final localConsultation = ConsultationModel(
        id: existingId,
        profileId: profileId,
        doctorName: 'Dr. Local Medic',
        visitDate: DateTime(2026, 11, 9),
        chiefComplaint: 'Routine checkup',
        diagnosis: 'Healthy',
        createdAt: DateTime(2026, 11, 9, 9, 0),
      );
      await hiveService.userBox.put(existingId, localConsultation.toJson());

      // Should return directly from Hive without calling Supabase
      final fromHive = await consultationRepo.getConsultationById(profileId, existingId);
      expect(fromHive, isNotNull);
      expect(fromHive!.doctorName, equals('Dr. Local Medic'));

      // Test fallback to Supabase when not present in Hive
      fakeRemoteDataSource.remoteConsultations.add(
        ConsultationModel(
          id: consultationUuid,
          profileId: profileId,
          doctorName: 'Dr. Remote Specialist',
          visitDate: DateTime(2026, 11, 8),
          chiefComplaint: 'Persistent cough',
          diagnosis: 'Acute bronchitis',
          createdAt: DateTime(2026, 11, 8, 8, 0),
        ),
      );

      final fromSupabase = await consultationRepo.getConsultationById(profileId, consultationUuid);
      expect(fromSupabase, isNotNull);
      expect(fromSupabase!.doctorName, equals('Dr. Remote Specialist'));
      // Verify it was cached in Hive
      final normKey = 'consultation_$consultationUuid';
      expect(hiveService.userBox.containsKey(normKey), isTrue);
    });

    test('4. saveConsultationModel updates existing Supabase consultation when ID is UUID', () async {
      final existingModel = ConsultationModel(
        id: consultationUuid,
        profileId: profileId,
        doctorName: 'Dr. Gregory House',
        visitDate: DateTime(2026, 11, 10),
        chiefComplaint: 'Severe headache',
        diagnosis: 'Migraine',
        createdAt: DateTime(2026, 11, 10, 10, 0),
      );
      await hiveService.userBox.put('consultation_$consultationUuid', existingModel.toJson());

      final updatedModel = existingModel.copyWith(
        diagnosis: 'Tension headache confirmed',
      );

      final saved = await consultationRepo.saveConsultationModel(profileId, updatedModel);

      expect(saved.diagnosis, equals('Tension headache confirmed'));
      expect(fakeRemoteDataSource.lastUpdatedConsultation, isNotNull);
      expect(fakeRemoteDataSource.lastUpdatedConsultation!.diagnosis, equals('Tension headache confirmed'));
      expect(fakeRemoteDataSource.lastCreatedConsultation, isNull);
    });

    test('5. saveConsultationModel creates new consultation in Supabase and normalizes temporary local key', () async {
      const tempId = 'temp_con_999';
      final newConsultation = ConsultationModel(
        id: tempId,
        profileId: profileId,
        doctorName: 'Dr. Allison Cameron',
        visitDate: DateTime(2026, 11, 11),
        chiefComplaint: 'Joint stiffness',
        diagnosis: 'Early rheumatoid arthritis',
        createdAt: DateTime(2026, 11, 11, 11, 0),
      );

      final created = await consultationRepo.saveConsultationModel(profileId, newConsultation);

      expect(fakeRemoteDataSource.lastCreatedConsultation, isNotNull);
      expect(UuidUtils.isValidUuid(IdUtils.unprefix(created.id)), isTrue);
      // Temporary local key must have been cleared from Hive
      expect(hiveService.userBox.containsKey(tempId), isFalse);
      expect(hiveService.userBox.containsKey('consultation_$tempId'), isFalse);
      // New key must exist
      expect(hiveService.userBox.containsKey(created.id), isTrue);
    });

    test('6. deleteConsultation enforces dependency check (medicines, reports) before deletion', () async {
      final consultation = ConsultationModel(
        id: consultationUuid,
        profileId: profileId,
        doctorName: 'Dr. Robert Chase',
        visitDate: DateTime(2026, 11, 10),
        chiefComplaint: 'Palpitations',
        diagnosis: 'Sinus tachycardia',
        createdAt: DateTime(2026, 11, 10, 10, 0),
      );
      await hiveService.userBox.put('consultation_$consultationUuid', consultation.toJson());

      // Seed a dependent medicine
      await hiveService.userBox.put('medicine_1001', {
        'id': 'med_1001',
        'profile_id': profileId,
        'linked_consultation_id': consultationUuid,
        'name': 'Metoprolol',
      });

      await expectLater(
        consultationRepo.deleteConsultation(profileId, consultationUuid),
        throwsA(isA<ResourceHasDependenciesException>()),
      );
      expect(hiveService.userBox.containsKey('consultation_$consultationUuid'), isTrue);
      expect(fakeRemoteDataSource.lastDeletedConsultationId, isNull);

      // Clean medicine and add dependent report
      await hiveService.userBox.delete('medicine_1001');
      await hiveService.userBox.put('report_2001', {
        'id': 'rep_2001',
        'profile_id': profileId,
        'consultation_id': consultationUuid,
        'title': 'ECG Report',
      });

      await expectLater(
        consultationRepo.deleteConsultation(profileId, consultationUuid),
        throwsA(isA<ResourceHasDependenciesException>()),
      );
      expect(hiveService.userBox.containsKey('consultation_$consultationUuid'), isTrue);
      expect(fakeRemoteDataSource.lastDeletedConsultationId, isNull);
    });

    test('7. deleteConsultation removes record from Supabase when no dependencies exist', () async {
      final consultation = ConsultationModel(
        id: consultationUuid,
        profileId: profileId,
        doctorName: 'Dr. Eric Foreman',
        visitDate: DateTime(2026, 11, 10),
        chiefComplaint: 'Mild dizziness',
        diagnosis: 'Benign vertigo',
        createdAt: DateTime(2026, 11, 10, 10, 0),
      );
      await hiveService.userBox.put('consultation_$consultationUuid', consultation.toJson());
      fakeRemoteDataSource.remoteConsultations.add(consultation);

      await consultationRepo.deleteConsultation(profileId, consultationUuid);

      expect(hiveService.userBox.containsKey('consultation_$consultationUuid'), isFalse);
      expect(fakeRemoteDataSource.lastDeletedConsultationId, equals(consultationUuid));
      expect(fakeRemoteDataSource.remoteConsultations, isEmpty);
    });

    test('8. Offline save queues mutation and preserves local record', () async {
      fakeConnectivity.isOnline = false;
      final offlineConsultation = ConsultationModel(
        id: 'con_offline_101',
        profileId: profileId,
        doctorName: 'Dr. James Wilson',
        visitDate: DateTime(2026, 11, 11),
        chiefComplaint: 'Annual oncology screening',
        diagnosis: 'Clear',
        createdAt: DateTime(2026, 11, 11, 11, 0),
      );

      final saved = await consultationRepo.saveConsultationModel(profileId, offlineConsultation);

      expect(saved.id, equals('consultation_offline_101'));
      expect(fakeRemoteDataSource.lastCreatedConsultation, isNull);
      expect(hiveService.userBox.containsKey('consultation_offline_101'), isTrue);

      final queueEntries = hiveService.syncQueueBox.values.toList();
      expect(queueEntries.isNotEmpty, isTrue);
      final lastQueueItem = queueEntries.last;
      expect(lastQueueItem['entity'], equals('consultations'));
    });

    test('9. Cross-user isolation: profile belonging to another user cannot be pulled or saved', () async {
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

      fakeRemoteDataSource.remoteConsultations.add(
        ConsultationModel(
          id: '55555555-5555-5555-5555-555555555555',
          profileId: foreignProfileId,
          doctorName: 'Dr. Foreign Doctor',
          visitDate: DateTime(2026, 11, 11),
          chiefComplaint: 'Foreign complaint',
          diagnosis: 'Foreign diagnosis',
          createdAt: DateTime(2026, 11, 11, 11, 0),
        ),
      );

      // Attempt to pull foreign profile — must not populate local Hive
      await consultationRepo.pullConsultations(foreignProfileId);

      final cached = hiveService.userBox.get('consultation_55555555-5555-5555-5555-555555555555');
      expect(cached, isNull);
    });

    test('10. Supabase network failure falls back safely to local Hive cache', () async {
      fakeRemoteDataSource.shouldThrowNetworkError = true;

      // 1. Pull handles error gracefully without throwing
      await consultationRepo.pullConsultations(profileId);

      // 2. Save persists to local Hive cache and enqueues sync mutation
      final newCon = ConsultationModel(
        id: 'new_temp_id',
        profileId: profileId,
        doctorName: 'Dr. Fallback Test',
        visitDate: DateTime(2026, 11, 11),
        chiefComplaint: 'Fallback check',
        diagnosis: 'Test diagnosis',
        createdAt: DateTime(2026, 11, 11, 11, 0),
      );
      final saved = await consultationRepo.saveConsultationModel(profileId, newCon);
      expect(saved, isNotNull);
      expect(hiveService.userBox.containsKey(saved.id), isTrue);

      // 3. Delete removes from Hive and queues delete mutation
      await consultationRepo.deleteConsultation(profileId, saved.id);
      expect(hiveService.userBox.containsKey(saved.id), isFalse);
    });
  });
}
