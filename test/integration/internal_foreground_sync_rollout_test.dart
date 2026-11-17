// ignore_for_file: depend_on_referenced_packages, prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/foreground_resume_sync.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_lock.dart';
import 'package:medi_crate/core/sync/sync_providers.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
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

  group('Implementation 7.3: Internal Foreground Sync Rollout & Opt-In Safety', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailTesterA = 'sync_rollout_tester_$timestamp@fldubai.com';
    final emailUserB = 'sync_rollout_standard_$timestamp@fldubai.com';
    const password = 'RolloutPassword123!';

    late SupabaseClient clientA;
    late SupabaseClient clientB;
    late SupabaseAuthRemoteDataSource authA;
    late SupabaseAuthRemoteDataSource authB;
    late SupabaseProfileRemoteDataSource profileDataSourceA;
    late SupabaseProfileRemoteDataSource profileDataSourceB;
    late SupabaseHospitalRemoteDataSource hospitalDataSourceA;
    late SupabaseDoctorRemoteDataSource doctorDataSourceA;
    late SupabaseConsultationRemoteDataSource consultationDataSourceA;
    late SupabaseAppointmentRemoteDataSource appointmentDataSourceA;
    late SupabaseMedicineRemoteDataSource medicineDataSourceA;
    late SupabaseReportRemoteDataSource reportDataSourceA;
    late SupabaseVitalsRemoteDataSource vitalsDataSourceA;
    late SupabaseStorageService storageServiceA;

    String? userAId;
    String? userBId;
    ProfileModel? profileA;
    ProfileModel? profileB;

    late Directory tempHiveDir;
    late IsolatedHiveService isolatedHiveService;
    late _FakeConnectivityService fakeConnectivity;
    late SupabaseSyncCoordinator coordinatorA;
    late SyncService syncService;

    SupabaseClient createClient() {
      return SupabaseClient(
        supabaseUrl,
        anonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    }

    Future<void> confirmUser(String userEmail) async {
      for (var attempt = 1; attempt <= 3; attempt++) {
        final res = await Process.run('supabase', [
          'db',
          'query',
          '--linked',
          "UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = '$userEmail';",
        ]);
        if (res.exitCode == 0) return;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    setUpAll(() async {
      clientA = createClient();
      clientB = createClient();
      authA = SupabaseAuthRemoteDataSource(clientA);
      authB = SupabaseAuthRemoteDataSource(clientB);

      profileDataSourceA = SupabaseProfileRemoteDataSource(customClient: clientA);
      profileDataSourceB = SupabaseProfileRemoteDataSource(customClient: clientB);
      hospitalDataSourceA = SupabaseHospitalRemoteDataSource(customClient: clientA);
      doctorDataSourceA = SupabaseDoctorRemoteDataSource(customClient: clientA);
      consultationDataSourceA = SupabaseConsultationRemoteDataSource(client: clientA);
      appointmentDataSourceA = SupabaseAppointmentRemoteDataSource(client: clientA);
      medicineDataSourceA = SupabaseMedicineRemoteDataSource(client: clientA);
      reportDataSourceA = SupabaseReportRemoteDataSource(client: clientA);
      vitalsDataSourceA = SupabaseVitalsRemoteDataSource(client: clientA);
      storageServiceA = SupabaseStorageService(customClient: clientA);

      // 1. Sign up and confirm User A (Eligible Tester)
      await authA.signUp(
        name: 'Internal Rollout Tester A',
        email: emailTesterA,
        password: password,
      );
      await confirmUser(emailTesterA);

      final resA = await clientA.auth.signInWithPassword(
        email: emailTesterA,
        password: password,
      );
      userAId = resA.user?.id;
      expect(userAId, isNotNull);

      final profilesA = await profileDataSourceA.fetchProfiles(ownerUserId: userAId!);
      profileA = profilesA.firstWhere((p) => p.isPrimary);

      // 2. Sign up and confirm User B (Standard Ineligible User)
      await authB.signUp(
        name: 'Standard User B',
        email: emailUserB,
        password: password,
      );
      await confirmUser(emailUserB);

      final resB = await clientB.auth.signInWithPassword(
        email: emailUserB,
        password: password,
      );
      userBId = resB.user?.id;
      expect(userBId, isNotNull);

      final profilesB = await profileDataSourceB.fetchProfiles(ownerUserId: userBId!);
      profileB = profilesB.firstWhere((p) => p.isPrimary);

      // 3. Isolated Hive storage
      tempHiveDir = await Directory.systemTemp.createTemp('medi_crate_rollout_test_');
      Hive.init(tempHiveDir.path);

      final authBox = await Hive.openBox<Map>('ro_test_auth_box');
      final syncQueueBox = await Hive.openBox<Map>('ro_test_sync_queue_box');
      final userBox = await Hive.openBox<Map>('ro_test_user_box');
      final settingsBox = await Hive.openBox<Map>('ro_test_settings_box');
      final consentBox = await Hive.openBox<Map>('ro_test_consent_box');
      final profileBox = await Hive.openBox<Map>('ro_test_profile_box');

      isolatedHiveService = IsolatedHiveService(
        authBox: authBox,
        syncQueueBox: syncQueueBox,
        userBox: userBox,
        settingsBox: settingsBox,
        consentBox: consentBox,
        profileBox: profileBox,
      );

      await profileBox.put(profileA!.profileId, profileA!.toMap());
      await profileBox.put('prof_${profileA!.profileId}', profileA!.toMap());

      fakeConnectivity = _FakeConnectivityService();
      coordinatorA = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: clientA,
        customStorageService: storageServiceA,
      );
      syncService = SyncService(
        hiveService: isolatedHiveService,
        connectivityService: fakeConnectivity,
        customSupabaseSyncCoordinator: coordinatorA,
      );
    });

    tearDownAll(() async {
      // 1. Storage cleanup
      for (final uid in [userAId, userBId]) {
        if (uid != null) {
          try {
            await storageServiceA.deleteParentFolder(
              bucket: 'reports',
              userId: uid,
              parentId: '',
            );
          } catch (_) {}
        }
      }

      // 2. Auth cleanup
      await Process.run('supabase', [
        'db',
        'query',
        '--linked',
        "DELETE FROM auth.users WHERE email IN ('$emailTesterA', '$emailUserB');",
      ]);

      // 3. Hive cleanup
      try {
        await Hive.close();
        if (tempHiveDir.existsSync()) {
          tempHiveDir.deleteSync(recursive: true);
        }
      } catch (_) {}

      // 4. Reset static flags
      SyncService.authorizedTesterUserIds.clear();
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
    });

    setUp(() async {
      await isolatedHiveService.syncQueueBox.clear();
      await isolatedHiveService.settingsBox.clear();
      SyncService.authorizedTesterUserIds.clear();
      fakeConnectivity.isOnline = true;
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
    });

    ProviderContainer createContainer({
      UserModel? currentUser,
      ProfileModel? activeProfile,
      SupabaseClient? customClient,
      SupabaseProfileRemoteDataSource? customProfileDataSource,
      SupabaseSyncCoordinator? customCoordinator,
    }) {
      final userModel = currentUser ??
          UserModel(id: userAId!, email: emailTesterA, name: 'Rollout Tester A');
      final currentProf = activeProfile ?? profileA;

      final authState = AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: userModel,
      );

      final cl = customClient ?? clientA;
      final profDs = customProfileDataSource ?? profileDataSourceA;
      final coord = customCoordinator ?? coordinatorA;

      return ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthNotifier(initialState: authState),
          ),
          hiveServiceProvider.overrideWithValue(isolatedHiveService),
          connectivityServiceProvider.overrideWithValue(fakeConnectivity),
          supabaseClientProvider.overrideWithValue(cl),
          supabaseSyncCoordinatorProvider.overrideWithValue(coord),
          syncServiceProvider.overrideWithValue(syncService),
          activeProfileProvider.overrideWith(
            () => _TestActiveProfileNotifier(currentProf),
          ),
          supabaseProfileRemoteDataSourceProvider.overrideWithValue(profDs),
          supabaseHospitalRemoteDataSourceProvider.overrideWithValue(hospitalDataSourceA),
          supabaseDoctorRemoteDataSourceProvider.overrideWithValue(doctorDataSourceA),
          supabaseConsultationRemoteDataSourceProvider.overrideWithValue(consultationDataSourceA),
          supabaseAppointmentRemoteDataSourceProvider.overrideWithValue(appointmentDataSourceA),
          supabaseMedicineRemoteDataSourceProvider.overrideWithValue(medicineDataSourceA),
          supabaseReportRemoteDataSourceProvider.overrideWithValue(reportDataSourceA),
          supabaseVitalsRemoteDataSourceProvider.overrideWithValue(vitalsDataSourceA),
        ],
      );
    }

    // -------------------------------------------------------------------------
    // Scenario 1: Eligible tester with opt-in triggers foreground sync
    // -------------------------------------------------------------------------
    test('1. Eligible tester with opt-in triggers foreground sync and dispatches to Supabase', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      expect(SyncService.isEligibleTester(userAId!), isTrue);
      expect(syncService.isTesterOptedIn(userAId!), isTrue);

      final hospUuid = UuidUtils.generateV4();
      final hospClientUuid = UuidUtils.generateV4();
      final item = SyncQueueItem(
        id: 'q_rollout_1',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': hospUuid,
          'profile_id': profileA!.profileId,
          'name': 'Rollout Beta Medical Center',
          'client_uuid': hospClientUuid,
          'owner_user_id': userAId!,
        },
      );
      await isolatedHiveService.syncQueueBox.put(item.id, item.toMap());
      expect(isolatedHiveService.syncQueueBox.length, equals(1));

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isTrue);
      expect(result.message, equals('All changes synchronized.'));
      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify remote record in PostgreSQL
      final rows = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', hospClientUuid);
      expect(rows, isNotEmpty);
      expect(rows.first['name'], equals('Rollout Beta Medical Center'));
      expect(rows.first['user_id'], equals(userAId));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Eligible tester without opt-in is blocked
    // -------------------------------------------------------------------------
    test('2. Eligible tester without opt-in is blocked from foreground synchronization', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      // User A is authorized but has NOT opted in
      expect(SyncService.isEligibleTester(userAId!), isTrue);
      expect(syncService.isTesterOptedIn(userAId!), isFalse);

      final hospUuid = UuidUtils.generateV4();
      final hospClientUuid = UuidUtils.generateV4();
      final item = SyncQueueItem(
        id: 'q_rollout_2',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': hospUuid,
          'profile_id': profileA!.profileId,
          'name': 'Unopted Hospital',
          'client_uuid': hospClientUuid,
          'owner_user_id': userAId!,
        },
      );
      await isolatedHiveService.syncQueueBox.put(item.id, item.toMap());

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('requires opt-in'));
      expect(isolatedHiveService.syncQueueBox.length, equals(1));

      // Remote record must NOT exist
      final rows = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', hospClientUuid);
      expect(rows, isEmpty);

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Ineligible authenticated user is blocked
    // -------------------------------------------------------------------------
    test('3. Ineligible authenticated user is blocked even if opt-in flag exists in settings', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      // User B is NOT in authorizedTesterUserIds
      await syncService.setTesterOptIn(userBId!, true);

      expect(SyncService.isEligibleTester(userBId!), isFalse);
      expect(syncService.isTesterOptedIn(userBId!), isTrue);

      final hospUuid = UuidUtils.generateV4();
      final hospClientUuid = UuidUtils.generateV4();
      final item = SyncQueueItem(
        id: 'q_rollout_3',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': hospUuid,
          'profile_id': profileB!.profileId,
          'name': 'Ineligible Hospital',
          'client_uuid': hospClientUuid,
          'owner_user_id': userBId!,
        },
      );
      await isolatedHiveService.syncQueueBox.put(item.id, item.toMap());

      final coordinatorB = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: clientB,
      );

      final container = createContainer(
        currentUser: UserModel(id: userBId!, email: emailUserB, name: 'Standard User B'),
        activeProfile: profileB,
        customClient: clientB,
        customProfileDataSource: profileDataSourceB,
        customCoordinator: coordinatorB,
      );

      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('restricted to authorized internal testers'));
      expect(isolatedHiveService.syncQueueBox.length, equals(1));

      // Remote record must NOT exist
      final rows = await clientB
          .from('hospitals')
          .select()
          .eq('client_uuid', hospClientUuid);
      expect(rows, isEmpty);

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Unauthenticated user is blocked
    // -------------------------------------------------------------------------
    test('4. Unauthenticated user is blocked immediately without attempting remote dispatch', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      final item = SyncQueueItem(
        id: 'q_rollout_4',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'profile_id': profileA!.profileId,
          'name': 'Unauthenticated Hospital',
          'client_uuid': UuidUtils.generateV4(),
        },
      );
      await isolatedHiveService.syncQueueBox.put(item.id, item.toMap());

      final unauthContainer = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthNotifier(
              initialState: const AuthState(
                isLoading: false,
                isAuthenticated: false,
                user: null,
              ),
            ),
          ),
          hiveServiceProvider.overrideWithValue(isolatedHiveService),
          connectivityServiceProvider.overrideWithValue(fakeConnectivity),
          supabaseClientProvider.overrideWithValue(clientA),
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );

      final result = await unauthContainer
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Active authenticated session required'));
      expect(isolatedHiveService.syncQueueBox.length, equals(1));

      unauthContainer.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Account switching cannot reuse eligibility or opt-in
    // -------------------------------------------------------------------------
    test('5. Account switching prevents User B from inheriting User A eligibility or opt-in', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      // Verify User A is eligible and opted in
      expect(SyncService.isEligibleTester(userAId!), isTrue);
      expect(syncService.isTesterOptedIn(userAId!), isTrue);

      // Verify User B is completely unconfigured
      expect(SyncService.isEligibleTester(userBId!), isFalse);
      expect(syncService.isTesterOptedIn(userBId!), isFalse);

      final coordinatorB = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: clientB,
      );

      // User B logs in on same device
      final containerB = createContainer(
        currentUser: UserModel(id: userBId!, email: emailUserB, name: 'Standard User B'),
        activeProfile: profileB,
        customClient: clientB,
        customProfileDataSource: profileDataSourceB,
        customCoordinator: coordinatorB,
      );

      // Reactive opt-in provider must evaluate to false for User B
      expect(containerB.read(syncOptInProvider), isFalse);
      expect(containerB.read(isEligibleTesterProvider), isFalse);

      // User B attempts force sync -> blocked
      final resultB1 = await containerB
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();
      expect(resultB1.isSuccess, isFalse);
      expect(resultB1.message, contains('restricted to authorized internal testers'));

      // Now authorize User B as tester, but User B has NOT opted in
      SyncService.authorizeTester(userBId!);
      containerB.refresh(isEligibleTesterProvider);
      expect(containerB.read(isEligibleTesterProvider), isTrue);
      expect(containerB.read(syncOptInProvider), isFalse);

      final resultB2 = await containerB
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();
      expect(resultB2.isSuccess, isFalse);
      expect(resultB2.message, contains('requires opt-in'));

      // User A's opt-in remains isolated
      expect(syncService.isTesterOptedIn(userAId!), isTrue);

      containerB.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Eligibility revalidated before dispatch
    // -------------------------------------------------------------------------
    test('6. Eligibility is revalidated right at dispatch boundary, aborting if revoked in flight', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      final hospUuid = UuidUtils.generateV4();
      final hospClientUuid = UuidUtils.generateV4();
      final item = SyncQueueItem(
        id: 'q_rollout_6',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': hospUuid,
          'profile_id': profileA!.profileId,
          'name': 'Revoked In-Flight Hospital',
          'client_uuid': hospClientUuid,
          'owner_user_id': userAId!,
        },
      );
      await isolatedHiveService.syncQueueBox.put(item.id, item.toMap());

      // Revoke eligibility before dispatch
      SyncService.revokeTester(userAId!);
      expect(SyncService.isEligibleTester(userAId!), isFalse);

      // Call low-level syncPending directly to test dispatch boundary enforcement
      await syncService.syncPending(
        force: true,
        explicitOwnerUserId: userAId!,
      );

      // Mutation MUST remain in Hive untouched
      expect(isolatedHiveService.syncQueueBox.length, equals(1));
      final rows = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', hospClientUuid);
      expect(rows, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Rollback (revocation/opt-out) blocks subsequent sync
    // -------------------------------------------------------------------------
    test('7. Rollback (revocation or opt-out) immediately halts subsequent sync operations', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      // Step 1: Successful sync
      final hospUuid1 = UuidUtils.generateV4();
      final clientUuid1 = UuidUtils.generateV4();
      final item1 = SyncQueueItem(
        id: 'q_rollout_7_1',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': hospUuid1,
          'profile_id': profileA!.profileId,
          'name': 'Step 1 Hospital',
          'client_uuid': clientUuid1,
          'owner_user_id': userAId!,
        },
      );
      await isolatedHiveService.syncQueueBox.put(item1.id, item1.toMap());

      final container = createContainer();
      final res1 = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();
      expect(res1.isSuccess, isTrue);
      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Step 2: Rollback via opt-out
      await syncService.setTesterOptIn(userAId!, false);
      expect(syncService.isTesterOptedIn(userAId!), isFalse);

      final hospUuid2 = UuidUtils.generateV4();
      final clientUuid2 = UuidUtils.generateV4();
      final item2 = SyncQueueItem(
        id: 'q_rollout_7_2',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': hospUuid2,
          'profile_id': profileA!.profileId,
          'name': 'Step 2 Hospital',
          'client_uuid': clientUuid2,
          'owner_user_id': userAId!,
        },
      );
      await isolatedHiveService.syncQueueBox.put(item2.id, item2.toMap());

      final res2 = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();
      expect(res2.isSuccess, isFalse);
      expect(res2.message, contains('requires opt-in'));
      expect(isolatedHiveService.syncQueueBox.length, equals(1));

      // Remote record 2 must NOT exist
      final rows2 = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', clientUuid2);
      expect(rows2, isEmpty);

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Rollback preserves pending Hive mutations
    // -------------------------------------------------------------------------
    test('8. Rollback preserves pending Hive mutations without burning retry counts', () async {
      SyncService.isControlledForegroundSyncEnabled = false; // Kill switch triggered
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      final itemA = SyncQueueItem(
        id: 'q_rollout_8_a',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'profile_id': profileA!.profileId,
          'name': 'Dr. Safe Offline',
          'client_uuid': UuidUtils.generateV4(),
        },
        retryCount: 0,
      );
      final itemB = SyncQueueItem(
        id: 'q_rollout_8_b',
        entity: 'medicine',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'profile_id': profileA!.profileId,
          'name': 'Paracetamol 500mg',
          'client_uuid': UuidUtils.generateV4(),
        },
        retryCount: 1,
      );

      await isolatedHiveService.syncQueueBox.put(itemA.id, itemA.toMap());
      await isolatedHiveService.syncQueueBox.put(itemB.id, itemB.toMap());
      expect(isolatedHiveService.syncQueueBox.length, equals(2));

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('Remote synchronization is disabled'));

      // Both items MUST remain in Hive completely unchanged
      expect(isolatedHiveService.syncQueueBox.length, equals(2));
      final storedA = SyncQueueItem.fromMap(
        Map<String, dynamic>.from(isolatedHiveService.syncQueueBox.get(itemA.id)!),
      );
      final storedB = SyncQueueItem.fromMap(
        Map<String, dynamic>.from(isolatedHiveService.syncQueueBox.get(itemB.id)!),
      );
      expect(storedA.retryCount, equals(0));
      expect(storedB.retryCount, equals(1));
      expect(storedA.payload['name'], equals('Dr. Safe Offline'));
      expect(storedB.payload['name'], equals('Paracetamol 500mg'));

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Background workers remain disabled
    // -------------------------------------------------------------------------
    test('9. Background sync remains strictly disabled under controlled foreground rollout', () {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);

      // Production invariant: BackgroundSyncService.isBackgroundSyncEnabled MUST evaluate strictly isRemoteSyncEnabled
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);

      // Verify that enabling controlled foreground sync or authorizing testers never enables background sync
      expect(
        BackgroundSyncService.isBackgroundSyncEnabled,
        equals(SyncService.isRemoteSyncEnabled),
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Existing ownership, profile isolation, SyncLock and queue recovery protections remain intact
    // -------------------------------------------------------------------------
    test('10. Cross-user isolation, profile boundaries, and SyncLock mutual exclusion remain intact', () async {
      SyncService.isControlledForegroundSyncEnabled = true;
      SyncService.authorizeTester(userAId!);
      await syncService.setTesterOptIn(userAId!, true);

      // A. Cross-user mutation deferred handling
      final foreignItem = SyncQueueItem(
        id: 'q_rollout_10_foreign',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': UuidUtils.generateV4(),
          'profile_id': profileB!.profileId,
          'name': 'Foreign Clinic',
          'client_uuid': UuidUtils.generateV4(),
          'owner_user_id': userBId!, // Belongs to User B!
        },
      );
      await isolatedHiveService.syncQueueBox.put(foreignItem.id, foreignItem.toMap());

      final container = createContainer();
      final result = await container
          .read(manualSyncControllerProvider.notifier)
          .triggerForceSync();

      expect(result.remainingTotalCount, greaterThanOrEqualTo(1));

      // Mutation for foreign user must NOT be synced, must be deferred safely
      expect(isolatedHiveService.syncQueueBox.containsKey(foreignItem.id), isTrue);
      final storedForeign = SyncQueueItem.fromMap(
        Map<String, dynamic>.from(isolatedHiveService.syncQueueBox.get(foreignItem.id)!),
      );
      expect(storedForeign.status, equals('deferred'));
      expect(storedForeign.errorMessage, contains('Cross-user mutation execution blocked'));

      // B. Cross-context SyncLock mutual exclusion
      final lock = SyncLock(isolatedHiveService.settingsBox);
      final lockToken = await lock.tryAcquire();
      expect(lockToken, isNotNull);

      // Another processor attempting to acquire must be locked out
      final competingToken = await lock.tryAcquire();
      expect(competingToken, isNull);

      // Release lock
      await lock.release(lockToken!);
      final afterReleaseToken = await lock.tryAcquire();
      expect(afterReleaseToken, isNotNull);
      await lock.release(afterReleaseToken!);

      // C. Foreground resume sync respects tester eligibility
      final unoptedContainer = createContainer();
      await syncService.setTesterOptIn(userAId!, false);
      // Resumed sync should be a clean no-op
      await runForegroundResumeSync(unoptedContainer);
      expect(isolatedHiveService.syncQueueBox.containsKey(foreignItem.id), isTrue);

      container.dispose();
      unoptedContainer.dispose();
    });
  });
}
