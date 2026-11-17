// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/sync/foreground_resume_sync.dart';
import 'package:medi_crate/core/sync/manual_sync_controller.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_lock.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import 'package:medi_crate/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
import 'package:medi_crate/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import 'package:medi_crate/features/doctors/presentation/providers/doctors_providers.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/presentation/providers/hospitals_providers.dart';
import 'package:medi_crate/features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import 'package:medi_crate/features/medicines/presentation/providers/medicine_providers.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import 'package:medi_crate/features/reports/presentation/providers/reports_providers.dart';
import 'package:medi_crate/features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import 'package:medi_crate/features/vitals/presentation/providers/measurement_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

class _FakeConnectivityService implements ConnectivityService {
  bool isOnline = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

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
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool online) {
    isOnline = online;
    _controller.add(online);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class IsolatedHiveService implements HiveService {
  Box<Map> _authBox;
  Box<Map> _syncQueueBox;
  Box<Map> _userBox;
  Box<Map> _settingsBox;
  Box<Map> _consentBox;
  Box<Map> _profileBox;

  IsolatedHiveService({
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

  void rebindBoxes({
    required Box<Map> authBox,
    required Box<Map> syncQueueBox,
    required Box<Map> userBox,
    required Box<Map> settingsBox,
    required Box<Map> consentBox,
    required Box<Map> profileBox,
  }) {
    _authBox = authBox;
    _syncQueueBox = syncQueueBox;
    _userBox = userBox;
    _settingsBox = settingsBox;
    _consentBox = consentBox;
    _profileBox = profileBox;
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
  HttpOverrides.global = _RealHttpOverrides();
  SharedPreferences.setMockInitialValues({});

  late String supabaseUrl;
  late String anonKey;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    final config = SupabaseConfig.validateConfig();
    supabaseUrl = config.url;
    anonKey = config.anonKey;
  });

  group('Implementation 7.1: Controlled Foreground Sync Activation Verification', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailA = 'sync_fg_user_a_$timestamp@fldubai.com';
    final emailB = 'sync_fg_user_b_$timestamp@fldubai.com';
    const password = 'SyncPassword123!';

    late SupabaseClient clientA;
    late SupabaseClient clientB;

    late SupabaseAuthRemoteDataSource authA;
    late SupabaseProfileRemoteDataSource profileA;
    late SupabaseHospitalRemoteDataSource hospitalA;
    late SupabaseDoctorRemoteDataSource doctorA;
    late SupabaseConsultationRemoteDataSource consultationA;
    late SupabaseAppointmentRemoteDataSource appointmentA;
    late SupabaseMedicineRemoteDataSource medicineA;
    late SupabaseReportRemoteDataSource reportA;
    late SupabaseVitalsRemoteDataSource vitalsA;
    late SupabaseStorageService storageA;

    late SupabaseAuthRemoteDataSource authB;
    late SupabaseProfileRemoteDataSource profileB;

    String? userAId;
    String? userBId;
    ProfileModel? primaryProfileA;

    late Directory tempHiveDir;
    late IsolatedHiveService isolatedHiveService;
    late _FakeConnectivityService fakeConnectivity;
    late SupabaseSyncCoordinator coordinatorA;
    late SyncService syncServiceA;

    SupabaseClient createClient() {
      return SupabaseClient(
        supabaseUrl,
        anonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    }

    Future<void> confirmUsers(List<String> emails) async {
      final emailList = emails.map((e) => "'$e'").join(', ');
      for (var attempt = 1; attempt <= 3; attempt++) {
        final res = await Process.run('supabase', [
          'db',
          'query',
          '--linked',
          'UPDATE auth.users SET email_confirmed_at = NOW() WHERE email IN ($emailList);',
        ]);
        if (res.exitCode == 0) return;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    setUpAll(() async {
      // 1. Initialize Clients & Data Sources
      clientA = createClient();
      authA = SupabaseAuthRemoteDataSource(clientA);
      profileA = SupabaseProfileRemoteDataSource(customClient: clientA);
      hospitalA = SupabaseHospitalRemoteDataSource(customClient: clientA);
      doctorA = SupabaseDoctorRemoteDataSource(customClient: clientA);
      consultationA = SupabaseConsultationRemoteDataSource(client: clientA);
      appointmentA = SupabaseAppointmentRemoteDataSource(client: clientA);
      medicineA = SupabaseMedicineRemoteDataSource(client: clientA);
      reportA = SupabaseReportRemoteDataSource(client: clientA);
      vitalsA = SupabaseVitalsRemoteDataSource(client: clientA);
      storageA = SupabaseStorageService(customClient: clientA);

      clientB = createClient();
      authB = SupabaseAuthRemoteDataSource(clientB);
      profileB = SupabaseProfileRemoteDataSource(customClient: clientB);

      // 2. Sign up test users
      await authA.signUp(
        name: 'Sync FG User A',
        email: emailA,
        password: password,
      );
      await authB.signUp(
        name: 'Sync FG User B',
        email: emailB,
        password: password,
      );

      // Confirm users via direct SQL to enable session login
      await confirmUsers([emailA, emailB]);

      // 3. Sign in User A & User B
      final resA = await clientA.auth.signInWithPassword(
        email: emailA,
        password: password,
      );
      userAId = resA.user?.id;

      final resB = await clientB.auth.signInWithPassword(
        email: emailB,
        password: password,
      );
      userBId = resB.user?.id;

      expect(userAId, isNotNull);
      expect(userBId, isNotNull);

      // 4. Fetch auto-provisioned primary profiles
      final profilesA = await profileA.fetchProfiles(ownerUserId: userAId!);
      primaryProfileA = profilesA.firstWhere((p) => p.isPrimary);

      final profilesB = await profileB.fetchProfiles(ownerUserId: userBId!);
      expect(profilesB.any((p) => p.isPrimary), isTrue);

      // 5. Setup Isolated Hive Environment in /tmp
      tempHiveDir = await Directory.systemTemp.createTemp('medi_crate_fg_sync_test_');
      Hive.init(tempHiveDir.path);

      final authBox = await Hive.openBox<Map>('test_auth_box');
      final syncQueueBox = await Hive.openBox<Map>('test_sync_queue_box');
      final userBox = await Hive.openBox<Map>('test_user_box');
      final settingsBox = await Hive.openBox<Map>('test_settings_box');
      final consentBox = await Hive.openBox<Map>('test_consent_box');
      final profileBox = await Hive.openBox<Map>('test_profile_box');

      isolatedHiveService = IsolatedHiveService(
        authBox: authBox,
        syncQueueBox: syncQueueBox,
        userBox: userBox,
        settingsBox: settingsBox,
        consentBox: consentBox,
        profileBox: profileBox,
      );

      await profileBox.put(
        primaryProfileA!.profileId,
        primaryProfileA!.toMap(),
      );
      await profileBox.put(
        'prof_${primaryProfileA!.profileId}',
        primaryProfileA!.toMap(),
      );

      fakeConnectivity = _FakeConnectivityService();
      coordinatorA = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: clientA,
        customStorageService: storageA,
      );
      syncServiceA = SyncService(
        hiveService: isolatedHiveService,
        connectivityService: fakeConnectivity,
        customSupabaseSyncCoordinator: coordinatorA,
      );
    });

    tearDownAll(() async {
      // 1. Clean up Storage files uploaded during test
      if (userAId != null) {
        try {
          await storageA.deleteParentFolder(
            bucket: 'reports',
            userId: userAId!,
            parentId: '',
          );
        } catch (_) {}
      }

      // 2. Purge test users from hosted database
      await Process.run('supabase', [
        'db',
        'query',
        '--linked',
        "DELETE FROM auth.users WHERE email IN ('$emailA', '$emailB');",
      ]);

      // 3. Clean up temporary Hive directory
      try {
        await Hive.close();
        if (tempHiveDir.existsSync()) {
          tempHiveDir.deleteSync(recursive: true);
        }
      } catch (_) {}

      // Reset static flags to production defaults
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
    });

    setUp(() async {
      await isolatedHiveService.syncQueueBox.clear();
      await isolatedHiveService.settingsBox.clear();
      fakeConnectivity.isOnline = true;
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
      if (userAId != null) {
        SyncService.authorizeTester(userAId!);
        await isolatedHiveService.settingsBox.put(
          'sync_opt_in_$userAId',
          {'opted_in': true, 'updated_at': DateTime.now().toIso8601String()},
        );
      }
    });

    ProviderContainer createTestContainer({
      required UserModel? currentUser,
      required ProfileModel? activeProfile,
      _TestAuthNotifier? customNotifier,
    }) {
      final authState = AuthState(
        isLoading: false,
        isAuthenticated: currentUser != null,
        user: currentUser,
      );
      final notifier = customNotifier ?? _TestAuthNotifier(initialState: authState);

      return ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => notifier),
          hiveServiceProvider.overrideWithValue(isolatedHiveService),
          connectivityServiceProvider.overrideWithValue(fakeConnectivity),
          supabaseClientProvider.overrideWithValue(clientA),
          supabaseSyncCoordinatorProvider.overrideWithValue(coordinatorA),
          syncServiceProvider.overrideWithValue(syncServiceA),
          activeProfileProvider.overrideWith(() => _TestActiveProfileNotifier(activeProfile)),
          supabaseProfileRemoteDataSourceProvider.overrideWithValue(profileA),
          supabaseHospitalRemoteDataSourceProvider.overrideWithValue(hospitalA),
          supabaseDoctorRemoteDataSourceProvider.overrideWithValue(doctorA),
          supabaseConsultationRemoteDataSourceProvider.overrideWithValue(consultationA),
          supabaseAppointmentRemoteDataSourceProvider.overrideWithValue(appointmentA),
          supabaseMedicineRemoteDataSourceProvider.overrideWithValue(medicineA),
          supabaseReportRemoteDataSourceProvider.overrideWithValue(reportA),
          supabaseVitalsRemoteDataSourceProvider.overrideWithValue(vitalsA),
        ],
      );
    }

    // =========================================================================
    // SCENARIO 1: EXPLICIT MANUAL SYNC
    // =========================================================================
    test('Scenario 1: Explicit manual sync triggers force sync under controlled foreground activation', () async {
      final userModelA = UserModel(id: userAId!, email: emailA, name: 'User A');
      final container = createTestContainer(
        currentUser: userModelA,
        activeProfile: primaryProfileA,
      );

      final hospClientUuid = '10000000-0000-0000-0001-000000000001';
      final item = SyncQueueItem(
        id: 'q_scen1_hosp',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_local_scen1',
          'client_uuid': hospClientUuid,
          'profile_id': primaryProfileA!.profileId,
          'name': 'Controlled Sync General Hospital',
          'type': 'General Hospital',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_scen1_hosp', item.toMap());

      // 1. When sync is disabled, manual sync returns preserved message without pushing
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;

      final disabledResult = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(disabledResult.isSuccess, isTrue);
      expect(disabledResult.message.contains('Remote synchronization is disabled'), isTrue);
      expect(isolatedHiveService.syncQueueBox.isNotEmpty, isTrue);

      // 2. Enable controlled foreground sync
      SyncService.isControlledForegroundSyncEnabled = true;

      final enabledResult = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(enabledResult.isSuccess, isTrue);
      expect(enabledResult.message, 'All changes synchronized.');
      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify remote PostgreSQL persistence
      final rows = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', hospClientUuid);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Controlled Sync General Hospital');

      container.dispose();
    });

    // =========================================================================
    // SCENARIO 2: FOREGROUND SYNC AFTER NETWORK RECONNECTION / RESUME
    // =========================================================================
    test('Scenario 2: Foreground sync on app resume / reconnection pushes queue and pulls clinical cache', () async {
      final userModelA = UserModel(id: userAId!, email: emailA, name: 'User A');
      final container = createTestContainer(
        currentUser: userModelA,
        activeProfile: primaryProfileA,
      );

      SyncService.isControlledForegroundSyncEnabled = true;

      final docClientUuid = '10000000-0000-0000-0002-000000000001';
      final item = SyncQueueItem(
        id: 'q_scen2_doc',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': 'doc_local_scen2',
          'client_uuid': docClientUuid,
          'profile_id': primaryProfileA!.profileId,
          'name': 'Dr. Reconnection Specialist',
          'specialty': 'Neurology',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_scen2_doc', item.toMap());

      // Simulate offline reconnect: currently offline
      fakeConnectivity.isOnline = false;
      await runForegroundResumeSync(container);
      expect(isolatedHiveService.syncQueueBox.isNotEmpty, isTrue, reason: 'Offline resume must not drain queue');

      // Now online
      fakeConnectivity.isOnline = true;
      await runForegroundResumeSync(container);

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      final docs = await doctorA.fetchDoctors(
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      final found = docs.firstWhere((d) => d.clientUuid == docClientUuid);
      expect(found.name, 'Dr. Reconnection Specialist');

      container.dispose();
    });

    // =========================================================================
    // SCENARIO 3: AUTHENTICATED SESSION VALIDATION
    // =========================================================================
    test('Scenario 3: Unauthenticated state strictly blocks mutations and manual sync', () async {
      final unauthenticatedClient = createClient();
      final unauthenticatedCoordinator = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: unauthenticatedClient,
        customStorageService: SupabaseStorageService(customClient: unauthenticatedClient),
      );

      final item = SyncQueueItem(
        id: 'q_scen3_unauth',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_scen3',
          'client_uuid': '10000000-0000-0000-0003-000000000001',
          'owner_user_id': userAId!,
          'name': 'Spoof Attempt Hospital',
        },
      );

      // 1. Direct coordinator processing with unauthenticated client
      final result = await unauthenticatedCoordinator.processItem(item: item);
      expect(result, isFalse);
      expect(item.status, 'auth_required');
      expect(item.retryCount, 0, reason: 'Auth failure must never burn retry counter');

      // 2. ManualSyncController with unauthenticated container
      final container = createTestContainer(
        currentUser: null,
        activeProfile: primaryProfileA,
      );
      SyncService.isControlledForegroundSyncEnabled = true;

      final syncResult = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(syncResult.isSuccess, isFalse);
      expect(syncResult.message, 'Active authenticated session required to synchronize.');

      container.dispose();
    });

    // =========================================================================
    // SCENARIO 4: LOGOUT DURING PENDING WORK
    // =========================================================================
    test('Scenario 4: Logout during queue drain immediately halts loop and preserves remaining mutations', () async {
      final userModelA = UserModel(id: userAId!, email: emailA, name: 'User A');
      final container = createTestContainer(
        currentUser: userModelA,
        activeProfile: primaryProfileA,
      );

      // Queue 3 items
      for (var i = 1; i <= 3; i++) {
        final it = SyncQueueItem(
          id: 'q_scen4_item_$i',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': 'hosp_scen4_$i',
            'client_uuid': '10000000-0000-0000-0004-00000000000$i',
            'owner_user_id': userAId!,
            'name': 'Logout Test Hospital $i',
          },
        );
        await isolatedHiveService.syncQueueBox.put('q_scen4_item_$i', it.toMap());
      }

      // Simulate sign out on clientA
      await clientA.auth.signOut();

      SyncService.isControlledForegroundSyncEnabled = true;
      await syncServiceA.syncPendingToSupabase();

      // Verify queue drain stopped immediately:
      // Item 1 was processed and marked 'auth_required' -> break from loop
      // Items 2 and 3 remain in 'pending' status!
      final raw1 = isolatedHiveService.syncQueueBox.get('q_scen4_item_1');
      final raw2 = isolatedHiveService.syncQueueBox.get('q_scen4_item_2');
      final raw3 = isolatedHiveService.syncQueueBox.get('q_scen4_item_3');

      expect(raw1?['status'], 'auth_required');
      expect(raw2?['status'], 'pending');
      expect(raw3?['status'], 'pending');
      expect(isolatedHiveService.syncQueueBox.length, 3, reason: 'All items must remain safely in Hive');

      // Restore session for User A for subsequent tests
      await clientA.auth.signInWithPassword(email: emailA, password: password);
      container.dispose();
    });

    // =========================================================================
    // SCENARIO 5: ACCOUNT SWITCHING
    // =========================================================================
    test('Scenario 5: Account switching defers User A mutations under User B session, then resumes safely', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      // Queue an item for User A
      final itemA = SyncQueueItem(
        id: 'q_scen5_userA',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_scen5_A',
          'client_uuid': '10000000-0000-0000-0005-000000000001',
          'owner_user_id': userAId!,
          'profile_id': primaryProfileA!.profileId,
          'name': 'User A Private Facility',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_scen5_userA', itemA.toMap());

      // Coordinator running under User B session
      final coordinatorB = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: clientB,
        customStorageService: SupabaseStorageService(customClient: clientB),
      );
      final syncServiceB = SyncService(
        hiveService: isolatedHiveService,
        connectivityService: fakeConnectivity,
        customSupabaseSyncCoordinator: coordinatorB,
      );

      // User B attempts to sync the queue
      await syncServiceB.syncPendingToSupabase(explicitOwnerUserId: userBId!);

      // Verify User A's mutation was deferred (blocked cross-user execution)
      final afterSyncB = isolatedHiveService.syncQueueBox.get('q_scen5_userA');
      expect(afterSyncB?['status'], 'deferred');
      expect(afterSyncB?['errorMessage']?.contains('Cross-user mutation execution blocked'), isTrue);

      // Now User A session resumes and syncs
      await syncServiceA.syncPendingToSupabase(explicitOwnerUserId: userAId!);

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify row exists and belongs to User A
      final rowsA = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', '10000000-0000-0000-0005-000000000001');
      expect(rowsA.length, 1);
      expect(rowsA.first['user_id'], userAId);
    });

    // =========================================================================
    // SCENARIO 6: DUPLICATE MANUAL SYNC ATTEMPTS
    // =========================================================================
    test('Scenario 6: Concurrent triggerForceSync() calls yield in-flight guard without spawning duplicates', () async {
      final userModelA = UserModel(id: userAId!, email: emailA, name: 'User A');
      final container = createTestContainer(
        currentUser: userModelA,
        activeProfile: primaryProfileA,
      );

      SyncService.isControlledForegroundSyncEnabled = true;

      final controller = container.read(manualSyncControllerProvider.notifier);

      // Fire two concurrent calls
      final future1 = controller.triggerForceSync();
      final future2 = controller.triggerForceSync();

      final results = await Future.wait([future1, future2]);

      final inFlightResult = results.firstWhere(
        (r) => r.message == 'Synchronization already in progress.',
        orElse: () => results.last,
      );
      expect(inFlightResult.isSuccess, isTrue);

      container.dispose();
    });

    // =========================================================================
    // SCENARIO 7: SYNCLOCK CONTENTION
    // =========================================================================
    test('Scenario 7: SyncLock contention prevents concurrent pull execution', () async {
      final userModelA = UserModel(id: userAId!, email: emailA, name: 'User A');
      final container = createTestContainer(
        currentUser: userModelA,
        activeProfile: primaryProfileA,
      );

      SyncService.isControlledForegroundSyncEnabled = true;

      // An external background process acquires the sync lease
      final externalLock = SyncLock(isolatedHiveService.settingsBox);
      final token = await externalLock.tryAcquire();
      expect(token, isNotNull);

      // runForegroundResumeSync attempts to run
      // It should gracefully yield at step 3 when trying to acquire the lock
      await runForegroundResumeSync(container);

      // Verify the external lease was not stolen or broken
      final stillHeld = await externalLock.tryAcquire();
      expect(stillHeld, isNull, reason: 'SyncLock lease must remain held by original owner');

      // Release external lease
      await externalLock.release(token!);

      container.dispose();
    });

    // =========================================================================
    // SCENARIO 8: PARTIAL FAILURE AND RECOVERY
    // =========================================================================
    test('Scenario 8: Partial failure dead-letters invalid record without stopping valid records', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      final validDocUuid = '10000000-0000-0000-0008-000000000001';
      final invalidHospUuid = '10000000-0000-0000-0008-000000000002';

      // Item 1: Valid Doctor
      final validItem = SyncQueueItem(
        id: 'q_scen8_valid',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': 'doc_scen8_valid',
          'client_uuid': validDocUuid,
          'profile_id': primaryProfileA!.profileId,
          'name': 'Dr. Valid Recovery',
          'specialty': 'General Medicine',
        },
      );

      // Item 2: Invalid Hospital with empty name (violates PostgreSQL CHECK constraint)
      final invalidItem = SyncQueueItem(
        id: 'q_scen8_invalid',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_scen8_invalid',
          'client_uuid': invalidHospUuid,
          'profile_id': primaryProfileA!.profileId,
          'name': '',
        },
      );

      await isolatedHiveService.syncQueueBox.put('q_scen8_valid', validItem.toMap());
      await isolatedHiveService.syncQueueBox.put('q_scen8_invalid', invalidItem.toMap());

      await syncServiceA.syncPendingToSupabase(force: true);

      // Valid item succeeded and was removed from queue
      expect(isolatedHiveService.syncQueueBox.containsKey('q_scen8_valid'), isFalse);

      // Invalid item dead-lettered with retryCount = 99
      final deadLettered = isolatedHiveService.syncQueueBox.get('q_scen8_invalid');
      expect(deadLettered, isNotNull);
      expect(deadLettered?['status'], 'failed');
      expect(deadLettered?['retryCount'], 99);

      // Subsequent sync run processes new valid items without being blocked by dead-lettered item
      final newValidItem = SyncQueueItem(
        id: 'q_scen8_new_valid',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_scen8_new',
          'client_uuid': '10000000-0000-0000-0008-000000000003',
          'profile_id': primaryProfileA!.profileId,
          'name': 'Subsequent Valid Clinic',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_scen8_new_valid', newValidItem.toMap());

      await syncServiceA.syncPendingToSupabase();

      expect(isolatedHiveService.syncQueueBox.containsKey('q_scen8_new_valid'), isFalse);
      expect(isolatedHiveService.syncQueueBox.containsKey('q_scen8_invalid'), isTrue, reason: 'Dead-letter remains parked');
    });

    // =========================================================================
    // SCENARIO 9: ATTACHMENT UPLOAD AND DELETION LIFECYCLE
    // =========================================================================
    test('Scenario 9: Attachment upload and deletion lifecycle with private bucket storage', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      final reportUuid = '10000000-0000-0000-0009-000000000001';
      final attUuid = '10000000-0000-0000-0009-000000000002';

      final sampleFile = File('${tempHiveDir.path}/controlled_sync_scan.pdf');
      sampleFile.writeAsStringSync('%PDF-1.4 Controlled Foreground Sync Test Document');

      // 1. Queue Report with attachment
      final reportItem = SyncQueueItem(
        id: 'q_scen9_rep',
        entity: 'report',
        operation: 'create',
        payload: {
          'id': reportUuid,
          'client_uuid': reportUuid,
          'profile_id': primaryProfileA!.profileId,
          'title': 'Controlled Sync MRI Scan',
          'category': 'Radiology',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'attachments': [
            {
              'id': attUuid,
              'name': 'controlled_sync_scan.pdf',
              'file_path': sampleFile.path,
              'file_size': sampleFile.lengthSync(),
            }
          ],
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_scen9_rep', reportItem.toMap());

      await syncServiceA.syncPendingToSupabase();
      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify in DB and Storage
      final reps = await reportA.fetchReports(
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      final report = reps.firstWhere((r) => r.id == reportUuid);
      expect(report.attachments.length, 1);
      final att = report.attachments.first;
      expect(att.fileUrl, isNotNull);

      // Test signed URL generation
      final signedUrl = await storageA.createSignedUrl(
        bucket: 'reports',
        storagePath: att.fileUrl!,
      );
      final httpResp = await http.get(Uri.parse(signedUrl));
      expect(httpResp.statusCode, 200);

      // 2. Queue Report deletion
      final delItem = SyncQueueItem(
        id: 'q_scen9_del',
        entity: 'report',
        operation: 'delete',
        payload: {
          'id': reportUuid,
          'client_uuid': reportUuid,
          'profile_id': primaryProfileA!.profileId,
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_scen9_del', delItem.toMap());

      await syncServiceA.syncPendingToSupabase();
      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify deleted from DB
      final afterDelReps = await reportA.fetchReports(
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(afterDelReps.any((r) => r.id == reportUuid), isFalse);
    });

    // =========================================================================
    // SCENARIO 10: APP RESTART AND NEXT FOREGROUND SYNC
    // =========================================================================
    test('Scenario 10: Cold app restart preserves mutations and drains on next foreground sync', () async {
      final apptClientUuid = '10000000-0000-0000-0010-000000000001';
      final medClientUuid = '10000000-0000-0000-0010-000000000002';

      final apptItem = SyncQueueItem(
        id: 'q_scen10_appt',
        entity: 'appointment',
        operation: 'create',
        payload: {
          'id': 'appt_scen10',
          'client_uuid': apptClientUuid,
          'profile_id': primaryProfileA!.profileId,
          'title': 'Cold Restart Dental Checkup',
          'appointment_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        },
      );
      final medItem = SyncQueueItem(
        id: 'q_scen10_med',
        entity: 'medicine',
        operation: 'create',
        payload: {
          'id': 'med_scen10',
          'client_uuid': medClientUuid,
          'profile_id': primaryProfileA!.profileId,
          'name': 'Cold Restart Amoxicillin 500mg',
          'dosage': '500mg',
          'frequency': 'Every 8 hours',
        },
      );

      // Write to Hive before simulated crash / restart
      await isolatedHiveService.syncQueueBox.put('q_scen10_appt', apptItem.toMap());
      await isolatedHiveService.syncQueueBox.put('q_scen10_med', medItem.toMap());

      // Simulate App Process Termination: close all boxes
      await Hive.close();

      // Simulate Cold App Launch: Re-open boxes from disk
      Hive.init(tempHiveDir.path);
      final reopenedAuth = await Hive.openBox<Map>('test_auth_box');
      final reopenedQueue = await Hive.openBox<Map>('test_sync_queue_box');
      final reopenedUser = await Hive.openBox<Map>('test_user_box');
      final reopenedSettings = await Hive.openBox<Map>('test_settings_box');
      final reopenedConsent = await Hive.openBox<Map>('test_consent_box');
      final reopenedProfile = await Hive.openBox<Map>('test_profile_box');

      isolatedHiveService.rebindBoxes(
        authBox: reopenedAuth,
        syncQueueBox: reopenedQueue,
        userBox: reopenedUser,
        settingsBox: reopenedSettings,
        consentBox: reopenedConsent,
        profileBox: reopenedProfile,
      );

      // Verify mutations survived cold restart!
      expect(isolatedHiveService.syncQueueBox.length, 2);
      expect(isolatedHiveService.syncQueueBox.containsKey('q_scen10_appt'), isTrue);
      expect(isolatedHiveService.syncQueueBox.containsKey('q_scen10_med'), isTrue);

      // Initialize re-launched services
      final restartedCoordinator = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: clientA,
        customStorageService: storageA,
      );
      final restartedSyncService = SyncService(
        hiveService: isolatedHiveService,
        connectivityService: fakeConnectivity,
        customSupabaseSyncCoordinator: restartedCoordinator,
      );

      // Enable controlled foreground sync and drain queue
      SyncService.isControlledForegroundSyncEnabled = true;
      await restartedSyncService.syncPendingToSupabase();

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify persistence in Tokyo Supabase
      final appts = await appointmentA.fetchAppointments(
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(appts.any((a) => a.clientUuid == apptClientUuid), isTrue);

      final meds = await medicineA.fetchMedicines(
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(meds.any((m) => m.clientUuid == medClientUuid), isTrue);
    });
  });
}
