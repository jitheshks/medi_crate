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

class _StagedFailingStorageService extends SupabaseStorageService {
  final SupabaseClient liveClient;
  bool injectFailure = true;
  int deletedCount = 0;

  _StagedFailingStorageService({required this.liveClient})
      : super(customClient: liveClient);

  @override
  Future<void> deleteAllUserFiles({required String userId}) async {
    final cleanUserId = userId.trim();
    for (final bucket in [
      SupabaseStorageService.avatarsBucket,
      SupabaseStorageService.consultationsBucket,
      SupabaseStorageService.reportsBucket,
    ]) {
      final rootItems = await liveClient.storage.from(bucket).list(path: cleanUserId);
      if (rootItems.isEmpty) continue;

      final List<String> pathsToDelete = [];
      for (final item in rootItems) {
        if (item.metadata == null || item.id == null) {
          final subPath = '$cleanUserId/${item.name}';
          final subItems = await liveClient.storage.from(bucket).list(path: subPath);
          for (final subItem in subItems) {
            pathsToDelete.add('$subPath/${subItem.name}');
          }
        } else {
          pathsToDelete.add('$cleanUserId/${item.name}');
        }
      }

      for (final path in pathsToDelete) {
        if (injectFailure && deletedCount == 1) {
          throw const StorageOperationException(
            'Simulated network failure midway through storage purge',
          );
        }
        await liveClient.storage.from(bucket).remove([path]);
        deletedCount++;
      }
    }
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

  setUpAll(() {
    adminClient = SupabaseClient(supabaseUrl, serviceRoleKey);
  });

  group('Implementation 5.6: Account Deletion Storage Cleanup & Safety Tests', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Account with no Storage objects
    // -------------------------------------------------------------------------
    test('1. Account with no Storage objects deletes cleanly', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_nostorage_$ts@medicrate.test';

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

      // Verify primary profile auto-created by trigger
      final profiles = await client.from('profiles').select().eq('user_id', userId);
      expect(profiles, isNotEmpty);
      expect(profiles.first['is_primary'], isTrue);

      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify user deleted in auth.users
      final userCheck = await adminClient.from('profiles').select().eq('user_id', userId);
      expect(userCheck, isEmpty, reason: 'Cascade must delete public.profiles');

      expect(
        () async => await adminClient.auth.admin.getUserById(userId),
        throwsA(isA<AuthException>()),
        reason: 'User must be permanently removed from auth.users',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 2 & 3: Account with avatar, consultation and report attachments
    // Verification that actual Storage files are removed, not merely metadata rows
    // -------------------------------------------------------------------------
    test('2 & 3. Account with avatar, consultation, report attachments purges physical files and DB', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_multi_$ts@medicrate.test';

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

      final profiles = await client.from('profiles').select().eq('user_id', userId);
      final profileId = profiles.first['id'] as String;

      // 1. Create parent records in database
      final consultId = UuidUtils.generateV4();
      await client.from('consultations').insert({
        'id': consultId,
        'user_id': userId,
        'profile_id': profileId,
        'doctor_name': 'Dr. Marcus Vance',
        'chief_complaint': 'Routine Checkup',
        'diagnosis': 'Healthy',
        'visit_date': '2026-11-14',
      });

      final reportId = UuidUtils.generateV4();
      await client.from('reports').insert({
        'id': reportId,
        'user_id': userId,
        'profile_id': profileId,
        'title': 'Metabolic Panel',
        'category': 'LAB TEST',
        'report_date': '2026-11-14',
      });

      // 2. Upload actual files to Storage API across all 3 buckets
      final avatarPath = '$userId/avatar.jpg';
      final consultPath = '$userId/$consultId/notes.pdf';
      final reportPath = '$userId/$reportId/lab.pdf';

      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final pdfBytes = Uint8List.fromList(List<int>.generate(128, (i) => i % 256));

      await client.storage.from('avatars').uploadBinary(
            avatarPath,
            jpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await client.storage.from('consultations').uploadBinary(
            consultPath,
            pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );
      await client.storage.from('reports').uploadBinary(
            reportPath,
            pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      // Verify files are downloadable via Storage API
      final downAvatar = await client.storage.from('avatars').download(avatarPath);
      expect(downAvatar.length, equals(jpgBytes.length));
      final downConsult = await client.storage.from('consultations').download(consultPath);
      expect(downConsult.length, equals(pdfBytes.length));
      final downReport = await client.storage.from('reports').download(reportPath);
      expect(downReport.length, equals(pdfBytes.length));

      // 3. Delete account
      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // 4. Verify actual Storage files are purged (attempting download throws StorageException)
      expect(
        () async => await adminClient.storage.from('avatars').download(avatarPath),
        throwsA(isA<StorageException>()),
        reason: 'Physical avatar file must be removed from storage',
      );
      expect(
        () async => await adminClient.storage.from('consultations').download(consultPath),
        throwsA(isA<StorageException>()),
        reason: 'Physical consultation file must be removed from storage',
      );
      expect(
        () async => await adminClient.storage.from('reports').download(reportPath),
        throwsA(isA<StorageException>()),
        reason: 'Physical report file must be removed from storage',
      );

      // 5. Verify database records are cascade-deleted
      final consultCheck = await adminClient.from('consultations').select().eq('id', consultId);
      expect(consultCheck, isEmpty);
      final reportCheck = await adminClient.from('reports').select().eq('id', reportId);
      expect(reportCheck, isEmpty);
      final profileCheck = await adminClient.from('profiles').select().eq('user_id', userId);
      expect(profileCheck, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Partial Storage deletion followed by failure
    // -------------------------------------------------------------------------
    test('4. Partial Storage deletion failure preserves database records and user account', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_partial_$ts@medicrate.test';

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

      final profiles = await client.from('profiles').select().eq('user_id', userId);
      final profileId = profiles.first['id'] as String;

      final reportId = UuidUtils.generateV4();
      await client.from('reports').insert({
        'id': reportId,
        'user_id': userId,
        'profile_id': profileId,
        'title': 'Biopsy Report',
        'category': 'LAB TEST',
        'report_date': '2026-11-14',
      });

      // Upload 2 files: one avatar and one report
      final avatarPath = '$userId/avatar.jpg';
      final reportPath = '$userId/$reportId/biopsy.pdf';

      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final pdfBytes = Uint8List.fromList(List<int>.generate(64, (i) => i));

      await client.storage.from('avatars').uploadBinary(
            avatarPath,
            jpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await client.storage.from('reports').uploadBinary(
            reportPath,
            pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      // Staged storage fails on the second file
      final stagedStorage = _StagedFailingStorageService(liveClient: client);
      final authDataSource = SupabaseAuthRemoteDataSource(
        client,
        customStorageService: stagedStorage,
      );

      // Attempt account deletion: must fail with ServerException
      await expectLater(
        () => authDataSource.deleteAccount(currentPassword: testPassword),
        throwsA(isA<ServerException>()),
      );

      // Verify intermediate state:
      // Object 1 (avatar) was deleted, but Object 2 (report) still remains
      expect(stagedStorage.deletedCount, equals(1));
      final remReport = await client.storage.from('reports').download(reportPath);
      expect(remReport.length, equals(pdfBytes.length), reason: 'Second file must remain');

      // CRITICAL INVARIANT: Database records and user account MUST REMAIN!
      final dbReport = await client.from('reports').select().eq('id', reportId);
      expect(dbReport, isNotEmpty, reason: 'Database report row must not be deleted on partial storage failure');

      final dbProfile = await client.from('profiles').select().eq('user_id', userId);
      expect(dbProfile, isNotEmpty, reason: 'Profile must not be deleted on partial storage failure');

      // Precondition Check: Direct RPC call must be rejected because active storage objects remain!
      expect(
        () async => await client.rpc('delete_user_account'),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('Precondition Failed: Active storage objects remain'),
          ),
        ),
        reason: 'RPC must reject deletion when active storage objects remain',
      );

      // Clean up user for subsequent tests
      adminClient.auth.admin.deleteUser(userId).catchError((_) {});
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Retry after Storage becomes available
    // -------------------------------------------------------------------------
    test('5. Retry after Storage becomes available cleanly finishes deletion', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_retry_$ts@medicrate.test';

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

      final avatarPath = '$userId/avatar.jpg';
      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      await client.storage.from('avatars').uploadBinary(
            avatarPath,
            jpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final stagedStorage = _StagedFailingStorageService(liveClient: client);
      final authDataSource = SupabaseAuthRemoteDataSource(
        client,
        customStorageService: stagedStorage,
      );

      // Force failure on 1st file
      stagedStorage.injectFailure = true;
      stagedStorage.deletedCount = 1; // triggers immediate throw

      await expectLater(
        () => authDataSource.deleteAccount(currentPassword: testPassword),
        throwsA(isA<ServerException>()),
      );

      // User and file still exist
      final checkFile = await client.storage.from('avatars').download(avatarPath);
      expect(checkFile, isNotEmpty);

      // Now retry with failure cleared
      stagedStorage.injectFailure = false;
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Both file and user are now completely gone
      expect(
        () async => await adminClient.storage.from('avatars').download(avatarPath),
        throwsA(isA<StorageException>()),
      );
      final dbCheck = await adminClient.from('profiles').select().eq('user_id', userId);
      expect(dbCheck, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Database failure and recoverable cleanup behavior
    // -------------------------------------------------------------------------
    test('6. Database failure after storage cleanup is recoverable on retry', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_dbfail_$ts@medicrate.test';

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

      final avatarPath = '$userId/avatar.jpg';
      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      await client.storage.from('avatars').uploadBinary(
            avatarPath,
            jpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      // Storage cleanup runs directly
      final storageService = SupabaseStorageService(customClient: client);
      await storageService.deleteAllUserFiles(userId: userId);

      // Verify file is gone from storage
      expect(
        () async => await adminClient.storage.from('avatars').download(avatarPath),
        throwsA(isA<StorageException>()),
      );

      // Account in DB still exists (recoverable state)
      final profileMid = await client.from('profiles').select().eq('user_id', userId);
      expect(profileMid, isNotEmpty);

      // Subsequent deleteAccount call succeeds (storage is already empty; RPC succeeds)
      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      final profileFinal = await adminClient.from('profiles').select().eq('user_id', userId);
      expect(profileFinal, isEmpty, reason: 'Database row must be deleted on retry');
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Repeated deletion requests (idempotency)
    // -------------------------------------------------------------------------
    test('7. Repeated deletion requests fail safely without corrupting state', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'del_repeat_$ts@medicrate.test';

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

      final authDataSource = SupabaseAuthRemoteDataSource(client);
      await authDataSource.deleteAccount(currentPassword: testPassword);

      // Verify user 1 is deleted in DB
      expect(await adminClient.from('profiles').select().eq('user_id', userId), isEmpty);

      // Session is now terminated: second call throws UnauthorizedException
      await expectLater(
        () => authDataSource.deleteAccount(currentPassword: testPassword),
        throwsA(isA<UnauthorizedException>()),
        reason: 'Repeated deletion without session must throw UnauthorizedException',
      );

      // Calling RPC directly without session throws 42501 permission denied
      expect(
        () async => await client.rpc('delete_user_account'),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.code,
            'code',
            equals('42501'),
          ),
        ),
        reason: 'Unauthenticated execution must be rejected at PostgreSQL grant level (42501)',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Cross-user account deletion rejection
    // -------------------------------------------------------------------------
    test('8. Cross-user account deletion is strictly rejected', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email1 = 'del_user1_$ts@medicrate.test';
      final email2 = 'del_user2_$ts@medicrate.test';

      final res1 = await adminClient.auth.admin.createUser(
        AdminUserAttributes(email: email1, password: testPassword, emailConfirm: true),
      );
      final user1Id = res1.user!.id;

      final res2 = await adminClient.auth.admin.createUser(
        AdminUserAttributes(email: email2, password: testPassword, emailConfirm: true),
      );
      final user2Id = res2.user!.id;

      final client1 = SupabaseClient(supabaseUrl, anonKey);
      await client1.auth.signInWithPassword(email: email1, password: testPassword);

      final client2 = SupabaseClient(supabaseUrl, anonKey);
      await client2.auth.signInWithPassword(email: email2, password: testPassword);

      // User 1 uploads an avatar
      final u1Avatar = '$user1Id/avatar.jpg';
      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      await client1.storage.from('avatars').uploadBinary(
            u1Avatar,
            jpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      // User 2 attempts to delete User 1's avatar via Storage API: rejected by Storage RLS
      final delRes = await client2.storage.from('avatars').remove([u1Avatar]);
      expect(delRes, isEmpty, reason: 'Storage RLS must reject cross-user file removal');

      // User 1's file is still intact
      final checkFile = await client1.storage.from('avatars').download(u1Avatar);
      expect(checkFile, isNotEmpty);

      // User 2 deletes their own account
      final u2AuthDS = SupabaseAuthRemoteDataSource(client2);
      await u2AuthDS.deleteAccount(currentPassword: testPassword);

      // Verify User 2 is deleted from database
      expect(await adminClient.from('profiles').select().eq('user_id', user2Id), isEmpty);

      // User 1 is completely untouched
      final u1Profile = await client1.from('profiles').select().eq('user_id', user1Id);
      expect(u1Profile, isNotEmpty);
      final u1File = await client1.storage.from('avatars').download(u1Avatar);
      expect(u1File.length, equals(jpgBytes.length));

      // Clean up User 1
      final u1AuthDS = SupabaseAuthRemoteDataSource(client1);
      await u1AuthDS.deleteAccount(currentPassword: testPassword);
    });
  });
}
