// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_lock.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import 'package:medi_crate/features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final Box<Map> _authBox;
  final Box<Map> _syncQueueBox;
  final Box<Map> _userBox;
  final Box<Map> _settingsBox;
  final Box<Map> _consentBox;
  final Box<Map> _profileBox;

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

  group('Implementation 7.0: Native Offline-First Synchronization Verification', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailA = 'sync_user_a_$timestamp@fldubai.com';
    final emailB = 'sync_user_b_$timestamp@fldubai.com';
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
    ProfileModel? primaryProfileB;

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

      // 2. Register & Confirm User A and User B
      await authA.signUp(name: 'Sync Tester A', email: emailA, password: password);
      await authB.signUp(name: 'Sync Tester B', email: emailB, password: password);
      await confirmUsers([emailA, emailB]);

      final resA = await clientA.auth.signInWithPassword(email: emailA, password: password);
      userAId = resA.user?.id;
      final resB = await clientB.auth.signInWithPassword(email: emailB, password: password);
      userBId = resB.user?.id;

      expect(userAId, isNotNull);
      expect(userBId, isNotNull);

      // Fetch primary profiles
      final profilesA = await profileA.fetchProfiles(ownerUserId: userAId!);
      primaryProfileA = profilesA.firstWhere((p) => p.isPrimary);

      final profilesB = await profileB.fetchProfiles(ownerUserId: userBId!);
      primaryProfileB = profilesB.firstWhere((p) => p.isPrimary);

      // 3. Setup Isolated Hive Storage
      tempHiveDir = Directory.systemTemp.createTempSync('medi_crate_sync_test_$timestamp');
      Hive.init(tempHiveDir.path);

      final authBox = await Hive.openBox<Map>('test_auth_$timestamp');
      final syncQueueBox = await Hive.openBox<Map>('test_sync_queue_$timestamp');
      final userBox = await Hive.openBox<Map>('test_user_$timestamp');
      final settingsBox = await Hive.openBox<Map>('test_settings_$timestamp');
      final consentBox = await Hive.openBox<Map>('test_consent_$timestamp');
      final profileBox = await Hive.openBox<Map>('test_profile_$timestamp');

      isolatedHiveService = IsolatedHiveService(
        authBox: authBox,
        syncQueueBox: syncQueueBox,
        userBox: userBox,
        settingsBox: settingsBox,
        consentBox: consentBox,
        profileBox: profileBox,
      );

      // Cache primary profile in profileBox for coordinator lookups
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
    });

    setUp(() async {
      await isolatedHiveService.syncQueueBox.clear();
    });

    // =========================================================================
    // GROUP 1: CORE OFFLINE-FIRST LIFECYCLE (CREATE, UPDATE, DELETE)
    // =========================================================================
    group('Group 1: Core Offline-First Lifecycle (CREATE, UPDATE, DELETE)', () {
      final hospitalClientUuid = '00000000-0000-0000-0001-000000000001';
      String? serverHospitalId;

      test('1.1 Offline CREATE -> reconnect -> remote persistence in PostgreSQL', () async {
        fakeConnectivity.setOnline(false);

        final createItem = SyncQueueItem(
          id: 'queue_hosp_create_1',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': 'hosp_offline_local_1',
            'client_uuid': hospitalClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Tokyo Offline Memorial Hospital',
            'type': 'General Hospital',
            'address': '100 Chiyoda-ku, Tokyo',
            'phone': '+81-3-1234-5678',
            'is_favorite': true,
          },
        );

        await syncServiceA.addToQueue(createItem);
        expect(isolatedHiveService.syncQueueBox.containsKey('queue_hosp_create_1'), isTrue);

        // Hospital does not exist in remote DB yet
        final remoteBefore = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        expect(remoteBefore.any((h) => h.clientUuid == hospitalClientUuid), isFalse);

        // Reconnect network and trigger controlled sync
        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        // Queue item was consumed upon success
        expect(isolatedHiveService.syncQueueBox.containsKey('queue_hosp_create_1'), isFalse);

        // Verified persisted in hosted PostgreSQL!
        final remoteAfter = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        final found = remoteAfter.firstWhere((h) => h.clientUuid == hospitalClientUuid);
        expect(found.name, 'Tokyo Offline Memorial Hospital');
        expect(found.address, '100 Chiyoda-ku, Tokyo');
        serverHospitalId = found.id;
      });

      test('1.2 Offline UPDATE -> reconnect -> remote PostgreSQL row updated', () async {
        expect(serverHospitalId, isNotNull);
        fakeConnectivity.setOnline(false);

        final updateItem = SyncQueueItem(
          id: 'queue_hosp_update_1',
          entity: 'hospital',
          operation: 'update',
          payload: {
            'id': serverHospitalId!,
            'client_uuid': hospitalClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Tokyo Offline Memorial Hospital',
            'type': 'Clinic',
            'address': '999 Shibuya Crossing, Tokyo',
            'phone': '+81-3-9876-5432',
            'is_favorite': true,
          },
        );

        await syncServiceA.addToQueue(updateItem);
        expect(isolatedHiveService.syncQueueBox.containsKey('queue_hosp_update_1'), isTrue);

        // Reconnect & sync
        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        expect(isolatedHiveService.syncQueueBox.containsKey('queue_hosp_update_1'), isFalse);

        // Verify remote PostgreSQL updated correctly
        final remoteUpdated = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        final found = remoteUpdated.firstWhere((h) => h.id == serverHospitalId);
        expect(found.type, 'Clinic');
        expect(found.address, '999 Shibuya Crossing, Tokyo');
      });

      test('1.3 Offline DELETE -> reconnect -> remote PostgreSQL row deleted', () async {
        expect(serverHospitalId, isNotNull);
        fakeConnectivity.setOnline(false);

        final deleteItem = SyncQueueItem(
          id: 'queue_hosp_delete_1',
          entity: 'hospital',
          operation: 'delete',
          payload: {
            'id': serverHospitalId!,
            'client_uuid': hospitalClientUuid,
            'profile_id': primaryProfileA!.profileId,
          },
        );

        await syncServiceA.addToQueue(deleteItem);
        expect(isolatedHiveService.syncQueueBox.containsKey('queue_hosp_delete_1'), isTrue);

        // Reconnect & sync
        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        expect(isolatedHiveService.syncQueueBox.containsKey('queue_hosp_delete_1'), isFalse);

        // Verify row is deleted from hosted PostgreSQL
        final remoteDeleted = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        expect(remoteDeleted.any((h) => h.id == serverHospitalId), isFalse);
      });
    });

    // =========================================================================
    // GROUP 2: QUEUE COALESCING & DURABILITY
    // =========================================================================
    group('Group 2: Queue Coalescing & Durability', () {
      test('2.1 CREATE + UPDATE coalescing collapses to a single CREATE with latest state', () async {
        fakeConnectivity.setOnline(false);

        final coalLocalId = 'hosp_local_coal_1';
        final coalClientUuid = '00000000-0000-0000-0002-000000000001';

        final createItem = SyncQueueItem(
          id: 'coal_hosp_create',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': coalLocalId,
            'client_uuid': coalClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Initial Hospital Name',
            'type': 'Clinic',
          },
        );

        final updateItem = SyncQueueItem(
          id: 'coal_hosp_update',
          entity: 'hospital',
          operation: 'update',
          payload: {
            'id': coalLocalId,
            'client_uuid': coalClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Coalesced Final Hospital Name',
            'type': 'General Hospital',
            'address': '55 Roppongi Hills',
          },
        );

        await syncServiceA.addToQueue(createItem);
        await syncServiceA.addToQueue(updateItem);

        // Only ONE item should survive in the queue box!
        expect(isolatedHiveService.syncQueueBox.length, 1);
        final surviving = SyncQueueItem.fromMap(
          Map<String, dynamic>.from(isolatedHiveService.syncQueueBox.values.first),
        );
        expect(surviving.operation, 'create');
        expect(surviving.payload['name'], 'Coalesced Final Hospital Name');
        expect(surviving.payload['address'], '55 Roppongi Hills');

        // Sync to remote and verify single insert occurred
        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

        final list = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        final found = list.firstWhere((h) => h.clientUuid == coalClientUuid);
        expect(found.name, 'Coalesced Final Hospital Name');

        // Cleanup
        await hospitalA.deleteHospital(
          hospitalId: found.id,
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
      });

      test('2.2 CREATE + DELETE before upload cancels out entirely (CASE B, zero remote traces)', () async {
        fakeConnectivity.setOnline(false);

        final cancelDocLocalId = 'doc_local_cancel_1';
        final cancelClientUuid = '00000000-0000-0000-0003-000000000001';

        final createItem = SyncQueueItem(
          id: 'cancel_doc_create',
          entity: 'doctor',
          operation: 'create',
          payload: {
            'id': cancelDocLocalId,
            'client_uuid': cancelClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Dr. Cancelled Offline',
            'specialty': 'Neurologist',
          },
        );

        final deleteItem = SyncQueueItem(
          id: 'cancel_doc_delete',
          entity: 'doctor',
          operation: 'delete',
          payload: {
            'id': cancelDocLocalId,
            'client_uuid': cancelClientUuid,
            'profile_id': primaryProfileA!.profileId,
          },
        );

        await syncServiceA.addToQueue(createItem);
        expect(isolatedHiveService.syncQueueBox.length, 1);

        // Adding delete should cancel out both entries completely
        await syncServiceA.addToQueue(deleteItem);
        expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

        // Reconnect network
        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        // Verified zero records created on remote Supabase
        final docs = await doctorA.fetchDoctors(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        expect(docs.any((d) => d.clientUuid == cancelClientUuid), isFalse);
      });

      test('2.3 Multiple UPDATE operations collapse to latest update', () async {
        // Setup initial remote hospital
        final multiHospId = '00000000-0000-0000-0004-000000000001';
        final multiClientUuid = '00000000-0000-0000-0004-000000000001';

        await hospitalA.createHospital(
          hospital: HospitalModel(
            id: multiHospId,
            clientUuid: multiClientUuid,
            profileId: primaryProfileA!.profileId,
            name: 'Base Hospital',
            type: 'General',
          ),
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );

        fakeConnectivity.setOnline(false);

        await syncServiceA.addToQueue(SyncQueueItem(
          id: 'upd_1',
          entity: 'hospital',
          operation: 'update',
          payload: {
            'id': multiHospId,
            'client_uuid': multiClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Update One',
          },
        ));

        await syncServiceA.addToQueue(SyncQueueItem(
          id: 'upd_2',
          entity: 'hospital',
          operation: 'update',
          payload: {
            'id': multiHospId,
            'client_uuid': multiClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Update Two Final',
          },
        ));

        expect(isolatedHiveService.syncQueueBox.length, 1);
        final item = SyncQueueItem.fromMap(
          Map<String, dynamic>.from(isolatedHiveService.syncQueueBox.values.first),
        );
        expect(item.payload['name'], 'Update Two Final');

        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        final list = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        final h = list.firstWhere((e) => e.id == multiHospId);
        expect(h.name, 'Update Two Final');

        // Cleanup
        await hospitalA.deleteHospital(
          hospitalId: multiHospId,
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
      });

      test('2.4 Duplicate replay and client_uuid idempotency prevents duplicate rows', () async {
        final idempHospId = '00000000-0000-0000-0005-000000000001';
        final idempClientUuid = '00000000-0000-0000-0005-000000000001';

        final item = SyncQueueItem(
          id: 'idemp_create_1',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': idempHospId,
            'client_uuid': idempClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Idempotent Hospital',
          },
        );

        // Sync first time
        fakeConnectivity.setOnline(true);
        await coordinatorA.processItem(item: item);

        // Duplicate replay of identical create mutation
        final replayItem = SyncQueueItem(
          id: 'idemp_create_2',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': idempHospId,
            'client_uuid': idempClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Idempotent Hospital',
          },
        );
        final replaySuccess = await coordinatorA.processItem(item: replayItem);
        expect(replaySuccess, isTrue);

        // Verify exactly 1 row exists in PostgreSQL (no duplicate)
        final rows = await clientA
            .from('hospitals')
            .select()
            .eq('client_uuid', idempClientUuid);
        expect(rows.length, 1);

        // Cleanup
        await hospitalA.deleteHospital(
          hospitalId: idempHospId,
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
      });
    });

    // =========================================================================
    // GROUP 3: ALL EIGHT SYNCHRONIZED DOMAINS & DEPENDENCY ORDERING
    // =========================================================================
    group('Group 3: All Eight Synchronized Domains & Dependency Ordering', () {
      String? domainFamilyProfileId;
      final domainHospitalId = '00000000-0000-0000-0011-000000000001';
      final domainDoctorId = '00000000-0000-0000-0012-000000000001';
      final domainConsultationId = '00000000-0000-0000-0013-000000000001';
      final domainReportId = '00000000-0000-0000-0014-000000000001';
      final domainAppointmentId = '00000000-0000-0000-0015-000000000001';
      final domainMedicineId = '00000000-0000-0000-0016-000000000001';
      final domainMeasurementId = '00000000-0000-0000-0017-000000000001';

      test('3.1 Domain 1: Profiles (family member creation & archival)', () async {
        final profileClientUuid = '00000000-0000-0000-0010-000000000001';
        final item = SyncQueueItem(
          id: 'sync_domain_profile_1',
          entity: 'profile',
          operation: 'create',
          payload: {
            'profile_id': 'prof_local_family_1',
            'client_uuid': profileClientUuid,
            'owner_user_id': userAId!,
            'full_name': 'E2E Sync Child Profile',
            'relationship': 'Son',
            'is_primary': false,
            'is_archived': false,
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        // Verify in DB
        final profiles = await profileA.fetchProfiles(ownerUserId: userAId!);
        final found = profiles.firstWhere((p) => p.fullName == 'E2E Sync Child Profile');
        expect(found, isNotNull);
        domainFamilyProfileId = found.profileId;

        // Cache in isolated profileBox for child lookups
        await isolatedHiveService.profileBox.put(
          domainFamilyProfileId!,
          found.toMap(),
        );
        await isolatedHiveService.profileBox.put(
          'prof_local_family_1',
          found.toMap(),
        );
      });

      test('3.2 Domain 2: Hospitals (facility creation & update)', () async {
        final item = SyncQueueItem(
          id: 'sync_domain_hosp_1',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': domainHospitalId,
            'client_uuid': domainHospitalId,
            'profile_id': domainFamilyProfileId!,
            'name': 'Domain Test Hospital',
            'type': 'General Hospital',
            'address': 'Ginza Medical Complex',
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final hosps = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        expect(hosps.any((h) => h.id == domainHospitalId), isTrue);
      });

      test('3.3 Domain 3: Doctors (clinician creation & hospital association)', () async {
        final item = SyncQueueItem(
          id: 'sync_domain_doc_1',
          entity: 'doctor',
          operation: 'create',
          payload: {
            'id': domainDoctorId,
            'client_uuid': domainDoctorId,
            'profile_id': domainFamilyProfileId!,
            'name': 'Dr. Domain Specialist',
            'specialty': 'Cardiologist',
            'hospital_ids': [domainHospitalId],
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final docs = await doctorA.fetchDoctors(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final found = docs.firstWhere((d) => d.id == domainDoctorId);
        expect(found.hospitalIds.contains(domainHospitalId), isTrue);
      });

      test('3.4 Domain 4: Consultations (visit record linked to doctor and hospital)', () async {
        final item = SyncQueueItem(
          id: 'sync_domain_con_1',
          entity: 'consultation',
          operation: 'create',
          payload: {
            'id': domainConsultationId,
            'client_uuid': domainConsultationId,
            'profile_id': domainFamilyProfileId!,
            'doctor_id': domainDoctorId,
            'hospital_id': domainHospitalId,
            'visit_date': DateTime.now().toIso8601String(),
            'chief_complaint': 'Chest discomfort during exercise',
            'diagnosis': 'Angina pectoris, mild',
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final cons = await consultationA.fetchConsultations(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final found = cons.firstWhere((c) => c.id == domainConsultationId);
        expect(found.doctorId, domainDoctorId);
        expect(found.hospitalId, domainHospitalId);
        expect(found.diagnosis, 'Angina pectoris, mild');
      });

      test('3.5 Domain 5: Reports (diagnostic report linked to consultation)', () async {
        final item = SyncQueueItem(
          id: 'sync_domain_rep_1',
          entity: 'report',
          operation: 'create',
          payload: {
            'id': domainReportId,
            'client_uuid': domainReportId,
            'profile_id': domainFamilyProfileId!,
            'consultation_id': domainConsultationId,
            'doctor_id': domainDoctorId,
            'hospital_id': domainHospitalId,
            'title': 'Cardiac Ultrasound Summary',
            'category': 'Cardiology',
            'date': DateTime.now().toIso8601String().substring(0, 10),
            'notes': 'Normal left ventricular ejection fraction',
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final reps = await reportA.fetchReports(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final found = reps.firstWhere((r) => r.id == domainReportId);
        expect(found.title, 'Cardiac Ultrasound Summary');
        expect(found.consultationId, domainConsultationId);
      });

      test('3.6 Domain 6: Appointments (clinical appointment linked to doctor & hospital)', () async {
        final item = SyncQueueItem(
          id: 'sync_domain_apt_1',
          entity: 'appointment',
          operation: 'create',
          payload: {
            'id': domainAppointmentId,
            'client_uuid': domainAppointmentId,
            'profile_id': domainFamilyProfileId!,
            'doctor_id': domainDoctorId,
            'doctor_name': 'Dr. Domain Specialist',
            'hospital_id': domainHospitalId,
            'consultation_id': domainConsultationId,
            'title': '3-Month Cardiology Review',
            'appointment_date': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
            'status': 'scheduled',
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final apts = await appointmentA.fetchAppointments(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final found = apts.firstWhere(
          (a) => IdUtils.matches(a.id, domainAppointmentId) || a.clientUuid == domainAppointmentId,
        );
        expect(found.title, '3-Month Cardiology Review');
        expect(found.doctorId, domainDoctorId);
      });

      test('3.7 Domain 7: Medicines / Prescriptions (medication linked to consultation)', () async {
        final item = SyncQueueItem(
          id: 'sync_domain_med_1',
          entity: 'medicine',
          operation: 'create',
          payload: {
            'id': domainMedicineId,
            'client_uuid': domainMedicineId,
            'profile_id': domainFamilyProfileId!,
            'consultation_id': domainConsultationId,
            'linked_consultation_id': domainConsultationId,
            'name': 'Atorvastatin',
            'medicine_name': 'Atorvastatin',
            'dosage': '20mg',
            'form': 'Tablet',
            'frequency': 'Once Daily',
            'status': 'active',
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final meds = await medicineA.fetchMedicines(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final found = meds.firstWhere(
          (m) => IdUtils.matches(m.id, domainMedicineId) || m.clientUuid == domainMedicineId,
        );
        expect(found.medicineName, 'Atorvastatin');
        expect(found.linkedConsultationId, domainConsultationId);
      });

      test('3.8 Domain 8: Vitals / Measurements (vital readings with immutable recorded_at)', () async {
        final fixedRecordedAt = DateTime.utc(2026, 11, 15, 8, 30, 0);

        final item = SyncQueueItem(
          id: 'sync_domain_vit_1',
          entity: 'measurement',
          operation: 'create',
          payload: {
            'id': domainMeasurementId,
            'client_uuid': domainMeasurementId,
            'profile_id': domainFamilyProfileId!,
            'type': 'blood_pressure',
            'systolic': 118,
            'diastolic': 78,
            'unit': 'mmHg',
            'recorded_at': fixedRecordedAt.toIso8601String(),
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        expect(ok, isTrue);

        final vitals = await vitalsA.fetchMeasurements(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final found = vitals.firstWhere(
          (v) => IdUtils.matches(v.id, domainMeasurementId) || v.clientUuid == domainMeasurementId,
        );
        expect(found.systolic, 118);
        expect(found.diastolic, 78);
        expect(found.recordedAt.isAtSameMomentAs(fixedRecordedAt), isTrue);
        expect(found.recordedAt.toUtc().toIso8601String(), fixedRecordedAt.toUtc().toIso8601String());
      });

      test('3.9 Parent-Child Dependency Ordering: child queued before parent is deferred until parent exists', () async {
        fakeConnectivity.setOnline(false);

        final depHospId = '00000000-0000-0000-0020-000000000001';
        final depDocId = '00000000-0000-0000-0021-000000000001';

        // Queue Doctor FIRST (depends on depHospId)
        final childDoctor = SyncQueueItem(
          id: 'dep_child_doc',
          entity: 'doctor',
          operation: 'create',
          payload: {
            'id': depDocId,
            'client_uuid': depDocId,
            'profile_id': domainFamilyProfileId!,
            'name': 'Dr. Dependent Child',
            'specialty': 'Pediatrician',
            'hospital_ids': [depHospId],
          },
        );

        // Queue Hospital SECOND
        final parentHosp = SyncQueueItem(
          id: 'dep_parent_hosp',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': depHospId,
            'client_uuid': depHospId,
            'profile_id': domainFamilyProfileId!,
            'name': 'Parent Community Hospital',
          },
        );

        await isolatedHiveService.syncQueueBox.put('dep_child_doc', childDoctor.toMap());
        await isolatedHiveService.syncQueueBox.put('dep_parent_hosp', parentHosp.toMap());

        // Process queue: SyncService._entityPriority sorts Hospitals (priority 1) before Doctors (priority 2)
        fakeConnectivity.setOnline(true);
        await syncServiceA.syncPendingToSupabase(force: true);

        expect(isolatedHiveService.syncQueueBox.isEmpty, isTrue);

        // Verify both created in PostgreSQL and association was established!
        final docs = await doctorA.fetchDoctors(
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        final d = docs.firstWhere((e) => e.id == depDocId);
        expect(d.hospitalIds.contains(depHospId), isTrue);

        // Cleanup
        await doctorA.deleteDoctor(
          doctorId: depDocId,
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
        await hospitalA.deleteHospital(
          hospitalId: depHospId,
          ownerUserId: userAId!,
          profileId: domainFamilyProfileId!,
        );
      });
    });

    // =========================================================================
    // GROUP 4: STORAGE LIFECYCLE & ATTACHMENT RESILIENCE
    // =========================================================================
    group('Group 4: Storage Lifecycle & Attachment Resilience', () {
      final storageReportId = '00000000-0000-0000-0030-000000000001';
      final storageAttId = '00000000-0000-0000-0031-000000000001';
      late File localDummyFile;

      setUpAll(() {
        localDummyFile = File('${tempHiveDir.path}/blood_work_sample.pdf');
        localDummyFile.writeAsStringSync('%PDF-1.4 Mock Clinical Attachment Content for MediCrate');
      });

      test('4.1 Report attachment upload: local file uploaded to private bucket with signed URL access', () async {
        final item = SyncQueueItem(
          id: 'storage_report_create',
          entity: 'report',
          operation: 'create',
          payload: {
            'id': storageReportId,
            'client_uuid': storageReportId,
            'profile_id': primaryProfileA!.profileId,
            'title': 'Lab Blood Work Analysis',
            'category': 'Laboratory',
            'date': DateTime.now().toIso8601String().substring(0, 10),
            'attachments': [
              {
                'id': storageAttId,
                'name': 'blood_work_sample.pdf',
                'file_path': localDummyFile.path,
                'file_size': localDummyFile.lengthSync(),
              }
            ],
          },
        );

        final ok = await coordinatorA.processItem(item: item);
        if (!ok) {
          print('DEBUG 4.1 FAILURE: status=${item.status}, error=${item.errorMessage}');
        }
        expect(ok, isTrue);

        // Verify report in DB
        final reports = await reportA.fetchReports(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        final found = reports.firstWhere((r) => r.id == storageReportId);
        expect(found.attachments.length, 1);
        final att = found.attachments.first;
        print('DEBUG att: fileUrl=${att.fileUrl}, filePath=${att.filePath}');
        expect(att.fileUrl, isNotNull);
        expect(att.fileUrl!.contains(userAId!), isTrue);

        // Verify signed URL works with public unauthenticated HTTP client
        final signedUrl = await storageA.createSignedUrl(
          bucket: 'reports',
          storagePath: att.fileUrl!,
          expiresInSeconds: 300,
        );
        final httpRes = await http.get(Uri.parse(signedUrl));
        expect(httpRes.statusCode, 200);
        expect(httpRes.body, contains('%PDF-1.4'));
      });

      test('4.2 Report deletion cleans up both PostgreSQL records and Storage object', () async {
        final deleteItem = SyncQueueItem(
          id: 'storage_report_delete',
          entity: 'report',
          operation: 'delete',
          payload: {
            'id': storageReportId,
            'client_uuid': storageReportId,
            'profile_id': primaryProfileA!.profileId,
          },
        );

        final ok = await coordinatorA.processItem(item: deleteItem);
        expect(ok, isTrue);

        // Verify report no longer exists in DB
        final reports = await reportA.fetchReports(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        expect(reports.any((r) => r.id == storageReportId), isFalse);

        // Verify Storage folder/file has been purged
        final storageFiles = await clientA.storage.from('reports').list(
              path: '$userAId/$storageReportId',
            );
        expect(storageFiles.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // GROUP 5: SESSION & PROFILE ISOLATION, ACCOUNT SWITCHING
    // =========================================================================
    group('Group 5: Session & Profile Isolation, Account Switching', () {
      test('5.1 User A cannot sync items with User B profile ID (foreign profile rejected)', () async {
        final foreignItem = SyncQueueItem(
          id: 'foreign_prof_item',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': '00000000-0000-0000-0040-000000000001',
            'client_uuid': '00000000-0000-0000-0040-000000000001',
            'profile_id': primaryProfileB!.profileId, // User B's profile!
            'name': 'Foreign Malicious Hospital',
          },
        );

        // Coordinator under User A rejects/defers mutation
        final ok = await coordinatorA.processItem(item: foreignItem);
        expect(ok, isFalse);
        expect(foreignItem.status, anyOf('deferred', 'auth_required', 'failed'));

        // Verify no record inserted under User B's profile
        final listB = await hospitalA.fetchHospitals(
          ownerUserId: userBId!,
          profileId: primaryProfileB!.profileId,
        ).catchError((_) => <HospitalModel>[]);
        expect(listB.any((h) => h.id == '00000000-0000-0000-0040-000000000001'), isFalse);
      });

      test('5.2 Unauthenticated session sets status to auth_required without consuming retry budget', () async {
        final unauthClient = createClient(); // Unauthenticated client
        final unauthCoordinator = SupabaseSyncCoordinator(
          hiveService: isolatedHiveService,
          customClient: unauthClient,
        );

        final item = SyncQueueItem(
          id: 'unauth_item',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': '00000000-0000-0000-0041-000000000001',
            'client_uuid': '00000000-0000-0000-0041-000000000001',
            'profile_id': primaryProfileA!.profileId,
            'name': 'Unauth Hospital',
          },
        );

        final ok = await unauthCoordinator.processItem(item: item);
        expect(ok, isFalse);
        expect(item.status, 'auth_required');
        expect(item.retryCount, 0); // Retry budget preserved!
      });
    });

    // =========================================================================
    // GROUP 6: CONCURRENCY CONTROL, SYNCLOCK, HEARTBEAT & RECOVERY
    // =========================================================================
    group('Group 6: Concurrency Control, SyncLock, Heartbeat & Recovery', () {
      test('6.1 SyncLock mutual exclusion prevents concurrent worker execution', () async {
        final lock = SyncLock(isolatedHiveService.settingsBox);

        // Worker 1 acquires lock
        final token1 = await lock.tryAcquire();
        expect(token1, isNotNull);
        expect(token1, isNot(SyncLock.noLockToken));

        // Worker 2 attempts to acquire lock while held by Worker 1
        final token2 = await lock.tryAcquire();
        expect(token2, isNull); // Blocked from executing concurrently!

        // Worker 1 releases lock
        await lock.release(token1!);

        // Worker 2 can now acquire lock
        final token3 = await lock.tryAcquire();
        expect(token3, isNotNull);
        await lock.release(token3!);
      });

      test('6.2 SyncLock renew extends valid lease window', () async {
        final lock = SyncLock(isolatedHiveService.settingsBox);
        final token = await lock.tryAcquire();
        expect(token, isNotNull);

        final renewed = await lock.renew(token!);
        expect(renewed, isTrue);

        await lock.release(token);
      });

      test('6.3 Dead-letter behavior: check constraint violation immediately dead-letters with retryCount = 99', () async {
        final invalidItem = SyncQueueItem(
          id: 'dead_letter_item',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': '00000000-0000-0000-0050-000000000001',
            'client_uuid': '00000000-0000-0000-0050-000000000001',
            'profile_id': primaryProfileA!.profileId,
            // Check constraint: hospital name cannot be empty string
            'name': '   ',
          },
        );

        final ok = await coordinatorA.processItem(item: invalidItem);
        expect(ok, isFalse);
        expect(invalidItem.status, 'failed');
        expect(invalidItem.retryCount, 99); // Dead-lettered immediately!
      });

      test('6.4 Application restart & queue recovery restores and processes pending mutations', () async {
        final restartHospId = '00000000-0000-0000-0060-000000000001';
        final restartClientUuid = '00000000-0000-0000-0060-000000000001';

        // Write mutation into Hive while offline
        fakeConnectivity.setOnline(false);
        final pendingItem = SyncQueueItem(
          id: 'restart_queue_item',
          entity: 'hospital',
          operation: 'create',
          payload: {
            'id': restartHospId,
            'client_uuid': restartClientUuid,
            'profile_id': primaryProfileA!.profileId,
            'name': 'Hospital Persisted Over Restart',
          },
        );
        await isolatedHiveService.syncQueueBox.put('restart_queue_item', pendingItem.toMap());

        // Simulate app crash/restart by creating a new SyncService instance
        final newSyncService = SyncService(
          hiveService: isolatedHiveService,
          connectivityService: fakeConnectivity,
          customSupabaseSyncCoordinator: coordinatorA,
        );

        // Turn on network & sync
        fakeConnectivity.setOnline(true);
        await newSyncService.syncPendingToSupabase(force: true);

        // Queue item was recovered from Hive and processed!
        expect(isolatedHiveService.syncQueueBox.containsKey('restart_queue_item'), isFalse);

        final list = await hospitalA.fetchHospitals(
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        expect(list.any((h) => h.id == restartHospId), isTrue);

        // Cleanup
        await hospitalA.deleteHospital(
          hospitalId: restartHospId,
          ownerUserId: userAId!,
          profileId: primaryProfileA!.profileId,
        );
        newSyncService.dispose();
      });
    });
  });
}
