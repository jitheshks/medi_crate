import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_attachment.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/reports/data/repositories/report_repository.dart';

import '../../core/storage/supabase_storage_service_test.dart';

void main() {
  late Directory tempDir;
  late HiveService hiveService;
  late FakeSupabaseClient fakeClient;
  late SupabaseStorageService storageService;
  late ConsultationRepository consultationRepo;
  late ReportRepository reportRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_repo_integration_test_');
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
    fakeClient = FakeSupabaseClient();
    storageService = SupabaseStorageService(customClient: fakeClient);

    consultationRepo = ConsultationRepository(
      hiveService: hiveService,
      storageService: storageService,
    );

    reportRepo = ReportRepository(
      hiveService: hiveService,
      storageService: storageService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Storage Repository Integration Tests', () {
    test('ConsultationRepository downloads missing attachment from Supabase Storage', () async {
      final remoteStoragePath = 'user_123/c_1/att_1_rx.pdf';
      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      bucketApi.storedFiles[remoteStoragePath] = Uint8List.fromList([10, 20, 30, 40]);

      // Seed local consultation record
      final initialConsultation = ConsultationModel(
        id: 'consultation_1',
        profileId: 'prof_1',
        doctorName: 'Dr. Smith',
        chiefComplaint: 'Fever',
        diagnosis: 'Flu',
        visitDate: DateTime.now(),
        createdAt: DateTime.now(),
        attachments: [
          const ConsultationAttachment(
            id: 'att_1',
            name: 'rx.pdf',
            sizeKB: 1,
            filePath: null, // Not cached locally
            fileUrl: 'user_123/c_1/att_1_rx.pdf',
          ),
        ],
      );
      await consultationRepo.saveConsultationModel('prof_1', initialConsultation);

      // Execute download via repository
      final resolvedFile = await consultationRepo.getOrDownloadAttachmentFile(
        profileId: 'prof_1',
        consultationId: 'consultation_1',
        attachment: initialConsultation.attachments.first,
        customBaseDirectory: tempDir,
      );

      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.existsSync(), isTrue);
      expect(await resolvedFile.readAsBytes(), [10, 20, 30, 40]);

      // Verify model retrieved from repository has updated filePath
      final updatedModel = await consultationRepo.getConsultationById('prof_1', 'consultation_1');
      expect(updatedModel, isNotNull);
      expect(updatedModel!.attachments.first.filePath, resolvedFile.path);
    });

    test('ReportRepository downloads missing attachment from Supabase Storage', () async {
      final remoteStoragePath = 'user_123/rep_1/att_1_scan.png';
      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.reportsBucket) as FakeStorageFileApi;
      bucketApi.storedFiles[remoteStoragePath] = Uint8List.fromList([50, 60, 70]);

      // Seed local report record
      final initialReport = ReportModel(
        id: 'report_1',
        profileId: 'prof_1',
        title: 'Chest X-Ray',
        category: 'IMAGING',
        date: DateTime.now(),
        attachments: [
          const ReportAttachmentModel(
            id: 'att_1',
            name: 'scan.png',
            size: '1 KB',
            filePath: null, // Not cached locally
            fileUrl: 'user_123/rep_1/att_1_scan.png',
          ),
        ],
      );
      await reportRepo.saveReport('prof_1', initialReport);

      final resolvedFile = await reportRepo.getOrDownloadAttachmentFile(
        profileId: 'prof_1',
        reportId: 'report_1',
        attachment: initialReport.attachments.first,
      );

      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.existsSync(), isTrue);
      expect(await resolvedFile.readAsBytes(), [50, 60, 70]);

      // Verify model retrieved from repository has updated filePath
      final updatedModel = await reportRepo.getReportById('prof_1', 'report_1');
      expect(updatedModel, isNotNull);
      expect(updatedModel!.attachments.first.filePath, resolvedFile.path);
    });

    test('Preserves existing local file on disk without re-downloading', () async {
      final existingFile = File('${tempDir.path}/cached_doc.pdf');
      await existingFile.writeAsBytes([9, 8, 7]);

      final attachment = ConsultationAttachment(
        id: 'att_cached',
        name: 'cached_doc.pdf',
        sizeKB: 1,
        filePath: existingFile.path,
        fileUrl: 'remote_path',
      );

      final result = await consultationRepo.getOrDownloadAttachmentFile(
        profileId: 'prof_1',
        consultationId: 'c_1',
        attachment: attachment,
      );

      expect(result, isNotNull);
      expect(result!.path, existingFile.path);
      // No download calls made
      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      expect(bucketApi.storedFiles.isEmpty, isTrue);
    });

    test('Retrying an upload does not create duplicate objects or metadata', () async {
      final localFile = File('${tempDir.path}/unique_prescription.pdf');
      await localFile.writeAsBytes([1, 2, 3, 4, 5]);

      final storagePath = SupabaseStorageService.buildObjectPath(
        userId: 'user_123',
        parentId: 'consultation_1',
        fileName: 'unique_prescription.pdf',
        attachmentId: 'att_unique',
      );

      // First upload
      final path1 = await storageService.uploadFile(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: storagePath,
        file: localFile,
      );

      // Retry upload with same parameters
      final path2 = await storageService.uploadFile(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: storagePath,
        file: localFile,
      );

      expect(path1, path2);
      expect(path1, storagePath);

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      // Stored files map only contains exactly one entry (no duplicates created)
      expect(bucketApi.storedFiles.length, 1);
      expect(bucketApi.storedFiles.containsKey(storagePath), isTrue);

      // Save consultation with this attachment metadata
      final consultation = ConsultationModel(
        id: 'consultation_1',
        profileId: 'prof_1',
        doctorName: 'Dr. Watson',
        chiefComplaint: 'Headache',
        diagnosis: 'Migraine',
        visitDate: DateTime.now(),
        createdAt: DateTime.now(),
        attachments: [
          ConsultationAttachment(
            id: 'att_unique',
            name: 'unique_prescription.pdf',
            sizeKB: 1,
            filePath: localFile.path,
            fileUrl: storagePath,
          ),
        ],
      );

      await consultationRepo.saveConsultationModel('prof_1', consultation);

      // Simulate re-saving (retry of record update)
      await consultationRepo.saveConsultationModel('prof_1', consultation);

      final retrieved = await consultationRepo.getConsultationById('prof_1', 'consultation_1');
      expect(retrieved, isNotNull);
      // Ensure exactly 1 attachment in list (no duplicate metadata)
      expect(retrieved!.attachments.length, 1);
      expect(retrieved.attachments.first.id, 'att_unique');
      expect(retrieved.attachments.first.fileUrl, storagePath);
    });

    test('A successful upload followed by metadata failure can be recovered', () async {
      final localFile = File('${tempDir.path}/recovery_scan.png');
      await localFile.writeAsBytes([77, 88, 99]);

      final storagePath = SupabaseStorageService.buildObjectPath(
        userId: 'user_123',
        parentId: 'report_rec_1',
        fileName: 'recovery_scan.png',
        attachmentId: 'att_rec_1',
      );

      // 1. Storage upload succeeds
      final uploadedPath = await storageService.uploadFile(
        bucket: SupabaseStorageService.reportsBucket,
        storagePath: storagePath,
        file: localFile,
      );
      expect(uploadedPath, storagePath);

      // 2. Local file remains intact on disk
      expect(localFile.existsSync(), isTrue);

      // 3. Simulated metadata failure: Hive save is initially interrupted or aborted
      // Local report record still has fileUrl: null or old state
      final reportWithoutRemoteUrl = ReportModel(
        id: 'report_rec_1',
        profileId: 'prof_1',
        title: 'Blood Panel',
        category: 'LAB TEST',
        date: DateTime.now(),
        attachments: [
          ReportAttachmentModel(
            id: 'att_rec_1',
            name: 'recovery_scan.png',
            size: '1 KB',
            filePath: localFile.path,
            fileUrl: null, // Metadata update failed
          ),
        ],
      );
      await reportRepo.saveReport('prof_1', reportWithoutRemoteUrl);

      // 4. Recovery: Subsequent reconciliation associates the uploaded remote path with the metadata
      final recoveredReport = reportWithoutRemoteUrl.copyWith(
        attachments: [
          reportWithoutRemoteUrl.attachments.first.copyWith(
            fileUrl: storagePath,
          ),
        ],
      );
      await reportRepo.saveReport('prof_1', recoveredReport);

      // 5. Verification: Metadata successfully stores remote path, and file on disk is preserved
      final verified = await reportRepo.getReportById('prof_1', 'report_rec_1');
      expect(verified, isNotNull);
      expect(verified!.attachments.first.fileUrl, storagePath);
      expect(verified.attachments.first.filePath, localFile.path);
      expect(File(verified.attachments.first.filePath!).existsSync(), isTrue);
    });
  });
}
