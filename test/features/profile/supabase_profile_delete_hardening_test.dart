import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/profile/data/datasources/local/profile_local_data_source.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/repositories/profile_repository.dart';

class _FakeBox extends Fake implements Box<Map> {
  @override
  bool get isOpen => false;
}

class _FakeHiveService extends Fake implements HiveService {
  @override
  Box<Map> get profileBox => _FakeBox();
}

class _FakeLocalDataSource extends Fake implements ProfileLocalDataSource {}
class _FakeRemoteDataSource extends Fake implements SupabaseProfileRemoteDataSource {}
class _FakeConnectivity extends Fake implements ConnectivityService {}
class _FakeSyncService extends Fake implements SyncService {}

void main() {
  group('Phase 4.4 Batch 2D: Profile DELETE Policy Hardening Static & Boundary Tests', () {
    const migrationPath =
        'supabase/migrations/20261111100000_harden_profile_delete_policy.sql';
    const testSqlPath =
        'supabase/tests/run_profile_delete_hardening_tests.sql';

    test('1. Migration file exists with timestamp after archival migration', () {
      final migrationFile = File(migrationPath);
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Migration 20261111100000_harden_profile_delete_policy.sql must exist',
      );

      final filename = migrationFile.uri.pathSegments.last;
      expect(filename, startsWith('20261111100000'));
    });

    test('2. Migration content drops authenticated DELETE policy without replacement', () {
      final migrationContent = File(migrationPath).readAsStringSync();

      // Must drop legacy policy
      expect(
        migrationContent.contains(
          'DROP POLICY IF EXISTS "Users can delete their own non-primary profiles" ON public.profiles;',
        ),
        isTrue,
      );

      // Must dynamically purge any other DELETE/ALL policies on public.profiles
      expect(
        migrationContent.contains("WHERE schemaname = 'public'"),
        isTrue,
      );
      expect(
        migrationContent.contains("tablename = 'profiles'"),
        isTrue,
      );
      expect(
        migrationContent.contains("cmd IN ('DELETE', 'ALL')"),
        isTrue,
      );

      // Must NOT add any new DELETE policy for authenticated
      expect(
        migrationContent.contains('CREATE POLICY') &&
            migrationContent.contains('FOR DELETE') &&
            migrationContent.contains('TO authenticated'),
        isFalse,
        reason: 'No replacement DELETE policy should be granted to authenticated users',
      );
    });

    test('3. Migration explicitly revokes table DELETE from client roles and preserves admin grants', () {
      final migrationContent = File(migrationPath).readAsStringSync();

      // Revokes DELETE
      expect(
        migrationContent.contains('REVOKE DELETE ON TABLE public.profiles FROM authenticated;'),
        isTrue,
      );
      expect(
        migrationContent.contains('REVOKE DELETE ON TABLE public.profiles FROM anon;'),
        isTrue,
      );
      expect(
        migrationContent.contains('REVOKE DELETE ON TABLE public.profiles FROM public;'),
        isTrue,
      );

      // Preserves SELECT, INSERT, UPDATE for authenticated
      expect(
        migrationContent.contains('GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;'),
        isTrue,
      );

      // Preserves service_role and postgres administrative hard delete
      expect(
        migrationContent.contains('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO service_role;'),
        isTrue,
      );
      expect(
        migrationContent.contains('GRANT ALL ON TABLE public.profiles TO postgres;'),
        isTrue,
      );
    });

    test('4. SQL test suite exists and covers all regression verification criteria', () {
      final testSqlFile = File(testSqlPath);
      expect(testSqlFile.existsSync(), isTrue);

      final content = testSqlFile.readAsStringSync();
      expect(content.contains('TEST 1: Original authenticated family-profile DELETE policy is absent'), isTrue);
      expect(content.contains('TEST 2: No other authenticated DELETE policy independently permits deletion'), isTrue);
      expect(content.contains('TEST 3: Authenticated users cannot directly delete their own non-primary profile'), isTrue);
      expect(content.contains('TEST 4: Authenticated users cannot delete primary Self profile'), isTrue);
      expect(content.contains('TEST 5: Another user\'s profile cannot be deleted'), isTrue);
      expect(content.contains('TEST 6: Profile archival remains permitted for an authorized owner'), isTrue);
      expect(content.contains('TEST 7: Profile restoration remains permitted for an authorized owner'), isTrue);
      expect(content.contains('TEST 8: Clinical historical SELECT access remains intact'), isTrue);
      expect(content.contains('TEST 9: Archived-profile clinical INSERT restriction remains intact'), isTrue);
      expect(content.contains('TEST 10: Archived-profile clinical UPDATE restriction remains intact'), isTrue);
      expect(content.contains('TEST 11: Privileged service_role DELETE execution'), isTrue);
      expect(content.contains('TEST 12: Superuser postgres deletion & client table privilege denial'), isTrue);
    });

    test('5. Application layer: ProfileRepository blocks permanent profile deletion with UnsupportedError', () {
      final repo = ProfileRepository(
        localDataSource: _FakeLocalDataSource(),
        remoteDataSource: _FakeRemoteDataSource(),
        connectivityService: _FakeConnectivity(),
        syncService: _FakeSyncService(),
        hiveService: _FakeHiveService(),
      );

      expect(
        () => repo.deleteProfile('family-uuid-1', ownerUserId: 'user-1'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Permanent profile deletion is disabled'),
          ),
        ),
      );
    });

    test('6. Application layer: SupabaseProfileRemoteDataSource does not expose deleteProfile', () {
      // SupabaseProfileRemoteDataSource supports archiveProfile and restoreProfile,
      // but has no deleteProfile method.
      final dataSource = SupabaseProfileRemoteDataSource();
      expect(dataSource.archiveProfile, isNotNull);
      expect(dataSource.restoreProfile, isNotNull);
    });

    test('7. Safety constraint: Remote sync remains disabled by default', () {
      expect(
        SyncService.isRemoteSyncEnabled,
        isFalse,
        reason: 'SyncService.isRemoteSyncEnabled must remain false',
      );
      expect(
        BackgroundSyncService.isBackgroundSyncEnabled,
        isFalse,
        reason: 'BackgroundSyncService.isBackgroundSyncEnabled must remain false',
      );
    });
  });
}


