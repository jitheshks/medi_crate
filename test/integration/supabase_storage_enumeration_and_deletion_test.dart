import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

/// Custom storage service wrapper to simulate batch removal failures.
class _FailingBatchStorageService extends SupabaseStorageService {
  final SupabaseClient liveClient;
  bool shouldFailOnBatch = false;
  int failAfterBatches = 1;
  int batchCount = 0;

  _FailingBatchStorageService({required this.liveClient})
      : super(customClient: liveClient);

  @override
  Future<void> deleteAllUserFiles({required String userId}) async {
    final cleanUserId = userId.trim();
    for (final bucket in [
      SupabaseStorageService.avatarsBucket,
      SupabaseStorageService.consultationsBucket,
      SupabaseStorageService.reportsBucket,
    ]) {
      final paths = await collectUserFilePaths(
        bucket: bucket,
        userId: cleanUserId,
      );
      if (paths.isEmpty) continue;

      const batchSize = 50;
      for (int i = 0; i < paths.length; i += batchSize) {
        batchCount++;
        if (shouldFailOnBatch && batchCount > failAfterBatches) {
          throw const StorageOperationException(
            'Simulated network failure midway through batch deletion',
          );
        }
        final end = (i + batchSize < paths.length) ? i + batchSize : paths.length;
        final chunk = paths.sublist(i, end);
        await liveClient.storage.from(bucket).remove(chunk);
      }
    }
  }
}

/// Custom storage service wrapper to simulate listing failure.
class _FailingListStorageService extends SupabaseStorageService {
  final SupabaseClient liveClient;
  bool shouldFailOnList = true;

  _FailingListStorageService({required this.liveClient})
      : super(customClient: liveClient);

  @override
  Future<void> deleteAllUserFiles({required String userId}) async {
    if (shouldFailOnList) {
      throw const StorageOperationException(
        'Simulated storage listing failure: connection timed out during directory enumeration',
      );
    }
    await super.deleteAllUserFiles(userId: userId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  const supabaseUrl = 'http://127.0.0.1:54421';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
  const serviceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

  late SupabaseClient adminClient;
  const testPassword = 'Password123!';
  final dummyJpgBytes =
      Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
  final dummyPdfBytes =
      Uint8List.fromList(List<int>.generate(128, (i) => i % 256));

  setUpAll(() {
    adminClient = SupabaseClient(supabaseUrl, serviceRoleKey);
  });

  group('Implementation 5.7: Complete Storage Enumeration & Account Deletion Verification', () {
    // -------------------------------------------------------------------------
    // Test 1: More than 100 files in one folder
    // -------------------------------------------------------------------------
    test('1. More than 100 files in one folder are completely enumerated and deleted', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_100single_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      // Upload 105 files in a single folder in avatars: $userId/avatar_XX.jpg
      // RLS allows array_length(foldername) = 1 for primary profile
      const fileCount = 105;
      final filePaths = <String>[];
      for (int i = 0; i < fileCount; i++) {
        filePaths.add('$userId/avatar_$i.jpg');
      }

      // Upload in concurrent batches of 15
      for (int i = 0; i < filePaths.length; i += 15) {
        final end = (i + 15 < filePaths.length) ? i + 15 : filePaths.length;
        final batch = filePaths.sublist(i, end);
        await Future.wait(batch.map((path) => client.storage
            .from(SupabaseStorageService.avatarsBucket)
            .uploadBinary(
              path,
              dummyJpgBytes,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg', upsert: true),
            )));
      }

      // Verify files can be downloaded before deletion
      final sampleBefore1 = await client.storage
          .from(SupabaseStorageService.avatarsBucket)
          .download(filePaths[0]);
      final sampleBefore2 = await client.storage
          .from(SupabaseStorageService.avatarsBucket)
          .download(filePaths[50]);
      final sampleBefore3 = await client.storage
          .from(SupabaseStorageService.avatarsBucket)
          .download(filePaths[104]);
      expect(sampleBefore1.length, equals(dummyJpgBytes.length));
      expect(sampleBefore2.length, equals(dummyJpgBytes.length));
      expect(sampleBefore3.length, equals(dummyJpgBytes.length));

      // Execute account deletion (triggers Storage API cleanup -> precondition -> RPC)
      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify actual Storage downloads FAIL for all tested samples
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(filePaths[0]),
        throwsA(isA<StorageException>()),
        reason: 'Physical file at index 0 must be purged',
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(filePaths[50]),
        throwsA(isA<StorageException>()),
        reason: 'Physical file at index 50 must be purged beyond initial 100-item page',
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(filePaths[104]),
        throwsA(isA<StorageException>()),
        reason: 'Physical file at index 104 must be purged',
      );

      // Verify database records cascade-deleted
      final profileCheck =
          await adminClient.from('profiles').select().eq('user_id', userId);
      expect(profileCheck, isEmpty);
      expect(
        () async => await adminClient.auth.admin.getUserById(userId),
        throwsA(isA<AuthException>()),
      );
    });

    // -------------------------------------------------------------------------
    // Test 2: More than 100 files across multiple pages
    // -------------------------------------------------------------------------
    test('2. More than 100 files across multiple pages are enumerated and purged', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_multipage_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      final profiles =
          await client.from('profiles').select().eq('user_id', userId);
      final profileId = profiles.first['id'] as String;

      // Create consultation parent record
      final consultId = UuidUtils.generateV4();
      await client.from('consultations').insert({
        'id': consultId,
        'user_id': userId,
        'profile_id': profileId,
        'doctor_name': 'Dr. Multi Page',
        'chief_complaint': 'Pagination Verification',
        'diagnosis': 'Healthy',
        'visit_date': '2026-11-15',
      });

      // Upload 110 files in consultations: $userId/$consultId/doc_XX.pdf
      // Requires page 1 (100 files) + page 2 (10 files)
      const fileCount = 110;
      final filePaths = <String>[];
      for (int i = 0; i < fileCount; i++) {
        filePaths.add('$userId/$consultId/doc_$i.pdf');
      }

      for (int i = 0; i < filePaths.length; i += 15) {
        final end = (i + 15 < filePaths.length) ? i + 15 : filePaths.length;
        final batch = filePaths.sublist(i, end);
        await Future.wait(batch.map((path) => client.storage
            .from(SupabaseStorageService.consultationsBucket)
            .uploadBinary(
              path,
              dummyPdfBytes,
              fileOptions:
                  const FileOptions(contentType: 'application/pdf', upsert: true),
            )));
      }

      // Verify downloads before deletion
      final downFirst = await client.storage
          .from(SupabaseStorageService.consultationsBucket)
          .download(filePaths[0]);
      final downPage2 = await client.storage
          .from(SupabaseStorageService.consultationsBucket)
          .download(filePaths[105]);
      expect(downFirst.length, equals(dummyPdfBytes.length));
      expect(downPage2.length, equals(dummyPdfBytes.length));

      // Perform account deletion
      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify physical downloads fail
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(filePaths[0]),
        throwsA(isA<StorageException>()),
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(filePaths[99]),
        throwsA(isA<StorageException>()),
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(filePaths[105]),
        throwsA(isA<StorageException>()),
      );

      // Verify consultation DB row deleted
      final dbConsult =
          await adminClient.from('consultations').select().eq('id', consultId);
      expect(dbConsult, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 3: Nested folders containing more than 100 files in total
    // -------------------------------------------------------------------------
    test('3. Nested folders containing more than 100 files in total are recursively traversed and purged', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_nested_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      final profiles =
          await client.from('profiles').select().eq('user_id', userId);
      final profileId = profiles.first['id'] as String;

      // Create 3 consultations to establish 3 subdirectories under $userId:
      // $userId/$consultId1 (35 files)
      // $userId/$consultId2 (35 files)
      // $userId/$consultId3 (35 files)
      // Total: 105 files across 3 distinct subdirectories
      final consultIds = [
        UuidUtils.generateV4(),
        UuidUtils.generateV4(),
        UuidUtils.generateV4(),
      ];

      for (int i = 0; i < 3; i++) {
        await client.from('consultations').insert({
          'id': consultIds[i],
          'user_id': userId,
          'profile_id': profileId,
          'doctor_name': 'Dr. Subfolder $i',
          'chief_complaint': 'Nested Traversal Test',
          'diagnosis': 'Healthy',
          'visit_date': '2026-11-15',
        });
      }

      final filePaths = <String>[];
      for (final cid in consultIds) {
        for (int i = 0; i < 35; i++) {
          filePaths.add('$userId/$cid/doc_$i.pdf');
        }
      }
      expect(filePaths.length, equals(105));

      for (int i = 0; i < filePaths.length; i += 15) {
        final end = (i + 15 < filePaths.length) ? i + 15 : filePaths.length;
        final batch = filePaths.sublist(i, end);
        await Future.wait(batch.map((path) => client.storage
            .from(SupabaseStorageService.consultationsBucket)
            .uploadBinary(
              path,
              dummyPdfBytes,
              fileOptions:
                  const FileOptions(contentType: 'application/pdf', upsert: true),
            )));
      }

      // Verify downloads before deletion from each subfolder
      final downSub1 = await client.storage
          .from(SupabaseStorageService.consultationsBucket)
          .download(filePaths[10]);
      final downSub2 = await client.storage
          .from(SupabaseStorageService.consultationsBucket)
          .download(filePaths[45]);
      final downSub3 = await client.storage
          .from(SupabaseStorageService.consultationsBucket)
          .download(filePaths[80]);
      expect(downSub1.length, equals(dummyPdfBytes.length));
      expect(downSub2.length, equals(dummyPdfBytes.length));
      expect(downSub3.length, equals(dummyPdfBytes.length));

      // Perform account deletion
      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify downloads fail across all subfolder levels
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(filePaths[10]),
        throwsA(isA<StorageException>()),
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(filePaths[45]),
        throwsA(isA<StorageException>()),
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(filePaths[80]),
        throwsA(isA<StorageException>()),
      );

      final profileCheck =
          await adminClient.from('profiles').select().eq('user_id', userId);
      expect(profileCheck, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 4: Files distributed across all three buckets
    // -------------------------------------------------------------------------
    test('4. Files distributed across all three buckets (avatars, consultations, reports) are purged', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_allthree_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      final profiles =
          await client.from('profiles').select().eq('user_id', userId);
      final profileId = profiles.first['id'] as String;

      // 1. Avatars bucket files
      final avatarPaths = [
        '$userId/avatar_main.jpg',
        '$userId/avatar_alt.png',
      ];
      for (final p in avatarPaths) {
        await client.storage.from(SupabaseStorageService.avatarsBucket).uploadBinary(
              p,
              dummyJpgBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      }

      // 2. Consultations bucket files
      final consultId = UuidUtils.generateV4();
      await client.from('consultations').insert({
        'id': consultId,
        'user_id': userId,
        'profile_id': profileId,
        'doctor_name': 'Dr. Multi Bucket',
        'chief_complaint': 'Triple Bucket Purge',
        'diagnosis': 'Healthy',
        'visit_date': '2026-11-15',
      });
      final consultPaths = [
        '$userId/$consultId/summary.pdf',
        '$userId/$consultId/chart.pdf',
      ];
      for (final p in consultPaths) {
        await client.storage
            .from(SupabaseStorageService.consultationsBucket)
            .uploadBinary(
              p,
              dummyPdfBytes,
              fileOptions: const FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );
      }

      // 3. Reports bucket files
      final reportId = UuidUtils.generateV4();
      await client.from('reports').insert({
        'id': reportId,
        'user_id': userId,
        'profile_id': profileId,
        'title': 'Lipid Panel',
        'category': 'LAB TEST',
        'report_date': '2026-11-15',
      });
      final reportPaths = [
        '$userId/$reportId/bloodwork.pdf',
        '$userId/$reportId/specimen.pdf',
      ];
      for (final p in reportPaths) {
        await client.storage.from(SupabaseStorageService.reportsBucket).uploadBinary(
              p,
              dummyPdfBytes,
              fileOptions: const FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );
      }

      // Verify downloads work across all 3 buckets
      expect(
        (await client.storage
                .from(SupabaseStorageService.avatarsBucket)
                .download(avatarPaths[0]))
            .length,
        equals(dummyJpgBytes.length),
      );
      expect(
        (await client.storage
                .from(SupabaseStorageService.consultationsBucket)
                .download(consultPaths[0]))
            .length,
        equals(dummyPdfBytes.length),
      );
      expect(
        (await client.storage
                .from(SupabaseStorageService.reportsBucket)
                .download(reportPaths[0]))
            .length,
        equals(dummyPdfBytes.length),
      );

      // Perform account deletion
      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify physical downloads fail across all 3 buckets
      for (final p in avatarPaths) {
        expect(
          () async => await adminClient.storage
              .from(SupabaseStorageService.avatarsBucket)
              .download(p),
          throwsA(isA<StorageException>()),
        );
      }
      for (final p in consultPaths) {
        expect(
          () async => await adminClient.storage
              .from(SupabaseStorageService.consultationsBucket)
              .download(p),
          throwsA(isA<StorageException>()),
        );
      }
      for (final p in reportPaths) {
        expect(
          () async => await adminClient.storage
              .from(SupabaseStorageService.reportsBucket)
              .download(p),
          throwsA(isA<StorageException>()),
        );
      }

      // Verify DB records deleted
      expect(
        await adminClient
            .from('consultations')
            .select()
            .eq('id', consultId),
        isEmpty,
      );
      expect(
        await adminClient.from('reports').select().eq('id', reportId),
        isEmpty,
      );
      expect(
        await adminClient.from('profiles').select().eq('user_id', userId),
        isEmpty,
      );
    });

    // -------------------------------------------------------------------------
    // Test 5: Partial batch deletion failure and retry
    // -------------------------------------------------------------------------
    test('5. Partial batch deletion failure preserves DB and retry completes deletion', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_batchretry_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      // Upload 105 files in avatars across two 50-item batches
      final filePaths = <String>[];
      for (int i = 0; i < 105; i++) {
        filePaths.add('$userId/avatar_$i.jpg');
      }

      for (int i = 0; i < filePaths.length; i += 15) {
        final end = (i + 15 < filePaths.length) ? i + 15 : filePaths.length;
        final batch = filePaths.sublist(i, end);
        await Future.wait(batch.map((path) => client.storage
            .from(SupabaseStorageService.avatarsBucket)
            .uploadBinary(
              path,
              dummyJpgBytes,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg', upsert: true),
            )));
      }

      // Use failing batch storage service: fails after 1st batch (50 files deleted, 55 remaining)
      final failingStorage = _FailingBatchStorageService(liveClient: client)
        ..shouldFailOnBatch = true
        ..failAfterBatches = 1;

      final authDataSource = SupabaseAuthRemoteDataSource(
        client,
        customStorageService: failingStorage,
      );

      // Account deletion must fail with ServerException
      await expectLater(
        () => authDataSource.deleteAccount(currentPassword: testPassword),
        throwsA(isA<ServerException>()),
      );

      // Invariant: User and DB profile remain intact
      final profileMid =
          await client.from('profiles').select().eq('user_id', userId);
      expect(profileMid, isNotEmpty, reason: 'Profile must not be deleted on batch failure');

      // Precondition Check: Direct RPC must fail because 55 active storage objects remain!
      expect(
        () async => await client.rpc('delete_user_account'),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('Precondition Failed: Active storage objects remain'),
          ),
        ),
        reason: 'RPC precondition must block deletion when storage objects remain',
      );

      // Verification: remaining files can still be downloaded
      final sampleRemaining = await client.storage
          .from(SupabaseStorageService.avatarsBucket)
          .download(filePaths[90]);
      expect(sampleRemaining.length, equals(dummyJpgBytes.length));

      // Now clear simulated failure and RETRY account deletion
      failingStorage.shouldFailOnBatch = false;
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify all files are now gone
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(filePaths[0]),
        throwsA(isA<StorageException>()),
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(filePaths[90]),
        throwsA(isA<StorageException>()),
      );

      // Verify DB records and auth user are deleted
      final profileFinal =
          await adminClient.from('profiles').select().eq('user_id', userId);
      expect(profileFinal, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 6: Listing failure prevents account deletion
    // -------------------------------------------------------------------------
    test('6. Listing failure propagates and strictly prevents account deletion', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_listfail_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      // Upload an avatar file
      final avatarPath = '$userId/profile.jpg';
      await client.storage.from(SupabaseStorageService.avatarsBucket).uploadBinary(
            avatarPath,
            dummyJpgBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      // Use storage service with simulated listing failure
      final failingListStorage = _FailingListStorageService(liveClient: client)
        ..shouldFailOnList = true;

      final authDataSource = SupabaseAuthRemoteDataSource(
        client,
        customStorageService: failingListStorage,
      );

      // Account deletion must fail with ServerException
      await expectLater(
        () => authDataSource.deleteAccount(currentPassword: testPassword),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('Failed to purge account storage files'),
        )),
      );

      // Verify physical file was NOT deleted and is still downloadable
      final checkFile = await client.storage
          .from(SupabaseStorageService.avatarsBucket)
          .download(avatarPath);
      expect(checkFile.length, equals(dummyJpgBytes.length));

      // Verify DB profile and user are preserved
      final profileCheck =
          await client.from('profiles').select().eq('user_id', userId);
      expect(profileCheck, isNotEmpty);

      // Precondition Check: Direct RPC must also fail
      expect(
        () async => await client.rpc('delete_user_account'),
        throwsA(isA<PostgrestException>()),
      );

      // Clean up test user
      adminClient.auth.admin.deleteUser(userId).catchError((_) {});
      adminClient.storage.from(SupabaseStorageService.avatarsBucket).remove([avatarPath]);
    });

    // -------------------------------------------------------------------------
    // Test 7: Final RPC precondition confirms no owned Storage objects remain
    // -------------------------------------------------------------------------
    test('7. Database precondition RPC enforces zero active storage objects before permitting account removal', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_precond_$ts@medicrate.test';

      final userRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userId = userRes.user!.id;

      final client = SupabaseClient(supabaseUrl, anonKey);
      await client.auth.signInWithPassword(email: email, password: testPassword);

      // Upload file to avatars
      final avatarPath = '$userId/avatar_check.jpg';
      await client.storage.from(SupabaseStorageService.avatarsBucket).uploadBinary(
            avatarPath,
            dummyJpgBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      // Step A: Attempt RPC execution directly without Storage purge
      expect(
        () async => await client.rpc('delete_user_account'),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('Precondition Failed: Active storage objects remain'),
          ),
        ),
        reason: 'Database RPC must strictly reject execution when storage objects exist',
      );

      // Verify user and profile still exist
      final userBefore = await adminClient.auth.admin.getUserById(userId);
      expect(userBefore.user, isNotNull);

      // Step B: Purge storage via Supabase Storage API
      final storageService = SupabaseStorageService(customClient: client);
      await storageService.deleteAllUserFiles(userId: userId);

      // Verify file is gone from storage
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(avatarPath),
        throwsA(isA<StorageException>()),
      );

      // Step C: Execute RPC now that Storage is clean
      await expectLater(
        client.rpc('delete_user_account'),
        completes,
        reason: 'RPC precondition must pass once storage objects have been purged',
      );

      // Step D: Confirm storage listing for this user returns empty across all buckets
      for (final bucket in [
        SupabaseStorageService.avatarsBucket,
        SupabaseStorageService.consultationsBucket,
        SupabaseStorageService.reportsBucket,
      ]) {
        final listCheck =
            await adminClient.storage.from(bucket).list(path: userId);
        expect(listCheck, isEmpty);
      }

      // Confirm user is deleted from auth.users
      expect(
        () async => await adminClient.auth.admin.getUserById(userId),
        throwsA(isA<AuthException>()),
      );
    });

    // -------------------------------------------------------------------------
    // Test 8: Cross-user objects remain untouched
    // -------------------------------------------------------------------------
    test('8. Cross-user isolation: User A deletion leaves User B files completely intact', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final emailA = 'del_usera_$ts@medicrate.test';
      final emailB = 'del_userb_$ts@medicrate.test';

      // Create User A
      final userARes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: emailA,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userAId = userARes.user!.id;

      // Create User B
      final userBRes = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: emailB,
          password: testPassword,
          emailConfirm: true,
        ),
      );
      final userBId = userBRes.user!.id;

      final clientA = SupabaseClient(supabaseUrl, anonKey);
      await clientA.auth.signInWithPassword(email: emailA, password: testPassword);

      final clientB = SupabaseClient(supabaseUrl, anonKey);
      await clientB.auth.signInWithPassword(email: emailB, password: testPassword);

      final profileA =
          (await clientA.from('profiles').select().eq('user_id', userAId)).first;
      final profileB =
          (await clientB.from('profiles').select().eq('user_id', userBId)).first;

      // User A files
      final avatarA = '$userAId/avatar.jpg';
      final consultAId = UuidUtils.generateV4();
      await clientA.from('consultations').insert({
        'id': consultAId,
        'user_id': userAId,
        'profile_id': profileA['id'],
        'doctor_name': 'Dr. Vance A',
        'chief_complaint': 'User A Checkup',
        'diagnosis': 'Healthy',
        'visit_date': '2026-11-15',
      });
      final consultPathA = '$userAId/$consultAId/notes.pdf';

      await clientA.storage.from(SupabaseStorageService.avatarsBucket).uploadBinary(
            avatarA,
            dummyJpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await clientA.storage
          .from(SupabaseStorageService.consultationsBucket)
          .uploadBinary(
            consultPathA,
            dummyPdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      // User B files
      final avatarB = '$userBId/avatar.jpg';
      final consultBId = UuidUtils.generateV4();
      await clientB.from('consultations').insert({
        'id': consultBId,
        'user_id': userBId,
        'profile_id': profileB['id'],
        'doctor_name': 'Dr. Vance B',
        'chief_complaint': 'User B Checkup',
        'diagnosis': 'Healthy',
        'visit_date': '2026-11-15',
      });
      final consultPathB = '$userBId/$consultBId/notes.pdf';

      await clientB.storage.from(SupabaseStorageService.avatarsBucket).uploadBinary(
            avatarB,
            dummyJpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await clientB.storage
          .from(SupabaseStorageService.consultationsBucket)
          .uploadBinary(
            consultPathB,
            dummyPdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      // Verify both users can download their files before deletion
      expect((await clientA.storage.from(SupabaseStorageService.avatarsBucket).download(avatarA)).length, equals(dummyJpgBytes.length));
      expect((await clientB.storage.from(SupabaseStorageService.avatarsBucket).download(avatarB)).length, equals(dummyJpgBytes.length));
      expect((await clientA.storage.from(SupabaseStorageService.consultationsBucket).download(consultPathA)).length, equals(dummyPdfBytes.length));
      expect((await clientB.storage.from(SupabaseStorageService.consultationsBucket).download(consultPathB)).length, equals(dummyPdfBytes.length));

      // User A deletes account
      final authDataSourceA = SupabaseAuthRemoteDataSource(clientA);
      await authDataSourceA.deleteAccount(currentPassword: testPassword);

      // Verify User A files are purged
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.avatarsBucket)
            .download(avatarA),
        throwsA(isA<StorageException>()),
      );
      expect(
        () async => await adminClient.storage
            .from(SupabaseStorageService.consultationsBucket)
            .download(consultPathA),
        throwsA(isA<StorageException>()),
      );
      expect(
        await adminClient.from('profiles').select().eq('user_id', userAId),
        isEmpty,
      );

      // CRITICAL VERIFICATION: User B files REMAIN COMPLETELY INTACT!
      final userBAvatarCheck = await clientB.storage
          .from(SupabaseStorageService.avatarsBucket)
          .download(avatarB);
      expect(userBAvatarCheck.length, equals(dummyJpgBytes.length),
          reason: 'User B avatar must remain downloadable');

      final userBConsultCheck = await clientB.storage
          .from(SupabaseStorageService.consultationsBucket)
          .download(consultPathB);
      expect(userBConsultCheck.length, equals(dummyPdfBytes.length),
          reason: 'User B consultation document must remain downloadable');

      // Verify User B DB records and auth session remain intact
      final userBProfileCheck =
          await clientB.from('profiles').select().eq('user_id', userBId);
      expect(userBProfileCheck, isNotEmpty);
      final userBConsultRecord =
          await clientB.from('consultations').select().eq('id', consultBId);
      expect(userBConsultRecord, isNotEmpty);

      // Clean up User B
      await adminClient.auth.admin.deleteUser(userBId).catchError((_) {});
      await adminClient.storage
          .from(SupabaseStorageService.avatarsBucket)
          .remove([avatarB])
          .catchError((_) => <FileObject>[]);
      await adminClient.storage
          .from(SupabaseStorageService.consultationsBucket)
          .remove([consultPathB])
          .catchError((_) => <FileObject>[]);
    });
  });
}
