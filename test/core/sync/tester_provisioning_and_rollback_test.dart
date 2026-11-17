// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/sync_providers.dart';
import 'package:medi_crate/core/sync/sync_rollout_config.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';

class FakeConnectivityService extends ConnectivityService {
  final bool online;
  FakeConnectivityService({this.online = true}) : super(autoInitialize: false);

  @override
  Future<bool> checkConnectivity() async => online;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(online);
}

class TestIsolatedHiveService implements HiveService {
  final Box<Map> _authBox;
  final Box<Map> _syncQueueBox;
  final Box<Map> _userBox;
  final Box<Map> _settingsBox;
  final Box<Map> _consentBox;
  final Box<Map> _profileBox;

  TestIsolatedHiveService({
    required Box<Map> authBox,
    required Box<Map> syncQueueBox,
    required Box<Map> userBox,
    required Box<Map> settingsBox,
    required Box<Map> consentBox,
    required Box<Map> profileBox,
  })  : _authBox = authBox,
        _syncQueueBox = syncQueueBox,
        _userBox = userBox,
        _settingsBox = settingsBox,
        _consentBox = consentBox,
        _profileBox = profileBox;

  @override
  Box<Map> get authBox => _authBox;
  @override
  Box<Map> get syncQueueBox => _syncQueueBox;
  @override
  Box<Map> get userBox => _userBox;
  @override
  Box<Map> get settingsBox => _settingsBox;
  @override
  Box<Map> get consentBox => _consentBox;
  @override
  Box<Map> get profileBox => _profileBox;
}

class _TestAuthNotifier extends AuthNotifier {
  final AuthState _testState;
  _TestAuthNotifier({required AuthState initialState})
      : _testState = initialState;

  @override
  AuthState build() => _testState;
}

class _TestActiveProfileNotifier extends ActiveProfileNotifier {
  final ProfileModel? _initialProfile;
  _TestActiveProfileNotifier(this._initialProfile);

  @override
  ProfileModel? build() => _initialProfile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Implementation 7.3.1: Operational Tester Provisioning & Rollback Controls', () {
    late Directory tempDir;
    late TestIsolatedHiveService hiveService;
    late FakeConnectivityService connectivityService;
    late SyncService syncService;

    final validTesterUuid1 = 'c6b39a3e-1087-4d7a-8f43-04e9c7f9999a';
    final validTesterUuid2 = 'd1a2b3c4-e5f6-4a1b-8c2d-3e4f5a6b7c8d';
    final standardUserUuid = '88888888-4444-4444-4444-121212121212';
    final profileId = 'prof_tester_1';

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('medicrate_7_3_1_test_');
      Hive.init(tempDir.path);

      final authBox = await Hive.openBox<Map>('test_731_auth');
      final syncQueueBox = await Hive.openBox<Map>('test_731_queue');
      final userBox = await Hive.openBox<Map>('test_731_user');
      final settingsBox = await Hive.openBox<Map>('test_731_settings');
      final consentBox = await Hive.openBox<Map>('test_731_consent');
      final profileBox = await Hive.openBox<Map>('test_731_profile');

      hiveService = TestIsolatedHiveService(
        authBox: authBox,
        syncQueueBox: syncQueueBox,
        userBox: userBox,
        settingsBox: settingsBox,
        consentBox: consentBox,
        profileBox: profileBox,
      );

      connectivityService = FakeConnectivityService(online: true);
      syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
      );
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      SyncRolloutConfig.resetToDefaults();
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
    });

    setUp(() async {
      await hiveService.syncQueueBox.clear();
      await hiveService.settingsBox.clear();
      SyncRolloutConfig.resetToDefaults();
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
    });

    ProviderContainer createContainer({
      UserModel? currentUser,
      ProfileModel? activeProfile,
      bool isAuthenticated = true,
    }) {
      final user = currentUser ??
          UserModel(
            id: validTesterUuid1,
            email: 'tester1@example.com',
            name: 'Tester One',
          );

      final prof = activeProfile ??
          ProfileModel(
            profileId: profileId,
            ownerUserId: user.id,
            fullName: 'Tester Profile',
            relationship: 'Self',
            isPrimary: true,
          );

      final authState = AuthState(
        isLoading: false,
        isAuthenticated: isAuthenticated,
        user: isAuthenticated ? user : null,
      );

      return ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthNotifier(initialState: authState),
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          syncServiceProvider.overrideWithValue(syncService),
          activeProfileProvider.overrideWith(
            () => _TestActiveProfileNotifier(prof),
          ),
        ],
      );
    }

    // -------------------------------------------------------------------------
    // Test 1: Authorized tester configuration is accepted
    // -------------------------------------------------------------------------
    test('1. Authorized tester configuration is accepted and validates UUIDs', () {
      // Test comma-separated parsing
      final count = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: '$validTesterUuid1, $validTesterUuid2',
      );
      expect(count, equals(2));
      expect(SyncRolloutConfig.authorizedTesterUuids.contains(validTesterUuid1), isTrue);
      expect(SyncRolloutConfig.authorizedTesterUuids.contains(validTesterUuid2), isTrue);
      expect(SyncService.isEligibleTester(validTesterUuid1), isTrue);
      expect(SyncService.isEligibleTester(validTesterUuid2), isTrue);

      // Test JSON array parsing
      final jsonCount = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: '["$validTesterUuid1", "$validTesterUuid2"]',
      );
      expect(jsonCount, equals(2));
      expect(SyncService.isEligibleTester(validTesterUuid1), isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 2: Invalid UUIDs are rejected
    // -------------------------------------------------------------------------
    test('2. Invalid UUIDs are rejected during configuration loading', () {
      final count = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: '$validTesterUuid1, not-a-uuid, 12345, admin@hospital.com, ../../../etc',
      );
      // Only the 1 valid UUID is accepted; all 4 invalid entries are dropped
      expect(count, equals(1));
      expect(SyncRolloutConfig.authorizedTesterUuids.contains(validTesterUuid1), isTrue);
      expect(SyncRolloutConfig.authorizedTesterUuids.contains('not-a-uuid'), isFalse);
      expect(SyncRolloutConfig.authorizedTesterUuids.contains('12345'), isFalse);
      expect(SyncRolloutConfig.authorizedTesterUuids.contains('admin@hospital.com'), isFalse);

      expect(SyncService.isEligibleTester('not-a-uuid'), isFalse);
      expect(SyncService.isEligibleTester('12345'), isFalse);
      expect(SyncService.isEligibleTester(''), isFalse);
      expect(SyncService.isEligibleTester(null), isFalse);

      // Direct authorizeTester call rejects invalid UUID (fails closed)
      final directResult = SyncService.authorizeTester('invalid-format-uuid');
      expect(directResult, isFalse);
      expect(SyncService.authorizedTesterUserIds.contains('invalid-format-uuid'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 3: Configuration unavailable or invalid fails closed
    // -------------------------------------------------------------------------
    test('3. Configuration unavailable or invalid fails closed', () {
      // Malformed JSON input must fail closed (returns -1, pauses rollout, clears registry)
      final result = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: '{"invalid": json syntax [}',
      );
      expect(result, equals(-1));
      expect(SyncRolloutConfig.isGlobalRolloutPaused, isTrue);
      expect(SyncRolloutConfig.authorizedTesterUuids, isEmpty);

      // Even previously accepted tester is now blocked
      expect(SyncService.isEligibleTester(validTesterUuid1), isFalse);

      // Null or empty configuration safely yields 0 authorized testers
      SyncRolloutConfig.resetToDefaults();
      final emptyResult = SyncRolloutConfig.loadConfiguration(rawTesterUuids: null);
      expect(emptyResult, equals(0));
      expect(SyncRolloutConfig.authorizedTesterUuids, isEmpty);
      expect(SyncService.isEligibleTester(validTesterUuid1), isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 4: Ineligible user cannot grant themselves access
    // -------------------------------------------------------------------------
    test('4. Ineligible user cannot grant themselves access via client storage', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);

      // Standard user attempts to grant themselves opt-in in local Hive settings
      await syncService.setTesterOptIn(standardUserUuid, true);
      expect(syncService.isTesterOptedIn(standardUserUuid), isTrue);

      // Eligibility must remain strictly false
      expect(SyncService.isEligibleTester(standardUserUuid), isFalse);

      // Enqueue mutation for standard user
      final item = SyncQueueItem(
        id: 'q_unauth_grant',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'client_uuid': UuidUtils.generateV4(),
          'name': 'Unauthorized Hospital',
          'owner_user_id': standardUserUuid,
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      final container = createContainer(
        currentUser: UserModel(
          id: standardUserUuid,
          email: 'standard@example.com',
          name: 'Standard User',
        ),
      );

      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('restricted to authorized internal testers'));
      expect(hiveService.syncQueueBox.length, equals(1));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 5: Tester revocation blocks subsequent dispatch
    // -------------------------------------------------------------------------
    test('5. Tester revocation blocks subsequent dispatch and preserves queue', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);
      await syncService.setTesterOptIn(validTesterUuid1, true);

      expect(SyncService.isEligibleTester(validTesterUuid1), isTrue);
      expect(syncService.isTesterOptedIn(validTesterUuid1), isTrue);

      final item = SyncQueueItem(
        id: 'q_revocation_test',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'client_uuid': UuidUtils.generateV4(),
          'name': 'Pre-Revocation Hospital',
          'owner_user_id': validTesterUuid1,
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // Operational revocation of tester
      SyncRolloutConfig.revokeTester(validTesterUuid1);
      expect(SyncService.isEligibleTester(validTesterUuid1), isFalse);

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('restricted to authorized internal testers'));
      expect(hiveService.syncQueueBox.length, equals(1));

      // Direct syncPending call also halts dispatch
      await syncService.syncPending(
        force: true,
        explicitOwnerUserId: validTesterUuid1,
      );
      expect(hiveService.syncQueueBox.length, equals(1));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 6: Global rollout pause blocks subsequent dispatch
    // -------------------------------------------------------------------------
    test('6. Global rollout pause blocks subsequent dispatch with informative message', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);
      await syncService.setTesterOptIn(validTesterUuid1, true);

      final item = SyncQueueItem(
        id: 'q_pause_test',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'client_uuid': UuidUtils.generateV4(),
          'name': 'Dr. Paused Rollout',
          'owner_user_id': validTesterUuid1,
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // Global Rollout Pause activated
      SyncRolloutConfig.setGlobalRolloutPaused(true);
      expect(SyncRolloutConfig.isGlobalRolloutPaused, isTrue);
      expect(SyncService.isEligibleTester(validTesterUuid1), isFalse);

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Synchronization rollout is currently paused'));
      expect(hiveService.syncQueueBox.length, equals(1));

      // Low level syncPending also blocks
      await syncService.syncPending(
        force: true,
        explicitOwnerUserId: validTesterUuid1,
      );
      expect(hiveService.syncQueueBox.length, equals(1));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 7: User opt-out still blocks dispatch
    // -------------------------------------------------------------------------
    test('7. User self opt-out blocks dispatch while preserving tester eligibility', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);
      // User opted in initially
      await syncService.setTesterOptIn(validTesterUuid1, true);

      final item = SyncQueueItem(
        id: 'q_opt_out_test',
        entity: 'medicine',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'client_uuid': UuidUtils.generateV4(),
          'name': 'Amoxicillin 250mg',
          'owner_user_id': validTesterUuid1,
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // User self-opts out
      await syncService.setTesterOptIn(validTesterUuid1, false);
      expect(syncService.isTesterOptedIn(validTesterUuid1), isFalse);
      // Still eligible
      expect(SyncService.isEligibleTester(validTesterUuid1), isTrue);

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('requires opt-in'));
      expect(hiveService.syncQueueBox.length, equals(1));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 8: Account switching does not reuse authorization or opt-in
    // -------------------------------------------------------------------------
    test('8. Account switching isolates authorization and opt-in strictly per user', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);
      await syncService.setTesterOptIn(validTesterUuid1, true);

      // User 1 is eligible and opted in
      expect(SyncService.isEligibleTester(validTesterUuid1), isTrue);
      expect(syncService.isTesterOptedIn(validTesterUuid1), isTrue);

      // User 2 logs in on the same client
      expect(SyncService.isEligibleTester(validTesterUuid2), isFalse);
      expect(syncService.isTesterOptedIn(validTesterUuid2), isFalse);

      final container2 = createContainer(
        currentUser: UserModel(
          id: validTesterUuid2,
          email: 'tester2@example.com',
          name: 'Tester Two',
        ),
      );

      expect(container2.read(isEligibleTesterProvider), isFalse);
      expect(container2.read(syncOptInProvider), isFalse);

      final res2 = await container2
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();
      expect(res2.isSuccess, isFalse);
      expect(res2.message, contains('restricted to authorized internal testers'));

      // User 1 remains unchanged
      expect(syncService.isTesterOptedIn(validTesterUuid1), isTrue);

      container2.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 9: Existing queued mutations remain intact during rollback
    // -------------------------------------------------------------------------
    test('9. Existing queued mutations remain intact with untouched payloads and retry counts', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);
      await syncService.setTesterOptIn(validTesterUuid1, true);

      final item1 = SyncQueueItem(
        id: 'q_intact_doc',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'client_uuid': UuidUtils.generateV4(),
          'name': 'Dr. Intact',
        },
        retryCount: 0,
      );

      final item2 = SyncQueueItem(
        id: 'q_intact_med',
        entity: 'medicine',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'client_uuid': UuidUtils.generateV4(),
          'name': 'Metformin 500mg',
        },
        retryCount: 2,
      );

      await hiveService.syncQueueBox.put(item1.id, item1.toMap());
      await hiveService.syncQueueBox.put(item2.id, item2.toMap());
      expect(hiveService.syncQueueBox.length, equals(2));

      // Trigger Local Kill Switch
      SyncRolloutConfig.setLocalKillSwitch(true);
      expect(SyncRolloutConfig.isLocalKillSwitchActive, isTrue);

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('disabled by local emergency controls'));

      // Queue items must be completely untouched
      expect(hiveService.syncQueueBox.length, equals(2));
      final stored1 = SyncQueueItem.fromMap(
        Map<String, dynamic>.from(hiveService.syncQueueBox.get(item1.id)!),
      );
      final stored2 = SyncQueueItem.fromMap(
        Map<String, dynamic>.from(hiveService.syncQueueBox.get(item2.id)!),
      );

      expect(stored1.retryCount, equals(0));
      expect(stored2.retryCount, equals(2));
      expect(stored1.payload['name'], equals('Dr. Intact'));
      expect(stored2.payload['name'], equals('Metformin 500mg'));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 10: Background workers remain disabled
    // -------------------------------------------------------------------------
    test('10. Background workers remain disabled throughout all rollout and pause states', () {
      // Configuration loaded with active tester
      SyncRolloutConfig.loadConfiguration(rawTesterUuids: validTesterUuid1);
      SyncService.isControlledForegroundSyncEnabled = true;

      // Invariants:
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      // Even when global pause is toggled
      SyncRolloutConfig.setGlobalRolloutPaused(true);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      SyncRolloutConfig.setGlobalRolloutPaused(false);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      // Local kill switch toggled
      SyncRolloutConfig.setLocalKillSwitch(true);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      // Invariant: BackgroundSyncService.isBackgroundSyncEnabled strictly matches isRemoteSyncEnabled
      expect(
        BackgroundSyncService.isBackgroundSyncEnabled,
        equals(SyncService.isRemoteSyncEnabled),
      );
    });
  });
}
