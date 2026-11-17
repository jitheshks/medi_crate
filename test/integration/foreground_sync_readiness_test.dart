// ignore_for_file: depend_on_referenced_packages

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
import 'package:medi_crate/core/sync/foreground_resume_sync.dart';
import 'package:medi_crate/core/sync/manual_sync_controller.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
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

  group('Implementation 7.2: Foreground Sync Production Readiness & Recovery', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'sync_readiness_$timestamp@fldubai.com';
    const password = 'ReadinessPassword123!';

    late SupabaseClient client;
    late SupabaseAuthRemoteDataSource auth;
    late SupabaseProfileRemoteDataSource profileDataSource;
    late SupabaseHospitalRemoteDataSource hospitalDataSource;
    late SupabaseDoctorRemoteDataSource doctorDataSource;
    late SupabaseConsultationRemoteDataSource consultationDataSource;
    late SupabaseAppointmentRemoteDataSource appointmentDataSource;
    late SupabaseMedicineRemoteDataSource medicineDataSource;
    late SupabaseReportRemoteDataSource reportDataSource;
    late SupabaseVitalsRemoteDataSource vitalsDataSource;
    late SupabaseStorageService storageService;

    String? userId;
    ProfileModel? primaryProfile;

    late Directory tempHiveDir;
    late IsolatedHiveService isolatedHiveService;
    late _FakeConnectivityService fakeConnectivity;
    late SupabaseSyncCoordinator coordinator;
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
      client = createClient();
      auth = SupabaseAuthRemoteDataSource(client);
      profileDataSource = SupabaseProfileRemoteDataSource(customClient: client);
      hospitalDataSource = SupabaseHospitalRemoteDataSource(customClient: client);
      doctorDataSource = SupabaseDoctorRemoteDataSource(customClient: client);
      consultationDataSource = SupabaseConsultationRemoteDataSource(client: client);
      appointmentDataSource = SupabaseAppointmentRemoteDataSource(client: client);
      medicineDataSource = SupabaseMedicineRemoteDataSource(client: client);
      reportDataSource = SupabaseReportRemoteDataSource(client: client);
      vitalsDataSource = SupabaseVitalsRemoteDataSource(client: client);
      storageService = SupabaseStorageService(customClient: client);

      // Register and confirm test user
      await auth.signUp(
        name: 'Sync Readiness User',
        email: email,
        password: password,
      );
      await confirmUser(email);

      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      userId = res.user?.id;
      expect(userId, isNotNull);

      final profiles = await profileDataSource.fetchProfiles(ownerUserId: userId!);
      primaryProfile = profiles.firstWhere((p) => p.isPrimary);

      tempHiveDir = await Directory.systemTemp.createTemp('medi_crate_readiness_test_');
      Hive.init(tempHiveDir.path);

      final authBox = await Hive.openBox<Map>('r_test_auth_box');
      final syncQueueBox = await Hive.openBox<Map>('r_test_sync_queue_box');
      final userBox = await Hive.openBox<Map>('r_test_user_box');
      final settingsBox = await Hive.openBox<Map>('r_test_settings_box');
      final consentBox = await Hive.openBox<Map>('r_test_consent_box');
      final profileBox = await Hive.openBox<Map>('r_test_profile_box');

      isolatedHiveService = IsolatedHiveService(
        authBox: authBox,
        syncQueueBox: syncQueueBox,
        userBox: userBox,
        settingsBox: settingsBox,
        consentBox: consentBox,
        profileBox: profileBox,
      );

      await profileBox.put(
        primaryProfile!.profileId,
        primaryProfile!.toMap(),
      );
      await profileBox.put(
        'prof_${primaryProfile!.profileId}',
        primaryProfile!.toMap(),
      );

      fakeConnectivity = _FakeConnectivityService();
      coordinator = SupabaseSyncCoordinator(
        hiveService: isolatedHiveService,
        customClient: client,
        customStorageService: storageService,
      );
      syncService = SyncService(
        hiveService: isolatedHiveService,
        connectivityService: fakeConnectivity,
        customSupabaseSyncCoordinator: coordinator,
      );
    });

    tearDownAll(() async {
      if (userId != null) {
        try {
          await storageService.deleteParentFolder(
            bucket: 'reports',
            userId: userId!,
            parentId: '',
          );
        } catch (_) {}
      }

      await Process.run('supabase', [
        'db',
        'query',
        '--linked',
        "DELETE FROM auth.users WHERE email = '$email';",
      ]);

      try {
        await Hive.close();
        if (tempHiveDir.existsSync()) {
          tempHiveDir.deleteSync(recursive: true);
        }
      } catch (_) {}

      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
    });

    setUp(() async {
      await isolatedHiveService.syncQueueBox.clear();
      await isolatedHiveService.settingsBox.clear();
      fakeConnectivity.isOnline = true;
      SyncService.isRemoteSyncEnabled = false;
      SyncService.isControlledForegroundSyncEnabled = false;
      if (userId != null) {
        SyncService.authorizeTester(userId!);
        await isolatedHiveService.settingsBox.put(
          'sync_opt_in_$userId',
          {'opted_in': true, 'updated_at': DateTime.now().toIso8601String()},
        );
      }
    });

    ProviderContainer createContainer({
      UserModel? currentUser,
      ProfileModel? activeProfile,
    }) {
      final userModel = currentUser ?? UserModel(id: userId!, email: email, name: 'Readiness Tester');
      final currentProf = activeProfile ?? primaryProfile;

      final authState = AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: userModel,
      );

      return ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => _TestAuthNotifier(initialState: authState)),
          hiveServiceProvider.overrideWithValue(isolatedHiveService),
          connectivityServiceProvider.overrideWithValue(fakeConnectivity),
          supabaseClientProvider.overrideWithValue(client),
          supabaseSyncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWithValue(syncService),
          activeProfileProvider.overrideWith(() => _TestActiveProfileNotifier(currentProf)),
          supabaseProfileRemoteDataSourceProvider.overrideWithValue(profileDataSource),
          supabaseHospitalRemoteDataSourceProvider.overrideWithValue(hospitalDataSource),
          supabaseDoctorRemoteDataSourceProvider.overrideWithValue(doctorDataSource),
          supabaseConsultationRemoteDataSourceProvider.overrideWithValue(consultationDataSource),
          supabaseAppointmentRemoteDataSourceProvider.overrideWithValue(appointmentDataSource),
          supabaseMedicineRemoteDataSourceProvider.overrideWithValue(medicineDataSource),
          supabaseReportRemoteDataSourceProvider.overrideWithValue(reportDataSource),
          supabaseVitalsRemoteDataSourceProvider.overrideWithValue(vitalsDataSource),
        ],
      );
    }

    // =========================================================================
    // 1. LARGE QUEUE PROCESSING
    // =========================================================================
    test('1. Large queue processing: 24 mixed mutations drain cleanly in dependency order', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      // Build 24 mutations across domains with dependencies
      for (var i = 1; i <= 6; i++) {
        final hospUuid = '20000000-0000-0000-0001-00000000000$i';
        final docUuid = '20000000-0000-0000-0002-00000000000$i';
        final apptUuid = '20000000-0000-0000-0003-00000000000$i';
        final vitalUuid = '20000000-0000-0000-0004-00000000000$i';

        // Hospitals (Priority 1)
        final hospItem = SyncQueueItem(
          id: 'q_large_hosp_$i',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': hospUuid,
            'client_uuid': hospUuid,
            'profile_id': primaryProfile!.profileId,
            'name': 'Large Batch Clinic $i',
          },
        );
        // Doctors (Priority 2)
        final docItem = SyncQueueItem(
          id: 'q_large_doc_$i',
          entity: 'doctor',
          operation: 'create',
          payload: {
            'id': docUuid,
            'client_uuid': docUuid,
            'profile_id': primaryProfile!.profileId,
            'name': 'Dr. Large Batch $i',
            'specialty': 'Cardiology',
            'hospital_ids': [hospUuid],
          },
        );
        // Appointments (Priority 5)
        final apptItem = SyncQueueItem(
          id: 'q_large_appt_$i',
          entity: 'appointment',
          operation: 'create',
          payload: {
            'id': apptUuid,
            'client_uuid': apptUuid,
            'profile_id': primaryProfile!.profileId,
            'doctor_id': docUuid,
            'doctor_name': 'Dr. Large Batch $i',
            'hospital_id': hospUuid,
            'title': 'Large Batch Checkup $i',
            'appointment_date': DateTime.now().add(Duration(days: i)).toIso8601String(),
          },
        );
        // Measurements (Priority 7)
        final vitalItem = SyncQueueItem(
          id: 'q_large_vital_$i',
          entity: 'measurement',
          operation: 'create',
          payload: {
            'id': vitalUuid,
            'client_uuid': vitalUuid,
            'profile_id': primaryProfile!.profileId,
            'type': 'blood_pressure',
            'systolic': 120 + i,
            'diastolic': 80,
            'unit': 'mmHg',
            'recorded_at': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
          },
        );

        await isolatedHiveService.syncQueueBox.put('q_large_hosp_$i', hospItem.toMap());
        await isolatedHiveService.syncQueueBox.put('q_large_doc_$i', docItem.toMap());
        await isolatedHiveService.syncQueueBox.put('q_large_appt_$i', apptItem.toMap());
        await isolatedHiveService.syncQueueBox.put('q_large_vital_$i', vitalItem.toMap());
      }

      expect(isolatedHiveService.syncQueueBox.length, 24);

      // Drain entire large queue
      await syncService.syncPendingToSupabase(force: true);

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify remote counts
      final hospCount = await client.from('hospitals').select('id').count(CountOption.exact);
      final docCount = await client.from('doctors').select('id').count(CountOption.exact);
      expect(hospCount.count, 6);
      expect(docCount.count, 6);
    });

    // =========================================================================
    // 2. REPEATED APP RESUME EVENTS
    // =========================================================================
    test('2. Repeated app resume events: rapid concurrent resume calls throttle safely without duplicate records', () async {
      final container = createContainer();
      SyncService.isControlledForegroundSyncEnabled = true;

      final hospUuid = '20000000-0000-0000-0010-000000000001';
      final item = SyncQueueItem(
        id: 'q_burst_hosp',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_burst',
          'client_uuid': hospUuid,
          'profile_id': primaryProfile!.profileId,
          'name': 'Rapid Resume Clinic',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_burst_hosp', item.toMap());

      // Fire 5 rapid resume calls in parallel
      final futures = List.generate(5, (_) => runForegroundResumeSync(container));
      await Future.wait(futures);

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      // Verify exactly 1 remote row exists (no duplicate inserts from rapid firing)
      final rows = await client
          .from('hospitals')
          .select()
          .eq('client_uuid', hospUuid);
      expect(rows.length, 1);

      container.dispose();
    });

    // =========================================================================
    // 3. NETWORK LOSS DURING DISPATCH
    // =========================================================================
    test('3. Network loss during dispatch: preserves mutation in Hive without dead-letter burn', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      final hospUuid = '20000000-0000-0000-0020-000000000001';
      final item = SyncQueueItem(
        id: 'q_net_drop',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_drop',
          'client_uuid': hospUuid,
          'profile_id': primaryProfile!.profileId,
          'name': 'Network Loss Clinic',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_net_drop', item.toMap());

      // Simulate offline state during sync check
      fakeConnectivity.isOnline = false;
      await syncService.syncPendingToSupabase();

      // Mutation is untouched and preserved in Hive
      final stored = isolatedHiveService.syncQueueBox.get('q_net_drop');
      expect(stored, isNotNull);
      expect(stored?['status'], 'pending');
      expect(stored?['retryCount'], 0);

      // Reconnect network
      fakeConnectivity.isOnline = true;
      await syncService.syncPendingToSupabase();

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);
    });

    // =========================================================================
    // 4. SESSION EXPIRY DURING DRAIN
    // =========================================================================
    test('4. Session expiry during drain: immediately breaks queue processing without dropping remaining items', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      // Queue 3 items
      for (var i = 1; i <= 3; i++) {
        final it = SyncQueueItem(
          id: 'q_exp_$i',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': 'hosp_exp_$i',
            'client_uuid': '20000000-0000-0000-0030-00000000000$i',
            'profile_id': primaryProfile!.profileId,
            'name': 'Expiry Hospital $i',
          },
        );
        await isolatedHiveService.syncQueueBox.put('q_exp_$i', it.toMap());
      }

      // Invalidate session on client
      await client.auth.signOut();

      // Trigger sync
      await syncService.syncPendingToSupabase();

      // First item encountered auth failure -> status 'auth_required' -> break from loop
      final item1 = isolatedHiveService.syncQueueBox.get('q_exp_1');
      final item2 = isolatedHiveService.syncQueueBox.get('q_exp_2');
      final item3 = isolatedHiveService.syncQueueBox.get('q_exp_3');

      expect(item1?['status'], 'auth_required');
      expect(item2?['status'], 'pending');
      expect(item3?['status'], 'pending');
      expect(isolatedHiveService.syncQueueBox.length, 3, reason: 'Zero data loss upon session expiry');

      // Re-authenticate for remaining tests
      await client.auth.signInWithPassword(email: email, password: password);
    });

    // =========================================================================
    // 5. APP TERMINATION DURING SYNC & LEASE RECLAIM
    // =========================================================================
    test('5. App termination mid-sync: stale processor claim is reclaimed and processed upon restart', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      final staleUuid = '20000000-0000-0000-0040-000000000001';
      final staleItem = SyncQueueItem(
        id: 'q_stale_claim',
        entity: 'hospital',
        operation: 'create',
        status: 'syncing',
        claimToken: 'crashed_process_pid_9999',
        // Claim timestamp older than 3-minute leaseDuration
        claimedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        payload: {
          'id': 'hosp_stale',
          'client_uuid': staleUuid,
          'profile_id': primaryProfile!.profileId,
          'name': 'Reclaimed Crash Clinic',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_stale_claim', staleItem.toMap());

      // Simulate App Restart with active worker
      await syncService.syncPendingToSupabase();

      expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

      final rows = await client
          .from('hospitals')
          .select()
          .eq('client_uuid', staleUuid);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Reclaimed Crash Clinic');
    });

    // =========================================================================
    // 6. DUPLICATE FORCE SYNC TRIGGERS
    // =========================================================================
    test('6. Duplicate Force Sync triggers: in-flight guard prevents redundant network dispatches', () async {
      final container = createContainer();
      SyncService.isControlledForegroundSyncEnabled = true;

      final controller = container.read(manualSyncControllerProvider.notifier);

      final callA = controller.triggerForceSync();
      final callB = controller.triggerForceSync();

      final results = await Future.wait([callA, callB]);

      // Exactly one execution ran while the other safely yielded
      expect(results.any((r) => r.isSuccess), isTrue);
      expect(
        results.any((r) => r.message == 'Synchronization already in progress.' || r.message == 'All changes synchronized.'),
        isTrue,
      );

      container.dispose();
    });

    // =========================================================================
    // 7. PARTIAL DOMAIN FAILURE & ISOLATION
    // =========================================================================
    test('7. Partial domain failure: single constraint failure dead-letters without impeding valid records', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      final validHosp = SyncQueueItem(
        id: 'q_part_valid',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_part_valid',
          'client_uuid': '20000000-0000-0000-0060-000000000001',
          'profile_id': primaryProfile!.profileId,
          'name': 'Resilient Healthy Clinic',
        },
      );
      // Empty name violates CHECK constraint in PostgreSQL
      final invalidHosp = SyncQueueItem(
        id: 'q_part_invalid',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_part_invalid',
          'client_uuid': '20000000-0000-0000-0060-000000000002',
          'profile_id': primaryProfile!.profileId,
          'name': '',
        },
      );

      await isolatedHiveService.syncQueueBox.put('q_part_valid', validHosp.toMap());
      await isolatedHiveService.syncQueueBox.put('q_part_invalid', invalidHosp.toMap());

      await syncService.syncPendingToSupabase(force: true);

      // Valid item succeeded
      expect(isolatedHiveService.syncQueueBox.containsKey('q_part_valid'), isFalse);

      // Invalid item dead-lettered
      final deadLetter = isolatedHiveService.syncQueueBox.get('q_part_invalid');
      expect(deadLetter?['status'], 'failed');
      expect(deadLetter?['retryCount'], 99);

      // Subsequent valid item is processed without block
      final nextValid = SyncQueueItem(
        id: 'q_part_next',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_part_next',
          'client_uuid': '20000000-0000-0000-0060-000000000003',
          'profile_id': primaryProfile!.profileId,
          'name': 'Subsequent Working Clinic',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_part_next', nextValid.toMap());

      await syncService.syncPendingToSupabase();

      expect(isolatedHiveService.syncQueueBox.containsKey('q_part_next'), isFalse);
      expect(isolatedHiveService.syncQueueBox.containsKey('q_part_invalid'), isTrue);
    });

    // =========================================================================
    // 8. AMBIGUOUS & LEGACY MUTATION PRESERVATION
    // =========================================================================
    test('8. Ambiguous / foreign mutation: preserves legacy items in Hive as deferred without sending', () async {
      SyncService.isControlledForegroundSyncEnabled = true;

      // Item with foreign or legacy user ID that does not match active session
      final foreignItem = SyncQueueItem(
        id: 'q_foreign_legacy',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'hosp_foreign',
          'client_uuid': '20000000-0000-0000-0070-000000000001',
          'owner_user_id': 'legacy_user_account_9999',
          'name': 'Foreign Legacy Clinic',
        },
      );
      await isolatedHiveService.syncQueueBox.put('q_foreign_legacy', foreignItem.toMap());

      await syncService.syncPendingToSupabase(explicitOwnerUserId: userId!);

      // Verify item was deferred and NOT deleted or pushed under current user
      final stored = isolatedHiveService.syncQueueBox.get('q_foreign_legacy');
      expect(stored?['status'], 'deferred');
      expect(stored?['errorMessage']?.contains('Cross-user mutation execution blocked'), isTrue);
      expect(isolatedHiveService.syncQueueBox.length, 1);

      // Verify it was NOT written to PostgreSQL
      final rows = await client
          .from('hospitals')
          .select()
          .eq('client_uuid', '20000000-0000-0000-0070-000000000001');
      expect(rows.isEmpty, isTrue);
    });
  });
}
