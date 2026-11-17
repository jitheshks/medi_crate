import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import 'package:medi_crate/features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import 'package:medi_crate/features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AlwaysOnlineConnectivityService extends Fake implements ConnectivityService {
  @override
  Future<bool> checkConnectivity() async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}

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
  int deletedObjectsCount = 0;

  _StagedFailingStorageService({required this.liveClient})
      : super(customClient: liveClient);

  @override
  Future<void> deleteParentFolder({
    required String bucket,
    required String parentId,
    required String userId,
  }) async {
    validateBucket(bucket);
    final folderPath = '$userId/$parentId';
    try {
      final list = await liveClient.storage.from(bucket).list(path: folderPath);
      if (list.isNotEmpty) {
        final sortedItems = list.toList()..sort((a, b) => a.name.compareTo(b.name));
        for (final item in sortedItems) {
          if (injectFailure && deletedObjectsCount == 1) {
            throw const StorageOperationException(
              'Injected storage failure after partial object deletion',
            );
          }
          await liveClient.storage.from(bucket).remove(['$folderPath/${item.name}']);
          deletedObjectsCount++;
        }
      }
    } catch (e) {
      if (e is StorageOperationException) rethrow;
      throw StorageOperationException(
        'Failed to clean up storage folder $folderPath: $e',
        e,
      );
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
  late SupabaseClient clientA;
  late SupabaseClient clientB;

  late String userAId;
  late String userBId;
  late String emailA;
  late String emailB;
  const password = 'TestPassword123!';

  late Directory tempDir;
  late HiveService hiveService;
  late _AlwaysOnlineConnectivityService connectivityService;

  // Track created entities for cross-scenario integration
  String? profileAId;
  String? familyProfileAId;
  String? hospitalAId;
  String? doctorAId;
  String? consultationAId;
  String? appointmentAId;
  String? prescriptionAId;
  String? measurementAId;
  String? reportAId;

  setUpAll(() async {
    adminClient = SupabaseClient(supabaseUrl, serviceRoleKey);

    final ts = DateTime.now().millisecondsSinceEpoch;
    emailA = 'user_a_$ts@medicrate.test';
    emailB = 'user_b_$ts@medicrate.test';

    // 1. Create two test accounts in GoTrue using admin API
    final resA = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: emailA,
        password: password,
        emailConfirm: true,
      ),
    );
    userAId = resA.user!.id;

    final resB = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: emailB,
        password: password,
        emailConfirm: true,
      ),
    );
    userBId = resB.user!.id;

    // 2. Sign in as User A and User B on separate SupabaseClient instances
    clientA = SupabaseClient(supabaseUrl, anonKey);
    await clientA.auth.signInWithPassword(email: emailA, password: password);

    clientB = SupabaseClient(supabaseUrl, anonKey);
    await clientB.auth.signInWithPassword(email: emailB, password: password);

    // 3. Initialize local Hive for coordinator/sync service testing
    tempDir = await Directory.systemTemp.createTemp('supabase_integration_test_');
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
    connectivityService = _AlwaysOnlineConnectivityService();

    // Seed local authBox with User A
    await hiveService.authBox.put('current_user', {
      'id': userAId,
      'user_id': userAId,
    });
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}

    // Clean up test users and cascade clinical records via Supabase Auth Admin
    try {
      await adminClient.auth.admin.deleteUser(userAId);
    } catch (_) {}
    try {
      await adminClient.auth.admin.deleteUser(userBId);
    } catch (_) {}
  });

  group('MediCrate — Implementation 5.4: Isolated Supabase Integration Tests', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Two-user authentication and profile isolation
    // -------------------------------------------------------------------------
    test('1. Two-user authentication and profile isolation', () async {
      expect(clientA.auth.currentUser?.id, equals(userAId));
      expect(clientB.auth.currentUser?.id, equals(userBId));

      // User A's primary profile is automatically created upon signup by on_auth_user_created trigger
      final profilesRes = await clientA
          .from('profiles')
          .select()
          .eq('user_id', userAId)
          .eq('is_primary', true);
      expect(profilesRes, isNotEmpty);
      profileAId = profilesRes.first['id'] as String;
      expect(profileAId, isNotNull);

      // User A updates primary profile
      final updateRes = await clientA
          .from('profiles')
          .update({'full_name': 'Alice User A'})
          .eq('id', profileAId!)
          .select()
          .single();
      expect(updateRes['full_name'], equals('Alice User A'));

      // User A can read its own profile
      final readA = await clientA
          .from('profiles')
          .select()
          .eq('id', profileAId!);
      expect(readA.length, equals(1));

      // Verify unique constraint: inserting a second primary profile for User A is rejected
      expect(
        () async => await clientA.from('profiles').insert({
          'user_id': userAId,
          'full_name': 'Alice Duplicate Primary',
          'relationship': 'Self',
          'is_primary': true,
        }),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', equals('23505'))),
        reason: 'idx_profiles_user_primary must reject multiple primary profiles per user',
      );

      // User B attempts to read User A's profile via PostgREST Data API
      final readB = await clientB
          .from('profiles')
          .select()
          .eq('id', profileAId!);
      expect(readB, isEmpty,
          reason: 'RLS must reject cross-user profile reading by returning empty list');

      // User B attempts to update User A's profile
      final updateB = await clientB
          .from('profiles')
          .update({'full_name': 'Attacker Overwrite'})
          .eq('id', profileAId!)
          .select();
      expect(updateB, isEmpty,
          reason: 'RLS must reject cross-user profile update by updating 0 rows');
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Profile creation, secondary-profile archival and primary-profile protection
    // -------------------------------------------------------------------------
    test('2. Profile creation, secondary-profile archival and primary-profile protection', () async {
      // User A creates a secondary family profile
      final secRes = await clientA
          .from('profiles')
          .insert({
            'user_id': userAId,
            'full_name': 'Bob Brother A',
            'relationship': 'Brother',
            'is_primary': false,
          })
          .select()
          .single();

      familyProfileAId = secRes['id'] as String;
      expect(secRes['is_archived'], isFalse);

      // User A archives the secondary family profile
      final profileRemoteDS = SupabaseProfileRemoteDataSource(customClient: clientA);
      final archived = await profileRemoteDS.archiveProfile(
        profileId: familyProfileAId!,
        ownerUserId: userAId,
      );
      expect(archived.isArchived, isTrue);

      final dbCheck = await clientA
          .from('profiles')
          .select('is_archived, archived_at')
          .eq('id', familyProfileAId!)
          .single();
      expect(dbCheck['is_archived'], isTrue);
      expect(dbCheck['archived_at'], isNotNull);

      // Attempting to delete primary profile via PostgREST:
      // Must be rejected by database triggers / RLS
      expect(
        () async => await clientA
            .from('profiles')
            .delete()
            .eq('id', profileAId!),
        throwsA(isA<PostgrestException>()),
        reason: 'Primary profile deletion must be rejected at database boundary',
      );

      // Attempting to direct hard-delete secondary profile:
      // Authenticated users have no DELETE privilege on profiles
      expect(
        () async => await clientA
            .from('profiles')
            .delete()
            .eq('id', familyProfileAId!),
        throwsA(isA<PostgrestException>()),
        reason: 'Hard deletion on profiles must be rejected (DELETE revoked)',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Doctor/hospital creation and affiliations (RPC & RLS)
    // -------------------------------------------------------------------------
    test('3. Doctor/hospital creation and affiliations (RPC & RLS)', () async {
      // User A creates hospital
      final hospRes = await clientA
          .from('hospitals')
          .insert({
            'user_id': userAId,
            'profile_id': profileAId!,
            'name': 'St. Jude General Hospital',
            'type': 'Hospital',
          })
          .select()
          .single();

      hospitalAId = hospRes['id'] as String;
      expect(hospitalAId, isNotNull);

      // User A creates doctor with affiliation via save_doctor_with_affiliations RPC (via createDoctor)
      final docRemoteDS = SupabaseDoctorRemoteDataSource(customClient: clientA);
      final doctor = await docRemoteDS.createDoctor(
        doctor: DoctorModel(
          id: UuidUtils.generateV4(),
          profileId: profileAId!,
          name: 'Dr. Gregory House',
          specialty: 'Diagnostic Medicine',
          hospitalIds: [hospitalAId!],
        ),
        ownerUserId: userAId,
        profileId: profileAId!,
      );

      doctorAId = doctor.id;
      expect(doctorAId, isNotNull);
      expect(doctor.name, equals('Dr. Gregory House'));

      // Verify doctor_hospitals affiliation row in DB
      final affils = await clientA
          .from('doctor_hospitals')
          .select()
          .eq('doctor_id', doctorAId!)
          .eq('hospital_id', hospitalAId!);
      expect(affils.length, equals(1));

      // User B cannot view User A's hospital or doctor
      final readHospB = await clientB
          .from('hospitals')
          .select()
          .eq('id', hospitalAId!);
      expect(readHospB, isEmpty);

      final readDocB = await clientB
          .from('doctors')
          .select()
          .eq('id', doctorAId!);
      expect(readDocB, isEmpty);

      // User B attempts to hijack User A's doctor via RPC -> rejected with CROSS_USER / ownership error
      expect(
        () async => await clientB.rpc(
          'save_doctor_with_affiliations',
          params: {
            'p_profile_id': profileAId,
            'p_name': 'Attacker Doctor',
            'p_specialty': 'General',
            'p_doctor_id': doctorAId,
          },
        ),
        throwsA(isA<PostgrestException>()),
        reason: 'Cross-user doctor modification via RPC must be strictly rejected',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Consultation and appointment dependencies & RLS
    // -------------------------------------------------------------------------
    test('4. Consultation and appointment dependencies & RLS', () async {
      // User A creates consultation referencing doctor and hospital
      final consultRes = await clientA
          .from('consultations')
          .insert({
            'user_id': userAId,
            'profile_id': profileAId!,
            'doctor_id': doctorAId,
            'doctor_name': 'Dr. Gregory House',
            'hospital_id': hospitalAId,
            'hospital_name': 'St. Jude General Hospital',
            'chief_complaint': 'Cardiology Follow-up',
            'diagnosis': 'Angina pectoris',
            'visit_date': '2026-11-14',
          })
          .select()
          .single();

      consultationAId = consultRes['id'] as String;
      expect(consultationAId, isNotNull);

      // User A creates appointment referencing doctor, and hospital
      final apptRes = await clientA
          .from('appointments')
          .insert({
            'user_id': userAId,
            'profile_id': profileAId!,
            'doctor_id': doctorAId,
            'doctor_name': 'Dr. Gregory House',
            'hospital_id': hospitalAId,
            'hospital_name': 'St. Jude General Hospital',
            'title': 'Annual Cardiac Check',
            'appointment_date': '2026-11-20T10:00:00Z',
            'status': 'confirmed',
          })
          .select()
          .single();

      appointmentAId = apptRes['id'] as String;
      expect(appointmentAId, isNotNull);

      // User B queries consultations and appointments -> returns 0 rows
      final bConsults = await clientB
          .from('consultations')
          .select()
          .eq('id', consultationAId!);
      expect(bConsults, isEmpty);

      final bAppts = await clientB
          .from('appointments')
          .select()
          .eq('id', appointmentAId!);
      expect(bAppts, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Medicine and vital record synchronization & RLS
    // -------------------------------------------------------------------------
    test('5. Medicine and vital record synchronization & RLS', () async {
      // User A creates prescription/medicine
      final rxRes = await clientA
          .from('prescriptions')
          .insert({
            'user_id': userAId,
            'profile_id': profileAId!,
            'consultation_id': consultationAId,
            'medicine_name': 'Atorvastatin',
            'dosage': '20mg',
            'form': 'Tablet',
            'frequency': 'Once daily at bedtime',
            'start_date': '2026-11-14',
            'is_active': true,
          })
          .select()
          .single();

      prescriptionAId = rxRes['id'] as String;
      expect(prescriptionAId, isNotNull);

      // User A creates measurement/vital (Blood Pressure)
      final vitalRes = await clientA
          .from('measurements')
          .insert({
            'user_id': userAId,
            'profile_id': profileAId!,
            'type': 'blood_pressure',
            'primary_value': 120.0,
            'secondary_value': 80.0,
            'unit': 'mmHg',
            'status': 'normal',
            'source': 'Manual',
            'recorded_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      measurementAId = vitalRes['id'] as String;
      expect(measurementAId, isNotNull);

      // User B cannot access User A's medicines or vitals
      final bRx = await clientB
          .from('prescriptions')
          .select()
          .eq('id', prescriptionAId!);
      expect(bRx, isEmpty);

      final bVitals = await clientB
          .from('measurements')
          .select()
          .eq('id', measurementAId!);
      expect(bVitals, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Report creation, expenses constraint, and attachment uploads
    // -------------------------------------------------------------------------
    test('6. Report creation, expenses constraint, and attachment uploads', () async {
      // 1. Create report row in public.reports
      final repRes = await clientA
          .from('reports')
          .insert({
            'user_id': userAId,
            'profile_id': profileAId!,
            'consultation_id': consultationAId,
            'doctor_id': doctorAId,
            'hospital_id': hospitalAId,
            'title': 'Lipid Panel Report',
            'category': 'LAB TEST',
            'report_date': '2026-11-14',
          })
          .select()
          .single();

      reportAId = repRes['id'] as String;
      expect(reportAId, isNotNull);

      // 2. Insert expense into public.report_expenses
      final expRes = await clientA
          .from('report_expenses')
          .insert({
            'report_id': reportAId,
            'user_id': userAId,
            'amount': 45.0,
            'currency': 'USD',
            'status': 'PAID',
          })
          .select()
          .single();
      expect(expRes['amount'], equals(45.0));

      // 3. Verify unique constraint: secondary insert with same report_id throws 23505
      expect(
        () async => await clientA.from('report_expenses').insert({
          'report_id': reportAId,
          'user_id': userAId,
          'amount': 60.0,
          'currency': 'USD',
          'status': 'PAID',
        }),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', equals('23505')),
        ),
        reason: 'uq_report_expenses_report_id must reject duplicate expense insertion',
      );

      // 4. Verify upsert semantics: .upsert on conflict 'report_id' succeeds idempotently
      final upsertRes = await clientA
          .from('report_expenses')
          .upsert({
            'report_id': reportAId,
            'user_id': userAId,
            'amount': 55.0,
            'currency': 'USD',
            'status': 'PAID',
          }, onConflict: 'report_id')
          .select()
          .single();
      expect(upsertRes['amount'], equals(55.0));

      // 5. Upload real file bytes to Supabase Storage reports bucket
      final testPdfBytes = Uint8List.fromList(
        List<int>.generate(256, (i) => i % 256),
      );
      final storagePath = '$userAId/$reportAId/lab_result.pdf';

      await clientA.storage.from('reports').uploadBinary(
            storagePath,
            testPdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      // Verify file download succeeds and bytes match
      final downloaded = await clientA.storage.from('reports').download(storagePath);
      expect(downloaded.length, equals(testPdfBytes.length));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Consultation attachment uploads and Storage RLS
    // -------------------------------------------------------------------------
    test('7. Consultation attachment uploads and Storage RLS', () async {
      final consultJpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final storagePath = '$userAId/$consultationAId/doctor_notes.jpg';

      await clientA.storage.from('consultations').uploadBinary(
            storagePath,
            consultJpgBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final downloaded =
          await clientA.storage.from('consultations').download(storagePath);
      expect(downloaded.length, equals(consultJpgBytes.length));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Attachment deletion, partial Storage failure and retry
    // -------------------------------------------------------------------------
    test('8. Attachment deletion, partial Storage failure and retry', () async {
      final storagePath = '$userAId/$reportAId/lab_result.pdf';

      // 1. Storage deletion while parent report exists succeeds
      final removeRes =
          await clientA.storage.from('reports').remove([storagePath]);
      expect(removeRes, isNotEmpty);

      // Verify file is gone from storage
      final listAfter = await clientA.storage
          .from('reports')
          .list(path: '$userAId/$reportAId');
      expect(listAfter.where((item) => item.name == 'lab_result.pdf'), isEmpty);

      // 2. Storage RLS precondition check:
      // Try to delete a path referencing a NON-EXISTENT report ID
      const fakeReportId = '00000000-0000-0000-0000-999999999999';
      final ghostPath = '$userAId/$fakeReportId/ghost.pdf';
      final ghostDeleteRes =
          await clientA.storage.from('reports').remove([ghostPath]);
      // Storage RLS rejects deletion for nonexistent parent rows: returns empty deleted list
      expect(ghostDeleteRes, isEmpty,
          reason: 'Storage RLS must reject deleting objects whose parent DB row does not exist');
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Offline mutation replay, idempotency and UUID reconciliation
    // -------------------------------------------------------------------------
    test('9. Offline mutation replay, idempotency and UUID reconciliation', () async {
      final storageService = SupabaseStorageService(customClient: clientA);
      final profileDS = SupabaseProfileRemoteDataSource(customClient: clientA);
      final hospDS = SupabaseHospitalRemoteDataSource(customClient: clientA);
      final docDS = SupabaseDoctorRemoteDataSource(customClient: clientA);
      final consultDS =
          SupabaseConsultationRemoteDataSource(client: clientA, customStorageService: storageService);
      final apptDS = SupabaseAppointmentRemoteDataSource(client: clientA);
      final medDS = SupabaseMedicineRemoteDataSource(client: clientA);
      final vitalsDS = SupabaseVitalsRemoteDataSource(client: clientA);
      final reportDS =
          SupabaseReportRemoteDataSource(client: clientA, storageService: storageService);

      final coordinator = SupabaseSyncCoordinator(
        hiveService: hiveService,
        customClient: clientA,
        customStorageService: storageService,
        customProfileRemoteDataSource: profileDS,
        customHospitalRemoteDataSource: hospDS,
        customDoctorRemoteDataSource: docDS,
        customConsultationRemoteDataSource: consultDS,
        customAppointmentRemoteDataSource: apptDS,
        customMedicineRemoteDataSource: medDS,
        customVitalsRemoteDataSource: vitalsDS,
        customReportRemoteDataSource: reportDS,
      );

      final clientUuid = UuidUtils.generateV4();
      const localHospId = 'hosp_local_offline_101';

      // 1. Seed userBox with local record
      await hiveService.userBox.put('hospital_$localHospId', {
        'id': localHospId,
        'client_uuid': clientUuid,
        'profile_id': profileAId,
        'name': 'Mayo Clinic Satellite',
        'type': 'Clinic',
      });

      // 2. Queue mutation
      final item = SyncQueueItem(
        id: 'q_hosp_replay_test',
        entity: 'hospital',
        operation: 'create',
        status: 'pending',
        payload: {
          'id': localHospId,
          'client_uuid': clientUuid,
          'profile_id': profileAId,
          'name': 'Mayo Clinic Satellite',
          'type': 'Clinic',
        },
      );

      // Process through real coordinator to Supabase
      final success1 = await coordinator.processItem(
        item: item,
        explicitOwnerUserId: userAId,
      );
      expect(success1, isTrue);

      // Verify server record created
      final serverRecords = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', clientUuid);
      expect(serverRecords.length, equals(1));
      final serverHospId = serverRecords.first['id'] as String;

      // Verify Hive userBox reconciled with server UUID
      final reconciled = hiveService.userBox.get('hospital_$serverHospId');
      expect(reconciled, isNotNull);
      expect(reconciled!['name'], equals('Mayo Clinic Satellite'));

      // 3. Replay same mutation again: Idempotency converts to update, NO duplicate created!
      final success2 = await coordinator.processItem(
        item: item,
        explicitOwnerUserId: userAId,
      );
      expect(success2, isTrue);

      final serverRecordsAfter = await clientA
          .from('hospitals')
          .select()
          .eq('client_uuid', clientUuid);
      expect(serverRecordsAfter.length, equals(1),
          reason: 'Replaying create mutation must not produce duplicate records');
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Application restart with pending mutations
    // -------------------------------------------------------------------------
    test('10. Application restart with pending mutations', () async {
      final clientUuid = UuidUtils.generateV4();
      const localVitalId = 'vital_restart_test_202';

      // 1. Place a pending mutation in Hive syncQueueBox
      final item = SyncQueueItem(
        id: 'q_restart_pending',
        entity: 'measurement',
        operation: 'create',
        status: 'pending',
        payload: {
          'id': localVitalId,
          'client_uuid': clientUuid,
          'profile_id': profileAId!,
          'type': 'heart_rate',
          'primary_value': 72.0,
          'unit': 'bpm',
          'status': 'normal',
          'source': 'Manual',
          'recorded_at': DateTime.now().toIso8601String(),
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      // 2. Simulate application restart: instantiate fresh SyncCoordinator & SyncService
      final storageService = SupabaseStorageService(customClient: clientA);
      final freshCoordinator = SupabaseSyncCoordinator(
        hiveService: hiveService,
        customClient: clientA,
        customStorageService: storageService,
        customProfileRemoteDataSource: SupabaseProfileRemoteDataSource(customClient: clientA),
        customHospitalRemoteDataSource: SupabaseHospitalRemoteDataSource(customClient: clientA),
        customDoctorRemoteDataSource: SupabaseDoctorRemoteDataSource(customClient: clientA),
        customConsultationRemoteDataSource:
            SupabaseConsultationRemoteDataSource(client: clientA, customStorageService: storageService),
        customAppointmentRemoteDataSource: SupabaseAppointmentRemoteDataSource(client: clientA),
        customMedicineRemoteDataSource: SupabaseMedicineRemoteDataSource(client: clientA),
        customVitalsRemoteDataSource: SupabaseVitalsRemoteDataSource(client: clientA),
        customReportRemoteDataSource:
            SupabaseReportRemoteDataSource(client: clientA, storageService: storageService),
      );

      final freshSyncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: freshCoordinator,
      );

      // Run syncPendingToSupabase with force=true for test execution
      await freshSyncService.syncPendingToSupabase(
        force: true,
        explicitOwnerUserId: userAId,
      );

      // Verify item processed and cleared from queue
      expect(hiveService.syncQueueBox.containsKey('q_restart_pending'), isFalse,
          reason: 'Post-restart synchronization must successfully process pending mutations');

      // Verify measurement created on Supabase
      final vitalsRes = await clientA
          .from('measurements')
          .select()
          .eq('client_uuid', clientUuid);
      expect(vitalsRes.length, equals(1));
      expect(vitalsRes.first['type'], equals('heart_rate'));

      freshSyncService.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Authentication expiration and account switching
    // -------------------------------------------------------------------------
    test('11. Authentication expiration and account switching', () async {
      // 1. When session is unauthenticated, processItem defers with status = 'auth_required'
      final unauthClient = SupabaseClient(supabaseUrl, anonKey);
      final unauthCoordinator = SupabaseSyncCoordinator(
        hiveService: hiveService,
        customClient: unauthClient,
        customStorageService: SupabaseStorageService(customClient: unauthClient),
      );

      final item = SyncQueueItem(
        id: 'q_auth_test',
        entity: 'profile',
        operation: 'create',
        status: 'pending',
        payload: {
          'id': 'prof_unauth_test',
          'full_name': 'Ghost User',
          'relationship': 'Sister',
          'is_primary': false,
        },
      );

      final successUnauth = await unauthCoordinator.processItem(
        item: item,
        explicitOwnerUserId: null,
      );
      expect(successUnauth, isFalse);
      expect(item.status, equals('auth_required'),
          reason: 'Missing session must transition to auth_required without consuming retry budget');

      // 2. Account switching: User B cannot process User A-owned mutation
      final userBCoordinator = SupabaseSyncCoordinator(
        hiveService: hiveService,
        customClient: clientB,
        customStorageService: SupabaseStorageService(customClient: clientB),
        customHospitalRemoteDataSource: SupabaseHospitalRemoteDataSource(customClient: clientB),
      );

      final itemOwnedByA = SyncQueueItem(
        id: 'q_user_a_mutation',
        entity: 'hospital',
        operation: 'create',
        status: 'pending',
        payload: {
          'id': 'hosp_owned_by_a',
          'client_uuid': UuidUtils.generateV4(),
          'profile_id': profileAId, // belongs to User A
          'name': 'Cross User Hospital',
        },
      );

      // User B attempts to process item referencing User A's profile
      final successCross = await userBCoordinator.processItem(
        item: itemOwnedByA,
        explicitOwnerUserId: userBId,
      );
      // Fails due to foreign key violation or missing parent profile owned by User B
      expect(successCross, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Cross-user database and Storage access rejection
    // -------------------------------------------------------------------------
    test('12. Cross-user database and Storage access rejection', () async {
      // 1. Cross-user Storage Download Rejection:
      // User B attempts to download User A's consultation file
      final userAConsultFile = '$userAId/$consultationAId/doctor_notes.jpg';
      expect(
        () async => await clientB.storage.from('consultations').download(userAConsultFile),
        throwsA(isA<StorageException>()),
        reason: 'Storage RLS must reject cross-user file download',
      );

      // 2. Cross-user Storage Deletion Rejection:
      // User B attempts to delete User A's consultation file
      final deleteCross =
          await clientB.storage.from('consultations').remove([userAConsultFile]);
      expect(deleteCross, isEmpty,
          reason: 'Storage RLS must reject cross-user file deletion');

      // 3. Cross-user Database Query Rejection across all tables:
      final bProfiles = await clientB.from('profiles').select().eq('user_id', userAId);
      expect(bProfiles, isEmpty);

      final bHospitals = await clientB.from('hospitals').select().eq('user_id', userAId);
      expect(bHospitals, isEmpty);

      final bDoctors = await clientB.from('doctors').select().eq('user_id', userAId);
      expect(bDoctors, isEmpty);

      final bConsults = await clientB.from('consultations').select().eq('user_id', userAId);
      expect(bConsults, isEmpty);

      final bAppts = await clientB.from('appointments').select().eq('user_id', userAId);
      expect(bAppts, isEmpty);

      final bRx = await clientB.from('prescriptions').select().eq('user_id', userAId);
      expect(bRx, isEmpty);

      final bVitals = await clientB.from('measurements').select().eq('user_id', userAId);
      expect(bVitals, isEmpty);

      final bReports = await clientB.from('reports').select().eq('user_id', userAId);
      expect(bReports, isEmpty);

      final bExpenses = await clientB.from('report_expenses').select().eq('user_id', userAId);
      expect(bExpenses, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Attachment partial-failure: parent row preserved until all Storage objects deleted
    // -------------------------------------------------------------------------
    test('13. Attachment partial-failure: parent row preserved until all Storage objects deleted', () async {
      final multiReportId = UuidUtils.generateV4();
      final effectiveProfileId = profileAId ??
          ((await clientA.from('profiles').select().eq('user_id', userAId)).first['id'] as String);

      // 1. Create parent report row in public.reports
      final repRes = await clientA
          .from('reports')
          .insert({
            'id': multiReportId,
            'user_id': userAId,
            'profile_id': effectiveProfileId,
            'title': 'Partial Failure Test Report',
            'category': 'LAB TEST',
            'report_date': '2026-11-14',
          })
          .select()
          .single();
      expect(repRes['id'], equals(multiReportId));

      // 2. Upload multiple disposable test objects to Supabase Storage reports bucket
      final file1Bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final file2Bytes = Uint8List.fromList(List<int>.generate(128, (i) => 255 - i));

      final storagePath1 = '$userAId/$multiReportId/attachment_1.pdf';
      final storagePath2 = '$userAId/$multiReportId/attachment_2.pdf';

      await clientA.storage.from('reports').uploadBinary(
            storagePath1,
            file1Bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );
      await clientA.storage.from('reports').uploadBinary(
            storagePath2,
            file2Bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      // Verify both files exist in remote Supabase Storage
      final listBefore = await clientA.storage
          .from('reports')
          .list(path: '$userAId/$multiReportId');
      final fileNamesBefore = listBefore.map((item) => item.name).toSet();
      expect(fileNamesBefore, containsAll(['attachment_1.pdf', 'attachment_2.pdf']));

      // 3. Instantiate datasource with staged failure storage service (fails on 2nd object)
      final stagedStorage = _StagedFailingStorageService(liveClient: clientA);
      final reportDataSource = SupabaseReportRemoteDataSource(
        client: clientA,
        storageService: stagedStorage,
      );

      // 4. Attempt deletion: 1st object is deleted, 2nd object deletion throws injected failure
      await expectLater(
        () => reportDataSource.deleteReport(
          reportId: multiReportId,
          ownerUserId: userAId,
          profileId: effectiveProfileId,
        ),
        throwsA(isA<ServerException>()),
      );

      // Verify exactly one object was deleted and failure was injected
      expect(stagedStorage.deletedObjectsCount, equals(1));

      // 5. Verify intermediate state:
      // Object 1 is gone from Storage
      // Object 2 still remains in Storage
      final listMid = await clientA.storage
          .from('reports')
          .list(path: '$userAId/$multiReportId');
      final fileNamesMid = listMid.map((item) => item.name).toList();
      expect(fileNamesMid, equals(['attachment_2.pdf']),
          reason: 'Only the first object was removed before storage failure occurred');

      // CRITICAL INVARIANT: Parent database row in public.reports MUST REMAIN!
      final dbCheck = await clientA
          .from('reports')
          .select()
          .eq('id', multiReportId);
      expect(dbCheck, isNotEmpty,
          reason: 'Parent report database row must not be deleted when storage deletion fails midway');
      expect(dbCheck.first['id'], equals(multiReportId));

      // 6. Retry deletion with simulated failure resolved
      stagedStorage.injectFailure = false;
      await reportDataSource.deleteReport(
        reportId: multiReportId,
        ownerUserId: userAId,
        profileId: effectiveProfileId,
      );

      // 7. Verify all remaining objects are removed from Storage
      final listFinal = await clientA.storage
          .from('reports')
          .list(path: '$userAId/$multiReportId');
      expect(listFinal, isEmpty,
          reason: 'All storage attachments must be cleaned up on successful retry');

      // 8. Verify parent deletion occurred in database only after successful cleanup
      final dbFinal = await clientA
          .from('reports')
          .select()
          .eq('id', multiReportId);
      expect(dbFinal, isEmpty,
          reason: 'Parent database row must be deleted after all storage files are cleaned up');
    });
  });
}
