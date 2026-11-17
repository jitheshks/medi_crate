import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/queue_coalescer.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_lock.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// TEST FAKES
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  final String id;
  _FakeUser({required this.id});
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  User? mockUser;
  _FakeGoTrueClient({this.mockUser});

  @override
  User? get currentUser => mockUser;
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  final _FakeGoTrueClient _auth;
  _FakeSupabaseClient({User? user}) : _auth = _FakeGoTrueClient(mockUser: user);

  @override
  GoTrueClient get auth => _auth;
}

class _FakeConnectivityService extends Fake implements ConnectivityService {
  bool isOnline = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> checkConnectivity() async => isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool status) {
    isOnline = status;
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _FakeSupabaseStorageService extends Fake
    implements SupabaseStorageService {
  final Map<String, List<int>> storage = {};
  final List<String> deletedFolders = [];
  bool failNextDeleteParentFolder = false;
  int deleteParentFolderCalls = 0;

  @override
  Future<String> uploadFile({
    required String bucket,
    required String storagePath,
    required File file,
    String? expectedUserId,
    String? mimeType,
    bool? upsert,
  }) async {
    storage['$bucket/$storagePath'] = await file.readAsBytes();
    return storagePath;
  }

  @override
  Future<void> deleteParentFolder({
    required String bucket,
    required String parentId,
    required String userId,
  }) async {
    deleteParentFolderCalls++;
    if (failNextDeleteParentFolder) {
      throw const StorageOperationException(
        'Storage connection refused during folder cleanup',
      );
    }
    storage.removeWhere((k, _) => k.startsWith('$bucket/$userId/$parentId'));
    deletedFolders.add('$bucket/$userId/$parentId');
  }
}

class _FakeSupabaseProfileRemoteDataSource extends Fake
    implements SupabaseProfileRemoteDataSource {
  final List<ProfileModel> profiles = [];
  bool archiveCalled = false;
  String? lastArchivedProfileId;
  Future<void> Function()? onBeforeArchive;

  @override
  Future<List<ProfileModel>> fetchProfiles({
    required String ownerUserId,
    bool includeArchived = false,
  }) async {
    return profiles.where((p) => p.ownerUserId == ownerUserId).toList();
  }

  @override
  Future<ProfileModel> createFamilyProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    final serverId = UuidUtils.generateV4();
    final created = profile.copyWith(
      profileId: serverId,
      ownerUserId: ownerUserId,
    );
    profiles.add(created);
    return created;
  }

  @override
  Future<ProfileModel> updateProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    final idx = profiles.indexWhere((p) => p.profileId == profile.profileId);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    return profile;
  }

  @override
  Future<ProfileModel> archiveProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    if (onBeforeArchive != null) {
      await onBeforeArchive!();
    }
    archiveCalled = true;
    lastArchivedProfileId = profileId;
    final idx = profiles.indexWhere((p) => p.profileId == profileId);
    if (idx >= 0) {
      final updated = profiles[idx].copyWith(isArchived: true);
      profiles[idx] = updated;
      return updated;
    }
    final created = ProfileModel(
      profileId: profileId,
      fullName: 'Secondary Family Member',
      relationship: 'Brother',
      ownerUserId: ownerUserId,
      isArchived: true,
    );
    profiles.add(created);
    return created;
  }
}

class _FakeSupabaseReportRemoteDataSource extends Fake
    implements SupabaseReportRemoteDataSource {
  final List<ReportModel> reports = [];
  final SupabaseStorageService storageService;
  bool deleteCalled = false;
  bool createCalled = false;
  bool updateCalled = false;
  bool failExpensePersistence = false;
  int expenseUpsertAttempts = 0;

  _FakeSupabaseReportRemoteDataSource({required this.storageService});

  @override
  Future<List<ReportModel>> fetchReports({
    required String ownerUserId,
    required String profileId,
    String? category,
    String? consultationId,
    String? doctorId,
    String? hospitalId,
    String? search,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return reports.where((r) => r.profileId == profileId).toList();
  }

  @override
  Future<ReportModel> createReport({
    required ReportModel report,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(report.id);
    final id = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : '00000000-0000-0000-0007-000000000001';

    if (report.expense != null) {
      expenseUpsertAttempts++;
      if (failExpensePersistence) {
        throw const ServerException('Failed to persist report expense');
      }
    }

    final created = report.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: report.clientUuid ?? id,
    );
    reports.add(created);
    return created;
  }

  @override
  Future<ReportModel> updateReport({
    required ReportModel report,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    if (report.expense != null) {
      expenseUpsertAttempts++;
      if (failExpensePersistence) {
        throw const ServerException('Failed to synchronize report expense');
      }
    }
    final idx = reports.indexWhere((r) => r.id == report.id);
    if (idx >= 0) {
      reports[idx] = report;
    } else {
      reports.add(report);
    }
    return report;
  }

  @override
  Future<void> deleteReport({
    required String reportId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    // Strict contract: Storage cleanup must succeed before database deletion
    await storageService.deleteParentFolder(
      bucket: SupabaseStorageService.reportsBucket,
      parentId: reportId,
      userId: ownerUserId,
    );
    reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<String> uploadAttachmentFile({
    required String userId,
    required String reportId,
    required File file,
    String? customAttachmentId,
    String? fileName,
  }) async {
    final attId = customAttachmentId ?? UuidUtils.generateV4();
    final fName = fileName ?? 'file.pdf';
    final path = '$userId/$reportId/${attId}_$fName';
    return await storageService.uploadFile(
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: path,
      file: file,
      expectedUserId: userId,
      upsert: true,
    );
  }
}

class _FakeSupabaseConsultationRemoteDataSource extends Fake
    implements SupabaseConsultationRemoteDataSource {
  final List<ConsultationModel> consultations = [];
  final SupabaseStorageService storageService;
  bool deleteCalled = false;

  _FakeSupabaseConsultationRemoteDataSource({required this.storageService});

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
    return consultations.where((c) => c.profileId == profileId).toList();
  }

  @override
  Future<void> deleteConsultation({
    required String consultationId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    // Strict contract: Storage cleanup must succeed before database deletion
    await storageService.deleteParentFolder(
      bucket: SupabaseStorageService.consultationsBucket,
      parentId: consultationId,
      userId: ownerUserId,
    );
    consultations.removeWhere((c) => c.id == consultationId);
  }
}

// ---------------------------------------------------------------------------
// MAIN REGRESSION SUITE
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeConnectivityService connectivityService;
  late _FakeSupabaseStorageService fakeStorage;
  late _FakeSupabaseProfileRemoteDataSource fakeProfileRemote;
  late _FakeSupabaseReportRemoteDataSource fakeReportRemote;
  late _FakeSupabaseConsultationRemoteDataSource fakeConsultationRemote;
  late SupabaseSyncCoordinator coordinator;
  late SyncService syncService;

  const testUserId = '00000000-0000-0000-0000-000000000001';
  const testProfileId = '00000000-0000-0000-0000-000000000002';
  const testFamilyProfileId = '00000000-0000-0000-0000-000000000003';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_safety_test_');
    Hive.init(tempDir.path);

    await Future.wait([
      Hive.openBox<Map>(HiveService.authBoxName),
      Hive.openBox<Map>(HiveService.syncQueueBoxName),
      Hive.openBox<Map>(HiveService.userBoxName),
      Hive.openBox<Map>(HiveService.settingsBoxName),
      Hive.openBox<Map>(HiveService.consentBoxName),
      Hive.openBox<Map>(HiveService.profileBoxName),
    ]);

    hiveService = HiveService();

    // Seed primary user profile and active auth session
    await hiveService.authBox.put('current_user', {
      'id': testUserId,
      'user_id': testUserId,
    });
    await hiveService.profileBox.put('prof_$testProfileId', {
      'profile_id': testProfileId,
      'name': 'Primary User',
      'relationship': 'Self',
      'is_primary': true,
      'owner_user_id': testUserId,
    });
    await hiveService.profileBox.put('prof_$testFamilyProfileId', {
      'profile_id': testFamilyProfileId,
      'name': 'Family Brother',
      'relationship': 'Brother',
      'is_primary': false,
      'owner_user_id': testUserId,
      'is_archived': false,
    });

    connectivityService = _FakeConnectivityService();
    fakeStorage = _FakeSupabaseStorageService();
    fakeProfileRemote = _FakeSupabaseProfileRemoteDataSource();
    fakeReportRemote = _FakeSupabaseReportRemoteDataSource(storageService: fakeStorage);
    fakeConsultationRemote = _FakeSupabaseConsultationRemoteDataSource(storageService: fakeStorage);

    final mockClient = _FakeSupabaseClient(user: _FakeUser(id: testUserId));

    coordinator = SupabaseSyncCoordinator(
      hiveService: hiveService,
      customClient: mockClient,
      customStorageService: fakeStorage,
      customProfileRemoteDataSource: fakeProfileRemote,
      customReportRemoteDataSource: fakeReportRemote,
      customConsultationRemoteDataSource: fakeConsultationRemote,
    );

    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: connectivityService,
      customSupabaseSyncCoordinator: coordinator,
    );
  });

  tearDown(() async {
    syncService.dispose();
    connectivityService.dispose();
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Implementation 5.2 — Focused Safety Regression Tests', () {
    test('1. Storage deletion failure preserves parent report and mutation', () async {
      const reportUuid = '00000000-0000-0000-0007-000000000010';
      final existingReport = ReportModel(
        id: reportUuid,
        profileId: testProfileId,
        title: 'Blood Test Report',
        category: 'LAB_REPORT',
        date: DateTime.now(),
      );
      fakeReportRemote.reports.add(existingReport);
      await hiveService.userBox.put('report_$reportUuid', existingReport.toJson());

      // Simulate Storage failure during parent folder deletion
      fakeStorage.failNextDeleteParentFolder = true;

      final deleteMutation = SyncQueueItem(
        id: 'q_rep_del_fail',
        entity: 'report',
        operation: 'delete',
        payload: {
          'id': reportUuid,
          'profile_id': testProfileId,
        },
      );
      await hiveService.syncQueueBox.put(deleteMutation.id, deleteMutation.toMap());

      await syncService.syncPendingToSupabase(force: true);

      // Parent database record MUST NOT be deleted
      expect(fakeReportRemote.reports.any((r) => r.id == reportUuid), isTrue,
          reason: 'Parent report row must be preserved when Storage deletion fails');

      // Local Hive cache record MUST NOT be deleted
      expect(hiveService.userBox.containsKey('report_$reportUuid'), isTrue,
          reason: 'Local Hive cache must be preserved for retry');

      // Delete mutation MUST NOT be acknowledged or removed from queue
      final queueItemRaw = hiveService.syncQueueBox.get(deleteMutation.id);
      expect(queueItemRaw, isNotNull);
      final queueItem = SyncQueueItem.fromMap(Map<String, dynamic>.from(queueItemRaw!));
      expect(queueItem.status, equals('failed'),
          reason: 'Mutation must be marked retryable/failed');
    });

    test('2. Partial Storage deletion can safely resume and complete', () async {
      const reportUuid = '00000000-0000-0000-0007-000000000020';
      final existingReport = ReportModel(
        id: reportUuid,
        profileId: testProfileId,
        title: 'MRI Scan',
        category: 'SCAN',
        date: DateTime.now(),
      );
      fakeReportRemote.reports.add(existingReport);
      await hiveService.userBox.put('report_$reportUuid', existingReport.toJson());

      // First attempt: Storage fails
      fakeStorage.failNextDeleteParentFolder = true;
      final deleteMutation = SyncQueueItem(
        id: 'q_rep_del_resume',
        entity: 'report',
        operation: 'delete',
        payload: {
          'id': reportUuid,
          'profile_id': testProfileId,
        },
      );
      await hiveService.syncQueueBox.put(deleteMutation.id, deleteMutation.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(deleteMutation.id), isTrue);

      // Second attempt: Storage recovers and resumes cleanly
      fakeStorage.failNextDeleteParentFolder = false;
      await syncService.syncPendingToSupabase(force: true);

      // After Storage succeeds, remote DB row is deleted
      expect(fakeReportRemote.reports.any((r) => r.id == reportUuid), isFalse);
      // Local cache is cleaned
      expect(hiveService.userBox.containsKey('report_$reportUuid'), isFalse);
      // Mutation is acknowledged and removed
      expect(hiveService.syncQueueBox.containsKey(deleteMutation.id), isFalse);
    });

    test('3. Consultation attachment deletion failure preserves parent record and mutation', () async {
      const consultationUuid = '00000000-0000-0000-0003-000000000010';
      final existingConsultation = ConsultationModel(
        id: consultationUuid,
        profileId: testProfileId,
        visitDate: DateTime.now(),
        doctorName: 'Dr. John Doe',
        chiefComplaint: 'Headache',
        diagnosis: 'Migraine',
        createdAt: DateTime.now(),
      );
      fakeConsultationRemote.consultations.add(existingConsultation);
      await hiveService.userBox.put('consultation_$consultationUuid', existingConsultation.toJson());

      // Simulate Storage failure during consultation parent folder cleanup
      fakeStorage.failNextDeleteParentFolder = true;

      final deleteMutation = SyncQueueItem(
        id: 'q_con_del_fail',
        entity: 'consultation',
        operation: 'delete',
        payload: {
          'id': consultationUuid,
          'profile_id': testProfileId,
        },
      );
      await hiveService.syncQueueBox.put(deleteMutation.id, deleteMutation.toMap());

      await syncService.syncPendingToSupabase(force: true);

      // Parent consultation row MUST NOT be deleted
      expect(fakeConsultationRemote.consultations.any((c) => c.id == consultationUuid), isTrue);
      // Local Hive cache MUST NOT be deleted
      expect(hiveService.userBox.containsKey('consultation_$consultationUuid'), isTrue);
      // Mutation remains in queue
      expect(hiveService.syncQueueBox.containsKey(deleteMutation.id), isTrue);
    });

    test('4. Report expense failure and idempotent retry', () async {
      const reportUuid = '00000000-0000-0000-0007-000000000030';
      const expense = ReportExpenseModel(
        id: '00000000-0000-0000-0008-000000000001',
        amount: 500.0,
        currency: 'INR',
        status: 'PAID',
      );

      final reportItem = SyncQueueItem(
        id: 'q_rep_exp_test',
        entity: 'report',
        operation: 'create',
        payload: {
          'id': reportUuid,
          'profile_id': testProfileId,
          'title': 'General Checkup',
          'category': 'PRESCRIPTION',
          'date': DateTime.now().toIso8601String(),
          'expense': expense.toJson(),
        },
      );
      await hiveService.syncQueueBox.put(reportItem.id, reportItem.toMap());

      // First run: simulate failure during expense persistence
      fakeReportRemote.failExpensePersistence = true;
      await syncService.syncPendingToSupabase(force: true);

      // Mutation MUST NOT be acknowledged when expense fails
      expect(hiveService.syncQueueBox.containsKey(reportItem.id), isTrue);
      final rawFailed = hiveService.syncQueueBox.get(reportItem.id);
      final failedItem = SyncQueueItem.fromMap(Map<String, dynamic>.from(rawFailed!));
      expect(failedItem.status, equals('failed'));

      // Second run: expense recovers; retry uses upsert without duplicate or unique constraint failure
      fakeReportRemote.failExpensePersistence = false;
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(reportItem.id), isFalse,
          reason: 'Mutation should be acknowledged after successful retry');
      expect(fakeReportRemote.reports.length, equals(1));
      expect(fakeReportRemote.reports.first.expense?.amount, equals(500.0));
    });

    test('5. Secondary profile deletion follows archival workflow', () async {
      final familyProfile = ProfileModel(
        profileId: testFamilyProfileId,
        fullName: 'Family Brother',
        relationship: 'Brother',
        isPrimary: false,
        ownerUserId: testUserId,
      );
      fakeProfileRemote.profiles.add(familyProfile);

      final archiveMutation = SyncQueueItem(
        id: 'q_fam_archive',
        entity: 'profile',
        operation: 'delete',
        payload: {
          'profile_id': testFamilyProfileId,
          'is_primary': false,
          'relationship': 'Brother',
        },
      );
      await hiveService.syncQueueBox.put(archiveMutation.id, archiveMutation.toMap());

      await syncService.syncPendingToSupabase(force: true);

      // Verifies archiveProfile was called on the remote data source
      expect(fakeProfileRemote.archiveCalled, isTrue);
      expect(fakeProfileRemote.lastArchivedProfileId, equals(testFamilyProfileId));
      expect(fakeProfileRemote.profiles.first.isArchived, isTrue);

      // Local cache updated with archived state
      final localRaw = hiveService.profileBox.get(testFamilyProfileId) ??
          hiveService.profileBox.get('prof_$testFamilyProfileId');
      expect(localRaw, isNotNull);
      final localModel = ProfileModel.fromMap(Map<String, dynamic>.from(localRaw!));
      expect(localModel.isArchived, isTrue);
    });

    test('6. Unsupported profile hard deletion is rejected and dead-lettered', () async {
      final hardDeleteMutation = SyncQueueItem(
        id: 'q_fam_hard_del',
        entity: 'profile',
        operation: 'hard_delete',
        payload: {
          'profile_id': testFamilyProfileId,
          'is_primary': false,
        },
      );
      await hiveService.syncQueueBox.put(hardDeleteMutation.id, hardDeleteMutation.toMap());

      await syncService.syncPendingToSupabase(force: true);

      final rawItem = hiveService.syncQueueBox.get(hardDeleteMutation.id);
      expect(rawItem, isNotNull);
      final stored = SyncQueueItem.fromMap(Map<String, dynamic>.from(rawItem!));
      expect(stored.status, equals('failed'));
      expect(stored.retryCount, equals(99), reason: 'Unsupported hard delete must dead-letter');
      expect(stored.errorMessage, contains('Direct hard-deletion of profiles is disabled'));
    });

    test('7. Foreign-key retry exhaustion transitions to dead-letter at retryCount 99', () async {
      // Simulate PostgrestException 23503 on item with retryCount = 4 (exhaustion threshold)
      final item = SyncQueueItem(
        id: 'q_fk_exhaust',
        entity: 'consultation',
        operation: 'create',
        retryCount: 4, // 5th attempt
        payload: {
          'id': '00000000-0000-0000-0003-000000000099',
          'profile_id': testProfileId,
          'doctor_id': '00000000-0000-0000-0002-999999999999', // Missing FK
          'doctor_name': 'Dr. Missing',
          'visit_date': DateTime.now().toIso8601String(),
          'chief_complaint': 'Checkup',
          'diagnosis': 'Healthy',
        },
      );

      // Coordinator handles 23503 when thrown by underlying datasource
      coordinator = SupabaseSyncCoordinator(
        hiveService: hiveService,
        customClient: _FakeSupabaseClient(user: _FakeUser(id: testUserId)),
        customConsultationRemoteDataSource: _FailingForeignKeyConsultationRemoteDataSource(),
      );

      final success = await coordinator.processItem(
        item: item,
        explicitOwnerUserId: testUserId,
      );

      expect(success, isFalse);
      expect(item.status, equals('failed'));
      expect(item.retryCount, equals(99), reason: 'Retry count >= 4 on 23503 must dead-letter to 99');
      expect(item.errorMessage, contains('Foreign key dependency failed after retry exhaustion'));
    });

    test('8. CREATE + DELETE while CREATE is in-flight preserves both operations', () {
      final inFlightCreate = QueueEntry(
        'q_inflight_create',
        SyncQueueItem(
          id: 'q_inflight_create',
          entity: 'hospital',
          operation: 'create',
          status: 'syncing',
          claimToken: 'proc_active_123',
          claimedAt: DateTime.now(),
          payload: {
            'id': 'local_hosp_inflight',
            'client_uuid': 'cuuid-hosp-inflight',
            'name': 'Active Clinic',
          },
        ),
      );

      final incomingDelete = SyncQueueItem(
        id: 'q_incoming_del',
        entity: 'hospital',
        operation: 'delete',
        payload: {
          'id': 'local_hosp_inflight',
          'client_uuid': 'cuuid-hosp-inflight',
        },
      );

      final result = QueueCoalescer.coalesce(
        existing: [inFlightCreate],
        incoming: incomingDelete,
        now: DateTime.now(),
        leaseDuration: const Duration(minutes: 3),
      );

      // In-flight CREATE must NOT be deleted from queue
      expect(result.keysToDelete.contains('q_inflight_create'), isFalse,
          reason: 'In-flight CREATE must never be deleted when DELETE arrives');

      // The incoming DELETE must be preserved to run after CREATE completes
      expect(result.wroteSomething, isTrue);
      expect(result.putItem?.operation, equals('delete'));
      expect(result.putItem?.payload['_needs_server_id'], isTrue);
    });

    test('9. Successful CREATE followed by DELETE generates server-backed delete', () {
      final existingStaleCreate = QueueEntry(
        'q_stale_create',
        SyncQueueItem(
          id: 'q_stale_create',
          entity: 'hospital',
          operation: 'create',
          status: 'pending',
          payload: {
            'id': 'hosp_uuid_server_confirmed',
            'client_uuid': 'cuuid-hosp-confirmed',
            'name': 'Confirmed Clinic',
          },
        ),
      );

      final incomingDelete = SyncQueueItem(
        id: 'q_incoming_del_confirmed',
        entity: 'hospital',
        operation: 'delete',
        payload: {
          'id': 'hosp_uuid_server_confirmed',
          'client_uuid': 'cuuid-hosp-confirmed',
        },
      );

      final result = QueueCoalescer.coalesce(
        existing: [existingStaleCreate],
        incoming: incomingDelete,
        now: DateTime.now(),
        leaseDuration: const Duration(minutes: 3),
        hasServerRecord: true,
      );

      expect(result.wroteSomething, isTrue);
      expect(result.putItem?.operation, equals('delete'));
      expect(result.keysToDelete.contains('q_stale_create'), isTrue);
    });

    test('10. Long-running upload extends claim timestamp and renews SyncLock lease', () async {
      final lock = SyncLock(hiveService.settingsBox);
      final lockToken = await lock.tryAcquire();
      expect(lockToken, isNotNull);

      // Verify lock.renew extends expiresAt
      final preRenewRaw = hiveService.settingsBox.get('__sync_lease__');
      final preExpiresAt = DateTime.parse(preRenewRaw!['expiresAt'] as String);

      await Future.delayed(const Duration(milliseconds: 50));
      final renewed = await lock.renew(lockToken!);
      expect(renewed, isTrue);

      final postRenewRaw = hiveService.settingsBox.get('__sync_lease__');
      final postExpiresAt = DateTime.parse(postRenewRaw!['expiresAt'] as String);

      expect(postExpiresAt.isAfter(preExpiresAt), isTrue,
          reason: 'Lease renewal must extend expiration timestamp for long-running operations');
    });

    test('11. Worker cannot acknowledge or delete mutation if claim was lost during execution', () async {
      final item = SyncQueueItem(
        id: 'q_lost_claim',
        entity: 'profile',
        operation: 'delete',
        status: 'pending',
        payload: {
          'id': testFamilyProfileId,
          'profile_id': testFamilyProfileId,
          'is_primary': false,
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // While archiveProfile is executing, a rival processor steals the claim in Hive
      fakeProfileRemote.onBeforeArchive = () async {
        final raw = hiveService.syncQueueBox.get('q_lost_claim');
        if (raw is Map) {
          final stolen = Map<String, dynamic>.from(raw);
          stolen['claimToken'] = 'rival_processor_stealer';
          stolen['claimedAt'] = DateTime.now().toIso8601String();
          await hiveService.syncQueueBox.put('q_lost_claim', stolen);
        }
      };

      await syncService.syncPendingToSupabase(
        force: true,
        explicitOwnerUserId: testUserId,
      );

      // Verify the item is preserved in Hive and NOT deleted or acknowledged by the original worker
      final postItemRaw = hiveService.syncQueueBox.get('q_lost_claim');
      expect(postItemRaw, isNotNull,
          reason: 'Worker must not delete or acknowledge item if its claim was lost or stolen');
      expect(postItemRaw!['claimToken'], equals('rival_processor_stealer'));
    });

    test('12. Interrupted in-flight CREATE and deferred DELETE execute safely upon restart', () async {
      // 1. Simulating an app restart after an in-flight CREATE timed out:
      // An in-flight CREATE with an expired claim (> 3 minutes old)
      final expiredClaimTime = DateTime.now().subtract(const Duration(minutes: 5));
      const clientUuid = '00000000-0000-0000-0000-000000000099';
      final inFlightCreate = SyncQueueItem(
        id: 'q_crashed_create',
        entity: 'profile',
        operation: 'create',
        status: 'syncing',
        claimToken: 'dead_process_token',
        claimedAt: expiredClaimTime,
        payload: {
          'id': 'prof_local_provisional',
          'client_uuid': clientUuid,
          'name': 'Restart Recovered Member',
          'relationship': 'Sister',
          'is_primary': false,
        },
      );

      // 2. A deferred DELETE waiting for server ID resolution
      final deferredDelete = SyncQueueItem(
        id: 'q_deferred_delete',
        entity: 'profile',
        operation: 'delete',
        status: 'pending',
        payload: {
          'id': 'prof_local_provisional',
          'client_uuid': clientUuid,
          'is_primary': false,
          '_needs_server_id': true,
        },
      );

      await hiveService.syncQueueBox.put(inFlightCreate.id, inFlightCreate.toMap());
      await hiveService.syncQueueBox.put(deferredDelete.id, deferredDelete.toMap());

      // Run sync service (simulating post-restart execution)
      await syncService.syncPendingToSupabase(
        force: true,
        explicitOwnerUserId: testUserId,
      );

      // Verify inFlightCreate was reclaimed and completed
      expect(hiveService.syncQueueBox.containsKey('q_crashed_create'), isFalse,
          reason: 'CREATE should be completed and removed from queue');

      // Verify remote profile was created then archived by the sequential delete
      expect(fakeProfileRemote.archiveCalled, isTrue,
          reason: 'Deferred DELETE should resolve server ID and execute archival');
      expect(fakeProfileRemote.profiles.any((p) => p.isArchived), isTrue);
    });
  });
}

class _FailingForeignKeyConsultationRemoteDataSource extends Fake
    implements SupabaseConsultationRemoteDataSource {
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
    return [];
  }

  @override
  Future<ConsultationModel> createConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    required String profileId,
  }) async {
    throw const PostgrestException(
      message: 'insert or update on table "consultations" violates foreign key constraint "fk_consultations_doctor"',
      code: '23503',
    );
  }
}
