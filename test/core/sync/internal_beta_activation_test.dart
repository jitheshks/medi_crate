// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/manual_sync_controller.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_lock.dart';
import 'package:medi_crate/core/sync/sync_providers.dart';
import 'package:medi_crate/core/sync/sync_rollout_config.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';

class _FakeConnectivityService extends ConnectivityService {
  final bool online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  _FakeConnectivityService({this.online = true})
      : super(autoInitialize: false);

  @override
  Future<bool> checkConnectivity() async => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;
}

class _TestIsolatedHiveService implements HiveService {
  final Box<Map> _authBox;
  final Box<Map> _syncQueueBox;
  final Box<Map> _userBox;
  final Box<Map> _settingsBox;
  final Box<Map> _consentBox;
  final Box<Map> _profileBox;

  _TestIsolatedHiveService({
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

class _MockSupabaseSyncCoordinator extends SupabaseSyncCoordinator {
  final String? _authUserId;
  final List<SyncQueueItem> processedItems = [];
  bool shouldThrow = false;
  bool returnSuccess = true;

  _MockSupabaseSyncCoordinator({
    required super.hiveService,
    String? authUserId,
  }) : _authUserId = authUserId;

  @override
  String? get authenticatedUserId => _authUserId;

  @override
  Future<bool> processItem({
    required SyncQueueItem item,
    String? explicitOwnerUserId,
  }) async {
    if (shouldThrow) {
      throw Exception('Simulated remote failure');
    }
    processedItems.add(item);
    return returnSuccess;
  }
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

  group('Implementation 7.3.2: Controlled Internal Foreground Activation', () {
    late Directory tempDir;
    late _TestIsolatedHiveService hiveService;
    late _FakeConnectivityService connectivityService;

    final authorizedTesterUuid1 = 'e4b39a3e-1087-4d7a-8f43-04e9c7f90001';
    final authorizedTesterUuid2 = 'e4b39a3e-1087-4d7a-8f43-04e9c7f90002';
    final standardUserUuid = 'f9a8b7c6-d5e4-4321-ba98-76543210fedc';
    final profileId = 'prof_beta_activation_1';

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('medicrate_7_3_2_test_');
      Hive.init(tempDir.path);

      final authBox = await Hive.openBox<Map>('test_732_auth');
      final syncQueueBox = await Hive.openBox<Map>('test_732_queue');
      final userBox = await Hive.openBox<Map>('test_732_user');
      final settingsBox = await Hive.openBox<Map>('test_732_settings');
      final consentBox = await Hive.openBox<Map>('test_732_consent');
      final profileBox = await Hive.openBox<Map>('test_732_profile');

      hiveService = _TestIsolatedHiveService(
        authBox: authBox,
        syncQueueBox: syncQueueBox,
        userBox: userBox,
        settingsBox: settingsBox,
        consentBox: consentBox,
        profileBox: profileBox,
      );

      connectivityService = _FakeConnectivityService(online: true);
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
      SyncService? customSyncService,
    }) {
      final user = currentUser ??
          UserModel(
            id: authorizedTesterUuid1,
            email: 'tester1@example.com',
            name: 'Beta Tester One',
          );

      final prof = activeProfile ??
          ProfileModel(
            profileId: profileId,
            ownerUserId: user.id,
            fullName: 'Beta Profile',
            relationship: 'Self',
            isPrimary: true,
          );

      final authState = AuthState(
        isLoading: false,
        isAuthenticated: isAuthenticated,
        user: isAuthenticated ? user : null,
      );

      final syncSvc = customSyncService ??
          SyncService(
            hiveService: hiveService,
            connectivityService: connectivityService,
          );

      return ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthNotifier(initialState: authState),
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          syncServiceProvider.overrideWithValue(syncSvc),
          activeProfileProvider.overrideWith(
            () => _TestActiveProfileNotifier(prof),
          ),
        ],
      );
    }

    test('1. Authorized and opted-in tester can synchronize (beta build enabled)', () async {
      // Configure internal beta build with authorized tester UUID
      final count = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );
      expect(count, equals(1));
      expect(SyncService.isControlledForegroundSyncEnabled, isTrue);
      expect(SyncRolloutConfig.isInternalBetaEnabled, isTrue);

      final mockCoordinator = _MockSupabaseSyncCoordinator(
        hiveService: hiveService,
        authUserId: authorizedTesterUuid1,
      );
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: mockCoordinator,
      );

      // Explicit opt-in
      await syncService.setTesterOptIn(authorizedTesterUuid1, true);
      expect(syncService.isTesterOptedIn(authorizedTesterUuid1), isTrue);

      // Verify all 8 activation safeguards evaluate to canSync == true
      final safeguard = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid1,
        isOptedIn: true,
      );
      expect(safeguard.canSync, isTrue);
      expect(safeguard.rejectionReason, isNull);

      // Queue a synthetic clinical mutation directly in isolated Hive storage
      final item = SyncQueueItem(
        id: 'mut_beta_001',
        entity: 'vitals',
        operation: 'create',
        payload: {
          'client_uuid': UuidUtils.generateV4(),
          'measurement_type': 'blood_pressure',
          'systolic': 120,
          'diastolic': 80,
          'owner_user_id': authorizedTesterUuid1,
        },
        status: 'pending',
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      expect(hiveService.syncQueueBox.length, equals(1));

      // Trigger sync
      await syncService.syncPending(explicitOwnerUserId: authorizedTesterUuid1);

      // Verify mutation was dispatched to coordinator and removed from queue
      expect(mockCoordinator.processedItems.length, equals(1));
      expect(hiveService.syncQueueBox.length, equals(0));
    });

    test('2. Ineligible users remain local-only', () async {
      // Beta enabled, but only tester 1 is authorized
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );

      final mockCoordinator = _MockSupabaseSyncCoordinator(
        hiveService: hiveService,
        authUserId: standardUserUuid,
      );
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: mockCoordinator,
      );

      // Ineligible user attempts opt-in in local storage
      await syncService.setTesterOptIn(standardUserUuid, true);

      // Activation safeguards must reject ineligible user
      final safeguard = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: standardUserUuid,
        isOptedIn: true,
      );
      expect(safeguard.canSync, isFalse);
      expect(
        safeguard.rejectionReason,
        contains('restricted to authorized internal testers'),
      );

      // Queue synthetic mutation for ineligible user
      final item = SyncQueueItem(
        id: 'mut_ineligible_001',
        entity: 'medicines',
        operation: 'create',
        payload: {
          'name': 'Paracetamol',
          'owner_user_id': standardUserUuid,
        },
        status: 'pending',
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // Attempt sync
      await syncService.syncPending(explicitOwnerUserId: standardUserUuid);

      // Verify coordinator was NEVER called and mutation remains safely in Hive
      expect(mockCoordinator.processedItems, isEmpty);
      expect(hiveService.syncQueueBox.length, equals(1));
      final preserved = hiveService.syncQueueBox.get('mut_ineligible_001');
      expect(preserved, isNotNull);
      expect(preserved!['retry_count'] ?? 0, equals(0));
    });

    test('3. Missing configuration fails closed', () async {
      // 3A: Null / empty configuration clears testers and fails closed
      final count = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: null,
        isBetaEnabled: true,
      );
      expect(count, equals(0));
      expect(SyncRolloutConfig.authorizedTesterUuids, isEmpty);

      final check1 = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid1,
        isOptedIn: true,
      );
      expect(check1.canSync, isFalse);
      expect(check1.rejectionReason, contains('restricted to authorized internal testers'));

      // 3B: Malformed JSON fails closed, pauses rollout, and clears testers
      final malformedCount = SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: '{"testers": "not-a-list"}',
        isBetaEnabled: true,
      );
      expect(malformedCount, equals(-1));
      expect(SyncRolloutConfig.isGlobalRolloutPaused, isTrue);
      expect(SyncRolloutConfig.authorizedTesterUuids, isEmpty);

      // 3C: Production build (isBetaEnabled: false) evaluates to disabled
      SyncRolloutConfig.resetToDefaults();
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: false,
      );
      expect(SyncService.isControlledForegroundSyncEnabled, isFalse);
      final check2 = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid1,
        isOptedIn: true,
      );
      expect(check2.canSync, isFalse);
      expect(check2.rejectionReason, contains('disabled for this build'));
    });

    test('4. Global pause prevents subsequent dispatch', () async {
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );

      final mockCoordinator = _MockSupabaseSyncCoordinator(
        hiveService: hiveService,
        authUserId: authorizedTesterUuid1,
      );
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: mockCoordinator,
      );
      await syncService.setTesterOptIn(authorizedTesterUuid1, true);

      // Activate Global Rollout Pause
      SyncRolloutConfig.setGlobalRolloutPaused(true);
      expect(SyncRolloutConfig.isGlobalRolloutPaused, isTrue);

      final safeguard = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid1,
        isOptedIn: true,
      );
      expect(safeguard.canSync, isFalse);
      expect(safeguard.rejectionReason, contains('rollout is currently paused'));

      // Queue mutation
      final item = SyncQueueItem(
        id: 'mut_paused_001',
        entity: 'appointments',
        operation: 'create',
        payload: {'title': 'Dental Checkup'},
        status: 'pending',
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // Attempt sync
      await syncService.syncPending(explicitOwnerUserId: authorizedTesterUuid1);

      // Blocked: coordinator not called, mutation intact
      expect(mockCoordinator.processedItems, isEmpty);
      expect(hiveService.syncQueueBox.length, equals(1));
    });

    test('5. Individual revocation prevents subsequent dispatch', () async {
      // Authorize both testers
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: '$authorizedTesterUuid1,$authorizedTesterUuid2',
        isBetaEnabled: true,
      );
      expect(SyncRolloutConfig.authorizedTesterUuids.length, equals(2));

      // Revoke Tester 1 specifically
      SyncRolloutConfig.revokeTester(authorizedTesterUuid1);
      expect(SyncRolloutConfig.authorizedTesterUuids.contains(authorizedTesterUuid1), isFalse);
      expect(SyncRolloutConfig.authorizedTesterUuids.contains(authorizedTesterUuid2), isTrue);

      // Tester 1 rejected
      final check1 = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid1,
        isOptedIn: true,
      );
      expect(check1.canSync, isFalse);
      expect(check1.rejectionReason, contains('restricted to authorized internal testers'));

      // Tester 2 remains permitted
      final check2 = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid2,
        isOptedIn: true,
      );
      expect(check2.canSync, isTrue);
    });

    test('6. User opt-out prevents subsequent dispatch', () async {
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );

      final mockCoordinator = _MockSupabaseSyncCoordinator(
        hiveService: hiveService,
        authUserId: authorizedTesterUuid1,
      );
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: mockCoordinator,
      );

      // User was opted in, then opts out
      await syncService.setTesterOptIn(authorizedTesterUuid1, true);
      expect(syncService.isTesterOptedIn(authorizedTesterUuid1), isTrue);
      await syncService.setTesterOptIn(authorizedTesterUuid1, false);
      expect(syncService.isTesterOptedIn(authorizedTesterUuid1), isFalse);

      final safeguard = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: authorizedTesterUuid1,
        isOptedIn: false,
      );
      expect(safeguard.canSync, isFalse);
      expect(safeguard.rejectionReason, contains('requires opt-in'));

      // Queue mutation
      final item = SyncQueueItem(
        id: 'mut_optout_001',
        entity: 'reports',
        operation: 'create',
        payload: {'report_name': 'Blood Test'},
        status: 'pending',
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPending(explicitOwnerUserId: authorizedTesterUuid1);

      // Blocked: coordinator not called, mutation intact
      expect(mockCoordinator.processedItems, isEmpty);
      expect(hiveService.syncQueueBox.length, equals(1));
    });

    test('7. Account switching cannot reuse authorization', () async {
      // Tester 1 is authorized and opted in
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
      );
      await syncService.setTesterOptIn(authorizedTesterUuid1, true);

      // Container for Tester 1
      final container1 = createContainer(
        currentUser: UserModel(
          id: authorizedTesterUuid1,
          email: 'tester1@example.com',
          name: 'Tester One',
        ),
        customSyncService: syncService,
      );
      final user1 = container1.read(authControllerProvider).user;
      final check1 = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: user1?.id,
        isOptedIn: syncService.isTesterOptedIn(user1?.id),
      );
      expect(check1.canSync, isTrue);

      // User logs out and User B logs in
      final container2 = createContainer(
        currentUser: UserModel(
          id: standardUserUuid,
          email: 'userb@example.com',
          name: 'User B',
        ),
        customSyncService: syncService,
      );
      final user2 = container2.read(authControllerProvider).user;
      final check2 = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: user2?.id,
        isOptedIn: syncService.isTesterOptedIn(user2?.id),
      );
      // User B must NOT inherit User A's authorization or opt-in
      expect(check2.canSync, isFalse);
      expect(syncService.isTesterOptedIn(user2?.id), isFalse);
    });

    test('8. Session expiry preserves pending mutations', () async {
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );

      final mockCoordinator = _MockSupabaseSyncCoordinator(
        hiveService: hiveService,
        authUserId: null,
      );
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: mockCoordinator,
      );

      // Unauthenticated session evaluates to false
      final safeguard = SyncRolloutConfig.evaluateActivationSafeguards(
        authenticatedUserId: null,
        isOptedIn: true,
      );
      expect(safeguard.canSync, isFalse);
      expect(safeguard.rejectionReason, contains('Active authenticated session required'));

      // Queue 3 pending mutations
      for (int i = 1; i <= 3; i++) {
        final item = SyncQueueItem(
          id: 'mut_expiry_$i',
          entity: 'consultations',
          operation: 'create',
          payload: {'notes': 'Consultation $i'},
          status: 'pending',
        );
        await hiveService.syncQueueBox.put(item.id, item.toMap());
      }
      expect(hiveService.syncQueueBox.length, equals(3));

      // Attempt sync with expired session (null user id)
      await syncService.syncPending(explicitOwnerUserId: null);

      // All 3 mutations remain completely preserved with 0 retries burned
      expect(mockCoordinator.processedItems, isEmpty);
      expect(hiveService.syncQueueBox.length, equals(3));
      for (int i = 1; i <= 3; i++) {
        final item = hiveService.syncQueueBox.get('mut_expiry_$i');
        expect(item, isNotNull);
        expect(item!['status'], equals('pending'));
        expect(item['retry_count'] ?? 0, equals(0));
      }
    });

    test('9. SyncLock prevents concurrent processing', () async {
      final lockA = SyncLock(hiveService.settingsBox);
      final lockB = SyncLock(hiveService.settingsBox);

      // Processor A acquires lock
      final tokenA = await lockA.tryAcquire();
      expect(tokenA, isNotNull);

      // Processor B attempts to acquire while lease is held
      final tokenB = await lockB.tryAcquire();
      expect(tokenB, isNull);

      // Processor A releases lock
      await lockA.release(tokenA!);

      // Processor B can now acquire lock
      final tokenB2 = await lockB.tryAcquire();
      expect(tokenB2, isNotNull);
      await lockB.release(tokenB2!);
    });

    test('10. Background workers remain disabled', () {
      // Production default
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      // Enable beta and authorize testers
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );
      expect(SyncService.isControlledForegroundSyncEnabled, isTrue);

      // Background sync must remain strictly disabled
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
      expect(SyncService.isRemoteSyncEnabled, isFalse);

      // Pause rollout
      SyncRolloutConfig.setGlobalRolloutPaused(true);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      // Reset
      SyncRolloutConfig.resetToDefaults();
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });

    test('11. Failed or deferred mutations are not reported as successfully synchronized', () async {
      SyncRolloutConfig.loadConfiguration(
        rawTesterUuids: authorizedTesterUuid1,
        isBetaEnabled: true,
      );

      // Coordinator returns false (failure to sync to remote)
      final mockCoordinator = _MockSupabaseSyncCoordinator(
        hiveService: hiveService,
        authUserId: authorizedTesterUuid1,
      )..returnSuccess = false;

      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: mockCoordinator,
      );
      await syncService.setTesterOptIn(authorizedTesterUuid1, true);

      // Queue a mutation
      final item = SyncQueueItem(
        id: 'mut_failing_001',
        entity: 'vitals',
        operation: 'create',
        payload: {'temp': 98.6},
        status: 'pending',
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // Attempt sync - coordinator reports failure
      await syncService.syncPending(explicitOwnerUserId: authorizedTesterUuid1);

      // Mutation is NOT deleted or reported synchronized; preserved in queue with failed status
      expect(hiveService.syncQueueBox.length, equals(1));
      final preserved = hiveService.syncQueueBox.get('mut_failing_001');
      expect(preserved, isNotNull);
      expect(preserved!['status'], equals('failed'));
      expect(preserved['retryCount'] ?? preserved['retry_count'], equals(1));

      // Test ManualSyncResult reporting
      const failingResult = ManualSyncResult(
        message: 'Some records could not be synchronized.',
        isSuccess: false,
        pullFailureCount: 2,
        remainingActiveCount: 1,
        remainingTotalCount: 1,
      );
      expect(failingResult.isSuccess, isFalse);
      expect(failingResult.pullFailureCount, equals(2));
      expect(failingResult.remainingActiveCount, equals(1));
    });
  });
}
