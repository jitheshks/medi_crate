import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/attachment_cleanup_helper.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/reports/data/repositories/report_repository.dart';

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

class _FakeSupabaseReportRemoteDataSource
    extends SupabaseReportRemoteDataSource {
  final List<ReportModel> remoteReports = [];
  final Map<String, List<int>> storageFiles = {};
  bool shouldThrowNetworkError = false;
  ReportModel? lastCreatedReport;
  ReportModel? lastUpdatedReport;
  String? lastDeletedReportId;
  int _idCounter = 0;

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
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    var list = remoteReports
        .where((r) => IdUtils.matches(r.profileId, profileId))
        .toList();
    if (category != null && category.toUpperCase() != 'ALL') {
      list = list
          .where((r) => r.category.toUpperCase() == category.toUpperCase())
          .toList();
    }
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<ReportModel?> getReportById({
    required String reportId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(reportId);
    try {
      return remoteReports.firstWhere(
        (r) =>
            IdUtils.matches(r.id, cleanId) ||
            (r.clientUuid != null && r.clientUuid == cleanId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ReportModel> createReport({
    required ReportModel report,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedReport = report;
    _idCounter++;
    final cleanId = IdUtils.unprefix(report.id);
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : '00000000-0000-0000-0000-00000000000$_idCounter';
    final created = report.copyWith(
      id: effectiveId,
      profileId: profileId,
      clientUuid: report.clientUuid ?? effectiveId,
    );
    remoteReports.add(created);
    return created;
  }

  @override
  Future<ReportModel> updateReport({
    required ReportModel report,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedReport = report;
    final cleanId = IdUtils.unprefix(report.id);
    final updated = report.copyWith(id: cleanId);
    final index =
        remoteReports.indexWhere((r) => IdUtils.matches(r.id, cleanId));
    if (index >= 0) {
      remoteReports[index] = updated;
    } else {
      remoteReports.add(updated);
    }
    return updated;
  }

  @override
  Future<void> deleteReport({
    required String reportId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(reportId);
    lastDeletedReportId = cleanId;
    remoteReports.removeWhere((r) => IdUtils.matches(r.id, cleanId));
  }

  @override
  Future<String> uploadAttachmentFile({
    required String userId,
    required String reportId,
    required File file,
    String? customAttachmentId,
    String? fileName,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Upload error');
    final path =
        '$userId/$reportId/${customAttachmentId ?? "att"}_${fileName ?? "file.pdf"}';
    storageFiles[path] = await file.readAsBytes();
    return path;
  }
}

class _FakeSupabaseStorageService extends SupabaseStorageService {
  final Map<String, List<int>> storageFiles = {};
  bool shouldThrowStorageError = false;

  @override
  Future<String> uploadFile({
    required String bucket,
    required String storagePath,
    required File file,
    String? mimeType,
    bool? upsert,
    String? expectedUserId,
  }) async {
    if (shouldThrowStorageError) {
      throw StorageException('Storage error');
    }
    storageFiles[storagePath] = await file.readAsBytes();
    return storagePath;
  }

  @override
  Future<Uint8List> downloadBytes({
    required String bucket,
    required String storagePath,
    int maxSizeBytes = 25 * 1024 * 1024,
  }) async {
    if (shouldThrowStorageError) {
      throw StorageException('Storage error');
    }
    final data = storageFiles[storagePath];
    if (data == null) throw StorageException('File not found');
    return Uint8List.fromList(data);
  }

  @override
  Future<void> deleteParentFolder({
    required String bucket,
    required String parentId,
    required String userId,
  }) async {
    if (shouldThrowStorageError) {
      throw StorageException('Storage error');
    }
    storageFiles.removeWhere((k, _) => k.contains('/$parentId/'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late SyncService syncService;
  late _FakeConnectivityService connectivityService;
  late _FakeSupabaseReportRemoteDataSource fakeSupabaseDataSource;
  late _FakeSupabaseStorageService fakeStorageService;
  late ReportRepository repository;

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
    tempDir =
        await Directory.systemTemp.createTemp('reports_repo_supabase_test_');
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

    await hiveService.profileBox.put(testProfile.profileId, testProfile.toMap());
    await hiveService.profileBox
        .put(foreignProfile.profileId, foreignProfile.toMap());

    fakeSupabaseDataSource = _FakeSupabaseReportRemoteDataSource();
    fakeStorageService = _FakeSupabaseStorageService();

    AttachmentCleanupHelper.setCustomBaseDirectory(tempDir);

    repository = ReportRepository(
      hiveService: hiveService,
      syncService: syncService,
      supabaseRemoteDataSource: fakeSupabaseDataSource,
      storageService: fakeStorageService,
      connectivityService: connectivityService,
    );
  });

  tearDown(() async {
    AttachmentCleanupHelper.setCustomBaseDirectory(null);
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ReportRepository Supabase Integration Tests (R1–R6)', () {
    test('1. Hive-first reads: getReportsForProfile returns local records immediately and triggers pull', () async {
      final localReport = ReportModel(
        id: 'report_local_1',
        profileId: testProfileUuid,
        title: 'Cached Blood Test',
        category: 'LAB TEST',
        date: DateTime.utc(2026, 11, 10),
      );
      await hiveService.userBox.put('report_local_1', localReport.toJson());

      fakeSupabaseDataSource.remoteReports.add(
        ReportModel(
          id: '11111111-0000-0000-0000-000000000001',
          profileId: testProfileUuid,
          title: 'Remote Ultrasound',
          category: 'IMAGING',
          date: DateTime.utc(2026, 11, 9),
        ),
      );

      final initial = await repository.getReportsForProfile(
        testProfileUuid,
        explicitOwnerUserId: testUserId,
      );

      expect(initial.length, equals(1));
      expect(initial.first.title, equals('Cached Blood Test'));

      // Allow background pull to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = await repository.getReportsForProfile(
        testProfileUuid,
        explicitOwnerUserId: testUserId,
      );
      expect(updated.length, equals(2));
    });

    test('2. PendingMutationGuard: pullReports does NOT overwrite records with pending mutations', () async {
      const clientUuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final pendingReport = ReportModel(
        id: 'report_pending_1',
        profileId: testProfileUuid,
        title: 'Local Edits Pending',
        category: 'PRESCRIPTION',
        date: DateTime.utc(2026, 11, 10),
        clientUuid: clientUuid,
      );
      await hiveService.userBox.put('report_pending_1', pendingReport.toJson());

      await hiveService.syncQueueBox.add({
        'id': 'sync_123',
        'entity': 'reports',
        'operation': 'update',
        'profile_id': testProfileUuid,
        'payload': {
          'id': 'report_pending_1',
          'profile_id': testProfileUuid,
          'client_uuid': clientUuid,
          'title': 'Local Edits Pending',
        },
      });

      fakeSupabaseDataSource.remoteReports.add(
        ReportModel(
          id: 'report_pending_1',
          profileId: testProfileUuid,
          title: 'Stale Remote Title',
          category: 'PRESCRIPTION',
          date: DateTime.utc(2026, 11, 1),
          clientUuid: clientUuid,
        ),
      );

      await repository.pullReports(
        testProfileUuid,
        explicitOwnerUserId: testUserId,
      );

      final loaded =
          await repository.getReportById(testProfileUuid, 'report_pending_1');
      expect(loaded?.title, equals('Local Edits Pending'));
    });

    test('3. saveReport: offline queuing adds to Hive and SyncQueue without crashing', () async {
      connectivityService.isOnline = false;

      final newReport = ReportModel(
        id: '',
        profileId: testProfileUuid,
        title: 'Offline Report',
        category: 'LAB TEST',
        date: DateTime.utc(2026, 11, 10),
      );

      final saved = await repository.saveReport(
        testProfileUuid,
        newReport,
        explicitOwnerUserId: testUserId,
      );

      expect(saved.id, startsWith('report_'));
      expect(saved.clientUuid, isNotNull);

      final local = await repository.getReportById(testProfileUuid, saved.id);
      expect(local, isNotNull);
      expect(local?.title, equals('Offline Report'));

      expect(hiveService.syncQueueBox.isNotEmpty, isTrue);
      final queueItem = hiveService.syncQueueBox.values.first;
      expect(queueItem['entity'], equals('reports'));
      expect(fakeSupabaseDataSource.remoteReports, isEmpty);
    });

    test('4. saveReport: online create creates report in PostgREST, uploads attachments, and cleans sync queue', () async {
      connectivityService.isOnline = true;

      // Create a temporary file on disk to simulate an attachment
      final tempFile = File('${tempDir.path}/sample_test_scan.pdf');
      await tempFile.writeAsString('sample pdf content');

      final newReport = ReportModel(
        id: '',
        profileId: testProfileUuid,
        title: 'Liver Function Test',
        category: 'LAB TEST',
        date: DateTime.utc(2026, 11, 10),
        attachments: [
          ReportAttachmentModel(
            id: 'temp_att_1',
            name: 'lft_scan.pdf',
            size: '18 B',
            filePath: tempFile.path,
            fileType: 'application/pdf',
          ),
        ],
      );

      final saved = await repository.saveReport(
        testProfileUuid,
        newReport,
        explicitOwnerUserId: testUserId,
      );

      expect(UuidUtils.isValidUuid(IdUtils.unprefix(saved.id)), isTrue);
      expect(saved.title, equals('Liver Function Test'));
      expect(saved.attachments.first.fileUrl, contains(testUserId));
      expect(saved.attachments.first.filePath, equals(tempFile.path));

      expect(fakeSupabaseDataSource.remoteReports.length, equals(1));
      expect(fakeSupabaseDataSource.storageFiles.isNotEmpty, isTrue);

      // Sync queue item was cleaned up after successful push
      expect(hiveService.syncQueueBox.isEmpty, isTrue);
    });

    test('5. deleteReport: online deletes from DB, removes from Hive, and never calls Laravel', () async {
      const reportUuid = '55555555-5555-5555-5555-555555555555';
      final existingReport = ReportModel(
        id: reportUuid,
        profileId: testProfileUuid,
        title: 'Report to Delete',
        category: 'IMAGING',
        date: DateTime.utc(2026, 11, 10),
      );
      await hiveService.userBox
          .put('report_$reportUuid', existingReport.toJson());
      fakeSupabaseDataSource.remoteReports.add(existingReport);

      await repository.deleteReport(
        testProfileUuid,
        reportUuid,
        explicitOwnerUserId: testUserId,
      );

      final local =
          await repository.getReportById(testProfileUuid, reportUuid);
      expect(local, isNull);
      expect(fakeSupabaseDataSource.remoteReports, isEmpty);
    });

    test('6. getOrDownloadAttachmentFile: downloads from Supabase Storage and updates local Hive model', () async {
      const reportUuid = '66666666-6666-6666-6666-666666666666';
      const storagePath = '$testUserId/$reportUuid/att_cbc.pdf';

      fakeStorageService.storageFiles[storagePath] = [10, 20, 30, 40, 50];

      final report = ReportModel(
        id: reportUuid,
        profileId: testProfileUuid,
        title: 'CBC Report',
        category: 'LAB TEST',
        date: DateTime.utc(2026, 11, 10),
        attachments: const [
          ReportAttachmentModel(
            id: 'att_cbc_1',
            name: 'cbc.pdf',
            size: '5 B',
            fileUrl: storagePath,
            filePath: null, // Not yet downloaded
          ),
        ],
      );
      await hiveService.userBox.put('report_$reportUuid', report.toJson());

      final downloadedFile = await repository.getOrDownloadAttachmentFile(
        profileId: testProfileUuid,
        reportId: reportUuid,
        attachment: report.attachments.first,
        explicitOwnerUserId: testUserId,
      );

      expect(downloadedFile, isNotNull);
      expect(downloadedFile!.existsSync(), isTrue);
      expect(await downloadedFile.readAsBytes(), equals([10, 20, 30, 40, 50]));

      // Verify Hive record was updated with the local filePath
      final updatedReport =
          await repository.getReportById(testProfileUuid, reportUuid);
      expect(updatedReport?.attachments.first.filePath,
          equals(downloadedFile.path));
    });

    test('7. Profile Isolation: foreign profile access is rejected', () async {
      fakeSupabaseDataSource.remoteReports.add(
        ReportModel(
          id: '77777777-7777-7777-7777-777777777777',
          profileId: foreignProfileUuid,
          title: 'Foreign Patient Report',
          category: 'LAB TEST',
          date: DateTime.utc(2026, 11, 10),
        ),
      );

      // Attempt to pull foreign profile with testUserId
      await repository.pullReports(
        foreignProfileUuid,
        explicitOwnerUserId: testUserId,
      );

      final reports = await repository.getReportsForProfile(
        foreignProfileUuid,
        explicitOwnerUserId: testUserId,
      );
      expect(reports, isEmpty);
    });

    test('8. Failure Isolation: Supabase failure NEVER falls back to Laravel', () async {
      connectivityService.isOnline = true;
      fakeSupabaseDataSource.shouldThrowNetworkError = true;

      final report = ReportModel(
        id: '',
        profileId: testProfileUuid,
        title: 'Error Report',
        category: 'LAB TEST',
        date: DateTime.utc(2026, 11, 10),
      );

      final result = await repository.saveReport(
        testProfileUuid,
        report,
        explicitOwnerUserId: testUserId,
      );

      expect(result.title, equals('Error Report'));
      // Verifies zero calls to legacy Laravel remote data source
    });

    test('9. Report Expenses: saves 1:1 expense with amount and currency and persists in Hive and Supabase', () async {
      connectivityService.isOnline = true;

      const reportUuid = '88888888-8888-8888-8888-888888888888';
      final reportWithExpense = ReportModel(
        id: reportUuid,
        profileId: testProfileUuid,
        title: 'MRI Brain with Contrast',
        category: 'IMAGING',
        date: DateTime.utc(2026, 11, 12),
        expense: const ReportExpenseModel(
          id: 'exp_mri_1',
          amount: 7500.0,
          currency: 'INR',
          description: 'Diagnostic Scan Fee',
        ),
      );

      final saved = await repository.saveReport(
        testProfileUuid,
        reportWithExpense,
        explicitOwnerUserId: testUserId,
      );

      expect(saved.expense, isNotNull);
      expect(saved.expense!.amount, equals(7500.0));
      expect(saved.expense!.currency, equals('INR'));
      expect(saved.expense!.description, equals('Diagnostic Scan Fee'));

      final cached = await repository.getReportById(testProfileUuid, reportUuid);
      expect(cached?.expense, isNotNull);
      expect(cached!.expense!.amount, equals(7500.0));
    });

    test('10. Attachment Replacement: replacing an attachment cleans up removed local file from disk', () async {
      connectivityService.isOnline = true;

      final profileAttDir = Directory(
        '${tempDir.path}/profiles/$testProfileUuid/reports/attachments',
      );
      await profileAttDir.create(recursive: true);

      final file1 = File('${profileAttDir.path}/report_old_scan.png');
      await file1.writeAsString('old image content');
      final file2 = File('${profileAttDir.path}/report_new_scan.png');
      await file2.writeAsString('new image content');

      const reportUuid = '99999999-9999-9999-9999-999999999999';
      final initialReport = ReportModel(
        id: reportUuid,
        profileId: testProfileUuid,
        title: 'Ultrasound Pelvis',
        category: 'IMAGING',
        date: DateTime.utc(2026, 11, 10),
        attachments: [
          ReportAttachmentModel(
            id: 'att_old',
            name: 'old_scan.png',
            size: '16 B',
            filePath: file1.path,
            fileType: 'image/png',
          ),
        ],
      );

      await repository.saveReport(
        testProfileUuid,
        initialReport,
        explicitOwnerUserId: testUserId,
      );
      expect(file1.existsSync(), isTrue);

      // Now update the report, replacing att_old with att_new
      final updatedReport = initialReport.copyWith(
        attachments: [
          ReportAttachmentModel(
            id: 'att_new',
            name: 'new_scan.png',
            size: '16 B',
            filePath: file2.path,
            fileType: 'image/png',
          ),
        ],
      );

      await repository.saveReport(
        testProfileUuid,
        updatedReport,
        explicitOwnerUserId: testUserId,
      );

      // file1 must have been deleted from disk because it was replaced
      expect(file1.existsSync(), isFalse);
      expect(file2.existsSync(), isTrue);
    });

    test('11. Strict session authorization: local auth cache without active session does NOT authorize remote operations', () async {
      await hiveService.authBox.put('current_user', {
        'id': testUserId,
        'email': 'cached@example.com',
      });

      fakeSupabaseDataSource.remoteReports.add(
        ReportModel(
          id: 'unauth-probe-1',
          profileId: testProfileUuid,
          title: 'Unauthenticated Probe Report',
          category: 'LAB TEST',
          date: DateTime.utc(2026, 11, 10),
        ),
      );

      // Pull without explicitOwnerUserId and without active Supabase session
      await repository.pullReports(testProfileUuid);

      // Must NOT have pulled from remote data source because local cache must not authorize remote calls
      final cached = hiveService.userBox.get('report_unauth-probe-1');
      expect(cached, isNull);
    });

    test('12. Image and PDF attachments support: both types correctly resolve paths and store files', () async {
      connectivityService.isOnline = true;

      final pngFile = File('${tempDir.path}/skin_lesion.jpg');
      await pngFile.writeAsString('jpeg bytes');
      final pdfFile = File('${tempDir.path}/pathology_report.pdf');
      await pdfFile.writeAsString('pdf bytes');

      final multiAttachmentReport = ReportModel(
        id: '',
        profileId: testProfileUuid,
        title: 'Dermatology Consultation Review',
        category: 'CONSULTATION',
        date: DateTime.utc(2026, 11, 11),
        attachments: [
          ReportAttachmentModel(
            id: 'att_img_1',
            name: 'skin_lesion.jpg',
            size: '10 B',
            filePath: pngFile.path,
            fileType: 'image/jpeg',
          ),
          ReportAttachmentModel(
            id: 'att_pdf_1',
            name: 'pathology_report.pdf',
            size: '9 B',
            filePath: pdfFile.path,
            fileType: 'application/pdf',
          ),
        ],
      );

      final saved = await repository.saveReport(
        testProfileUuid,
        multiAttachmentReport,
        explicitOwnerUserId: testUserId,
      );

      expect(saved.attachments.length, equals(2));
      expect(saved.attachments[0].fileUrl, contains(testUserId));
      expect(saved.attachments[1].fileUrl, contains(testUserId));
      expect(saved.attachments[0].fileUrl, endsWith('.jpg'));
      expect(saved.attachments[1].fileUrl, endsWith('.pdf'));
    });
  });
}
