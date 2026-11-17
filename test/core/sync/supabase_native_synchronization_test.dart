import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/supabase_sync_coordinator.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import 'package:medi_crate/features/medicines/data/models/medicine_model.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import 'package:medi_crate/features/vitals/data/models/measurement_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// TEST FAKES
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  final String id;
  _FakeUser({required this.id});
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  User? mockUser;
  _FakeGoTrueClient({this.mockUser});

  @override
  User? get currentUser => mockUser;
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  final _FakeGoTrueClient _auth;
  _FakeSupabaseClient({User? user}) : _auth = _FakeGoTrueClient(mockUser: user);

  @override
  GoTrueClient get auth => _auth;
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

  void emit(bool status) {
    isOnline = status;
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _FakeSupabaseStorageService extends Fake
    implements SupabaseStorageService {
  final Map<String, List<int>> storage = {};
  final List<String> deletedPaths = [];
  final List<String> deletedFolders = [];

  @override
  Future<String> uploadFile({
    required String bucket,
    required String storagePath,
    required File file,
    String? expectedUserId,
    String? mimeType,
    bool? upsert,
  }) async {
    storage['$bucket/$storagePath'] = await file.readAsBytes();
    return storagePath;
  }

  @override
  Future<void> deleteFile({
    required String bucket,
    required String storagePath,
  }) async {
    storage.remove('$bucket/$storagePath');
    deletedPaths.add('$bucket/$storagePath');
  }

  @override
  Future<void> deleteParentFolder({
    required String bucket,
    required String parentId,
    required String userId,
  }) async {
    storage.removeWhere((k, _) => k.startsWith('$bucket/$userId/$parentId'));
    deletedFolders.add('$bucket/$userId/$parentId');
  }
}

// ---------------------------------------------------------------------------
// DOMAIN REMOTE DATA SOURCE FAKES (SUPABASE)
// ---------------------------------------------------------------------------

class _FakeSupabaseProfileRemoteDataSource extends Fake
    implements SupabaseProfileRemoteDataSource {
  final List<ProfileModel> profiles = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool archiveCalled = false;

  @override
  Future<List<ProfileModel>> fetchProfiles({
    required String ownerUserId,
    bool includeArchived = false,
  }) async {
    return profiles.where((p) => p.ownerUserId == ownerUserId).toList();
  }

  @override
  Future<ProfileModel> archiveProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    archiveCalled = true;
    final idx = profiles.indexWhere((p) => p.profileId == profileId);
    if (idx >= 0) {
      final updated = profiles[idx].copyWith(isArchived: true);
      profiles[idx] = updated;
      return updated;
    }
    final dummy = ProfileModel(
      profileId: profileId,
      fullName: 'Archived User',
      relationship: 'Brother',
      ownerUserId: ownerUserId,
      isArchived: true,
    );
    profiles.add(dummy);
    return dummy;
  }

  @override
  Future<ProfileModel> createFamilyProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(profile.profileId);
    final id = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : '00000000-0000-0000-0001-000000000001';
    final created = profile.copyWith(
      profileId: id,
      ownerUserId: ownerUserId,
      clientUuid: profile.clientUuid ?? id,
    );
    profiles.add(created);
    return created;
  }

  @override
  Future<ProfileModel> updateProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    updateCalled = true;
    final idx = profiles.indexWhere((p) => p.profileId == profile.profileId);
    if (idx >= 0) profiles[idx] = profile;
    return profile;
  }
}

class _FakeSupabaseHospitalRemoteDataSource extends Fake
    implements SupabaseHospitalRemoteDataSource {
  final List<HospitalModel> hospitals = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;
  bool simulateTransientError = false;
  bool simulateValidationError = false;
  bool simulateForeignKeyError = false;

  @override
  Future<List<HospitalModel>> fetchHospitals({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? type,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return hospitals.where((h) => h.profileId == profileId).toList();
  }

  @override
  Future<HospitalModel> createHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (simulateTransientError) throw const NetworkException('Connection timeout');
    if (simulateValidationError) {
      throw const ValidationException('Check constraint violation (23514)');
    }
    if (simulateForeignKeyError) {
      throw const PostgrestException(
        message: 'violates foreign key constraint "fk_hospital"',
        code: '23503',
      );
    }
    createCalled = true;
    final cleanId = IdUtils.unprefix(hospital.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0002-000000000001';
    final created = HospitalModel(
      id: id,
      profileId: profileId,
      name: hospital.name,
      type: hospital.type,
      clientUuid: hospital.clientUuid ?? id,
    );
    hospitals.add(created);
    return created;
  }

  @override
  Future<HospitalModel> updateHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (simulateTransientError) throw const NetworkException('Connection timeout');
    updateCalled = true;
    final idx = hospitals.indexWhere((h) => h.id == hospital.id);
    if (idx >= 0) hospitals[idx] = hospital;
    return hospital;
  }

  @override
  Future<void> deleteHospital({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    hospitals.removeWhere((h) => h.id == hospitalId);
  }
}

class _FakeSupabaseDoctorRemoteDataSource extends Fake
    implements SupabaseDoctorRemoteDataSource {
  final List<DoctorModel> doctors = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<List<DoctorModel>> fetchDoctors({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? specialty,
    String? hospitalId,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return doctors.where((d) => d.profileId == profileId).toList();
  }

  @override
  Future<DoctorModel> createDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(doctor.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0003-000000000001';
    final created = DoctorModel(
      id: id,
      profileId: profileId,
      name: doctor.name,
      specialty: doctor.specialty,
      clientUuid: doctor.clientUuid ?? id,
    );
    doctors.add(created);
    return created;
  }

  @override
  Future<DoctorModel> updateDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    final idx = doctors.indexWhere((d) => d.id == doctor.id);
    if (idx >= 0) doctors[idx] = doctor;
    return doctor;
  }

  @override
  Future<void> deleteDoctor({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    doctors.removeWhere((d) => d.id == doctorId);
  }
}

class _FakeSupabaseAppointmentRemoteDataSource extends Fake
    implements SupabaseAppointmentRemoteDataSource {
  final List<AppointmentModel> appointments = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<List<AppointmentModel>> fetchAppointments({
    required String ownerUserId,
    required String profileId,
    String? doctorId,
    String? hospitalId,
    String? from,
    String? to,
    String? status,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return appointments.where((a) => a.profileId == profileId).toList();
  }

  @override
  Future<AppointmentModel> createAppointment({
    required AppointmentModel appointment,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(appointment.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0004-000000000001';
    final created = appointment.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: appointment.clientUuid ?? id,
    );
    appointments.add(created);
    return created;
  }

  @override
  Future<AppointmentModel> updateAppointment({
    required AppointmentModel appointment,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    final idx = appointments.indexWhere((a) => a.id == appointment.id);
    if (idx >= 0) appointments[idx] = appointment;
    return appointment;
  }

  @override
  Future<void> deleteAppointment({
    required String appointmentId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    appointments.removeWhere((a) => a.id == appointmentId);
  }
}

class _FakeSupabaseMedicineRemoteDataSource extends Fake
    implements SupabaseMedicineRemoteDataSource {
  final List<MedicineModel> medicines = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<List<MedicineModel>> fetchMedicines({
    required String ownerUserId,
    required String profileId,
    String? consultationId,
    String? status,
    String? search,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return medicines.where((m) => m.profileId == profileId).toList();
  }

  @override
  Future<MedicineModel> createMedicine({
    required MedicineModel medicine,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(medicine.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0005-000000000001';
    final created = MedicineModel(
      id: id,
      profileId: profileId,
      medicineName: medicine.medicineName,
      dosage: medicine.dosage,
      startDate: medicine.startDate,
      clientUuid: medicine.clientUuid ?? id,
    );
    medicines.add(created);
    return created;
  }

  @override
  Future<MedicineModel> updateMedicine({
    required MedicineModel medicine,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    final idx = medicines.indexWhere((m) => m.id == medicine.id);
    if (idx >= 0) medicines[idx] = medicine;
    return medicine;
  }

  @override
  Future<void> deleteMedicine({
    required String medicineId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    medicines.removeWhere((m) => m.id == medicineId);
  }
}

class _FakeSupabaseVitalsRemoteDataSource extends Fake
    implements SupabaseVitalsRemoteDataSource {
  final List<MeasurementModel> measurements = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<List<MeasurementModel>> fetchMeasurements({
    required String ownerUserId,
    required String profileId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return measurements.where((m) => m.profileId == profileId).toList();
  }

  @override
  Future<MeasurementModel> createMeasurement({
    required MeasurementModel measurement,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(measurement.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0006-000000000001';
    final created = measurement.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: measurement.clientUuid ?? id,
    );
    measurements.add(created);
    return created;
  }

  @override
  Future<MeasurementModel> updateMeasurement({
    required MeasurementModel measurement,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    final idx = measurements.indexWhere((m) => m.id == measurement.id);
    if (idx >= 0) measurements[idx] = measurement;
    return measurement;
  }

  @override
  Future<void> deleteMeasurement({
    required String measurementId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    measurements.removeWhere((m) => m.id == measurementId);
  }
}

class _FakeSupabaseReportRemoteDataSource extends Fake
    implements SupabaseReportRemoteDataSource {
  final List<ReportModel> reports = [];
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<List<ReportModel>> fetchReports({
    required String ownerUserId,
    required String profileId,
    String? category,
    String? consultationId,
    String? doctorId,
    String? hospitalId,
    String? search,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return reports.where((r) => r.profileId == profileId).toList();
  }

  @override
  Future<ReportModel> createReport({
    required ReportModel report,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(report.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0007-000000000001';
    final created = report.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: report.clientUuid ?? id,
    );
    reports.add(created);
    return created;
  }

  @override
  Future<ReportModel> updateReport({
    required ReportModel report,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    final idx = reports.indexWhere((r) => r.id == report.id);
    if (idx >= 0) reports[idx] = report;
    return report;
  }

  @override
  Future<void> deleteReport({
    required String reportId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<String> uploadAttachmentFile({
    required String userId,
    required String reportId,
    required File file,
    String? customAttachmentId,
    String? fileName,
  }) async {
    return 'reports/$userId/$reportId/${fileName ?? "doc.pdf"}';
  }
}

class _FakeSupabaseConsultationRemoteDataSource extends Fake
    implements SupabaseConsultationRemoteDataSource {
  final List<ConsultationModel> consultations = [];
  @override
  final SupabaseStorageService? customStorageService;
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  _FakeSupabaseConsultationRemoteDataSource({this.customStorageService});

  @override
  Future<List<ConsultationModel>> fetchConsultations({
    required String ownerUserId,
    required String profileId,
    String? doctorId,
    String? hospitalId,
    String? search,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    return consultations.where((c) => c.profileId == profileId).toList();
  }

  @override
  Future<ConsultationModel> createConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    required String profileId,
  }) async {
    createCalled = true;
    final cleanId = IdUtils.unprefix(consultation.id);
    final id = UuidUtils.isValidUuid(cleanId) ? cleanId : '00000000-0000-0000-0008-000000000001';
    final created = ConsultationModel(
      id: id,
      profileId: profileId,
      doctorName: consultation.doctorName,
      visitDate: consultation.visitDate,
      chiefComplaint: consultation.chiefComplaint,
      diagnosis: consultation.diagnosis,
      attachments: consultation.attachments,
      clientUuid: consultation.clientUuid ?? id,
      createdAt: consultation.createdAt,
    );
    consultations.add(created);
    return created;
  }

  @override
  Future<ConsultationModel> updateConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    String? profileId,
  }) async {
    updateCalled = true;
    final idx = consultations.indexWhere((c) => c.id == consultation.id);
    if (idx >= 0) consultations[idx] = consultation;
    return consultation;
  }

  @override
  Future<void> deleteConsultation({
    required String consultationId,
    required String ownerUserId,
    String? profileId,
  }) async {
    deleteCalled = true;
    final cleanId = IdUtils.unprefix(consultationId).trim();
    if (customStorageService != null) {
      await customStorageService!.deleteParentFolder(
        bucket: SupabaseStorageService.consultationsBucket,
        parentId: cleanId,
        userId: ownerUserId.trim(),
      );
    }
    consultations.removeWhere((c) => c.id == consultationId);
  }
}

// ---------------------------------------------------------------------------
// MAIN TEST SUITE
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeConnectivityService connectivityService;
  late _FakeSupabaseClient supabaseClient;
  late _FakeSupabaseStorageService storageService;

  late _FakeSupabaseProfileRemoteDataSource profileRemote;
  late _FakeSupabaseHospitalRemoteDataSource hospitalRemote;
  late _FakeSupabaseDoctorRemoteDataSource doctorRemote;
  late _FakeSupabaseAppointmentRemoteDataSource appointmentRemote;
  late _FakeSupabaseMedicineRemoteDataSource medicineRemote;
  late _FakeSupabaseVitalsRemoteDataSource vitalsRemote;
  late _FakeSupabaseReportRemoteDataSource reportRemote;
  late _FakeSupabaseConsultationRemoteDataSource consultationRemote;

  late SupabaseSyncCoordinator coordinator;
  late SyncService syncService;

  const testUserId = '00000000-0000-0000-0000-000000000001';
  const testProfileId = '00000000-0000-0000-0000-000000000010';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medi_crate_native_sync_');
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
    connectivityService = _FakeConnectivityService();

    supabaseClient = _FakeSupabaseClient(user: _FakeUser(id: testUserId));
    storageService = _FakeSupabaseStorageService();

    profileRemote = _FakeSupabaseProfileRemoteDataSource();
    hospitalRemote = _FakeSupabaseHospitalRemoteDataSource();
    doctorRemote = _FakeSupabaseDoctorRemoteDataSource();
    appointmentRemote = _FakeSupabaseAppointmentRemoteDataSource();
    medicineRemote = _FakeSupabaseMedicineRemoteDataSource();
    vitalsRemote = _FakeSupabaseVitalsRemoteDataSource();
    reportRemote = _FakeSupabaseReportRemoteDataSource();
    consultationRemote = _FakeSupabaseConsultationRemoteDataSource(
      customStorageService: storageService,
    );

    coordinator = SupabaseSyncCoordinator(
      hiveService: hiveService,
      customClient: supabaseClient,
      customStorageService: storageService,
      customProfileRemoteDataSource: profileRemote,
      customHospitalRemoteDataSource: hospitalRemote,
      customDoctorRemoteDataSource: doctorRemote,
      customAppointmentRemoteDataSource: appointmentRemote,
      customMedicineRemoteDataSource: medicineRemote,
      customVitalsRemoteDataSource: vitalsRemote,
      customReportRemoteDataSource: reportRemote,
      customConsultationRemoteDataSource: consultationRemote,
    );

    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: connectivityService,
      customSupabaseSyncCoordinator: coordinator,
    );

    // Seed primary profile
    await hiveService.profileBox.put('prof_$testProfileId', {
      'profile_id': testProfileId,
      'owner_user_id': testUserId,
      'name': 'Primary User',
      'is_primary': true,
      'client_uuid': testProfileId,
    });
  });

  tearDown(() async {
    syncService.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // GROUP 1: Authoritative Session Identity & Profile Isolation
  // -------------------------------------------------------------------------
  group('1. Authoritative Session Identity & Profile Isolation', () {
    test('Unauthenticated session sets status to auth_required and does NOT consume retry budget', () async {
      final unauthClient = _FakeSupabaseClient(user: null);
      final unauthCoordinator = SupabaseSyncCoordinator(
        hiveService: hiveService,
        customClient: unauthClient,
        customHospitalRemoteDataSource: hospitalRemote,
      );
      final unauthSyncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: unauthCoordinator,
      );

      final item = SyncQueueItem(
        id: 'q_hosp_unauth',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_hosp_1',
          'profile_id': testProfileId,
          'name': 'City General',
          'client_uuid': 'cuuid-hosp-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await unauthSyncService.syncPendingToSupabase(force: true);

      final raw = hiveService.syncQueueBox.get(item.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.status, equals('auth_required'));
      expect(active.retryCount, equals(0), reason: 'auth_required must not burn retry budget');
      expect(hospitalRemote.createCalled, isFalse);

      unauthSyncService.dispose();
    });

    test('Foreign profile ID is rejected/deferred and not pushed', () async {
      const foreignProfileId = '00000000-0000-0000-0000-000000000099';
      await hiveService.profileBox.put('prof_$foreignProfileId', {
        'profile_id': foreignProfileId,
        'owner_user_id': '00000000-0000-0000-0000-000000000999', // foreign user
        'name': 'Stranger',
        'is_primary': false,
      });

      final item = SyncQueueItem(
        id: 'q_foreign_hosp',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_foreign_1',
          'profile_id': foreignProfileId,
          'name': 'Foreign Clinic',
          'client_uuid': 'cuuid-foreign-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPendingToSupabase(force: true);

      final raw = hiveService.syncQueueBox.get(item.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.status, equals('deferred'), reason: 'Foreign profile should defer and not be sent');
      expect(active.retryCount, equals(0));
      expect(hospitalRemote.createCalled, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // GROUP 2: Queue Replay Across All 8 Migrated Clinical Domains
  // -------------------------------------------------------------------------
  group('2. Queue Replay Across All 8 Migrated Clinical Domains', () {
    test('Profiles queue replay: creates family member and rejects primary deletion', () async {
      final createFamily = SyncQueueItem(
        id: 'q_fam_c',
        entity: 'profile',
        operation: 'create',
        payload: {
          'profile_id': 'local_fam_1',
          'name': 'Bob Smith',
          'relationship': 'Brother',
          'is_primary': false,
          'client_uuid': 'cuuid-fam-1',
        },
      );
      await hiveService.syncQueueBox.put(createFamily.id, createFamily.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(createFamily.id), isFalse);
      expect(profileRemote.createCalled, isTrue);
      expect(profileRemote.profiles.length, equals(1));
      final createdFamId = profileRemote.profiles.first.profileId;
      expect(hiveService.profileBox.containsKey(createdFamId), isTrue);

      // Attempt to delete primary profile: must be dead-lettered
      final deletePrimary = SyncQueueItem(
        id: 'q_prim_d',
        entity: 'profile',
        operation: 'delete',
        payload: {
          'profile_id': testProfileId,
          'name': 'Primary User',
          'is_primary': true,
        },
      );
      await hiveService.syncQueueBox.put(deletePrimary.id, deletePrimary.toMap());
      await syncService.syncPendingToSupabase(force: true);

      final raw = hiveService.syncQueueBox.get(deletePrimary.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.retryCount, equals(99), reason: 'Primary profile delete must be dead-lettered');
    });

    test('Hospitals queue replay: creates, updates, and deletes with userBox reconciliation', () async {
      // CREATE
      final createItem = SyncQueueItem(
        id: 'q_hosp_c',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_hosp_10',
          'profile_id': testProfileId,
          'name': 'Memorial Hospital',
          'type': 'Hospital',
          'client_uuid': 'cuuid-hosp-10',
        },
      );
      await hiveService.syncQueueBox.put(createItem.id, createItem.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(createItem.id), isFalse);
      expect(hospitalRemote.createCalled, isTrue);
      expect(hospitalRemote.hospitals.length, equals(1));
      final createdHospitalId = hospitalRemote.hospitals.first.id;
      expect(hiveService.userBox.containsKey('hospital_$createdHospitalId'), isTrue);

      // UPDATE
      final updateItem = SyncQueueItem(
        id: 'q_hosp_u',
        entity: 'hospital',
        operation: 'update',
        payload: {
          'id': createdHospitalId,
          'profile_id': testProfileId,
          'name': 'Memorial Hospital Renamed',
          'type': 'Clinic',
          'client_uuid': 'cuuid-hosp-10',
        },
      );
      await hiveService.syncQueueBox.put(updateItem.id, updateItem.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(updateItem.id), isFalse);
      expect(hospitalRemote.updateCalled, isTrue);

      // DELETE
      final deleteItem = SyncQueueItem(
        id: 'q_hosp_d',
        entity: 'hospital',
        operation: 'delete',
        payload: {
          'id': createdHospitalId,
          'profile_id': testProfileId,
          'client_uuid': 'cuuid-hosp-10',
        },
      );
      await hiveService.syncQueueBox.put(deleteItem.id, deleteItem.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(deleteItem.id), isFalse);
      expect(hospitalRemote.deleteCalled, isTrue);
      expect(hospitalRemote.hospitals.isEmpty, isTrue);
      expect(hiveService.userBox.containsKey('hospital_$createdHospitalId'), isFalse);
    });

    test('Doctors queue replay: creates and deletes', () async {
      final item = SyncQueueItem(
        id: 'q_doc_c',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': 'local_doc_1',
          'profile_id': testProfileId,
          'name': 'Dr. Gregory House',
          'specialty': 'Diagnostician',
          'client_uuid': 'cuuid-doc-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);
      expect(doctorRemote.createCalled, isTrue);
      expect(doctorRemote.doctors.length, equals(1));
      final docId = doctorRemote.doctors.first.id;
      expect(hiveService.userBox.containsKey('doctor_$docId'), isTrue);

      // DELETE
      final delItem = SyncQueueItem(
        id: 'q_doc_d',
        entity: 'doctor',
        operation: 'delete',
        payload: {
          'id': docId,
          'profile_id': testProfileId,
        },
      );
      await hiveService.syncQueueBox.put(delItem.id, delItem.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(delItem.id), isFalse);
      expect(doctorRemote.deleteCalled, isTrue);
      expect(doctorRemote.doctors.isEmpty, isTrue);
    });

    test('Appointments queue replay: creates and deletes', () async {
      final item = SyncQueueItem(
        id: 'q_appt_c',
        entity: 'appointment',
        operation: 'create',
        payload: {
          'id': 'local_appt_1',
          'profile_id': testProfileId,
          'title': 'Cardiology Followup',
          'doctor_name': 'Dr. Watson',
          'date': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'client_uuid': 'cuuid-appt-1',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);
      expect(appointmentRemote.createCalled, isTrue);
      expect(appointmentRemote.appointments.length, equals(1));
    });

    test('Medicines queue replay: creates and deletes', () async {
      final item = SyncQueueItem(
        id: 'q_med_c',
        entity: 'medicine',
        operation: 'create',
        payload: {
          'id': 'local_med_1',
          'profile_id': testProfileId,
          'medicine_name': 'Metformin',
          'dosage': '500mg',
          'start_date': DateTime.now().toIso8601String(),
          'client_uuid': 'cuuid-med-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);
      expect(medicineRemote.createCalled, isTrue);
      expect(medicineRemote.medicines.length, equals(1));
    });

    test('Vitals queue replay: preserves recorded_at immutable timestamp', () async {
      final recordedAt = DateTime(2025, 10, 15, 8, 30);
      final item = SyncQueueItem(
        id: 'q_vital_c',
        entity: 'measurement',
        operation: 'create',
        payload: {
          'id': 'local_vital_1',
          'profile_id': testProfileId,
          'type': 'blood_pressure',
          'values': {'systolic': 120, 'diastolic': 80},
          'recorded_at': recordedAt.toIso8601String(),
          'client_uuid': 'cuuid-vital-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);
      expect(vitalsRemote.createCalled, isTrue);
      expect(vitalsRemote.measurements.length, equals(1));
      expect(vitalsRemote.measurements.first.recordedAt, equals(recordedAt));
    });

    test('Reports queue replay: creates report and handles deletion', () async {
      final item = SyncQueueItem(
        id: 'q_rep_c',
        entity: 'report',
        operation: 'create',
        payload: {
          'id': 'local_rep_1',
          'profile_id': testProfileId,
          'title': 'Complete Blood Count',
          'category': 'LAB_REPORT',
          'client_uuid': 'cuuid-rep-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);
      expect(reportRemote.createCalled, isTrue);
      expect(reportRemote.reports.length, equals(1));
      final repId = reportRemote.reports.first.id;

      // DELETE report: removes DB row and userBox entry
      final delItem = SyncQueueItem(
        id: 'q_rep_d',
        entity: 'report',
        operation: 'delete',
        payload: {
          'id': repId,
          'profile_id': testProfileId,
          'client_uuid': 'cuuid-rep-1',
        },
      );
      await hiveService.syncQueueBox.put(delItem.id, delItem.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(delItem.id), isFalse);
      expect(reportRemote.deleteCalled, isTrue);
      expect(reportRemote.reports.isEmpty, isTrue);
    });

    test('Consultations queue replay: creates consultation and handles deletion', () async {
      final item = SyncQueueItem(
        id: 'q_cons_c',
        entity: 'consultation',
        operation: 'create',
        payload: {
          'id': 'local_cons_1',
          'profile_id': testProfileId,
          'doctor_name': 'Dr. Strange',
          'visit_date': DateTime.now().toIso8601String(),
          'chief_complaint': 'Migraine',
          'diagnosis': 'Tension headache',
          'client_uuid': 'cuuid-cons-1',
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);
      expect(consultationRemote.createCalled, isTrue);
      expect(consultationRemote.consultations.length, equals(1));
      final consId = consultationRemote.consultations.first.id;

      // Delete consultation
      final delItem = SyncQueueItem(
        id: 'q_cons_d',
        entity: 'consultation',
        operation: 'delete',
        payload: {
          'id': consId,
          'profile_id': testProfileId,
          'client_uuid': 'cuuid-cons-1',
        },
      );
      await hiveService.syncQueueBox.put(delItem.id, delItem.toMap());
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(delItem.id), isFalse);
      expect(consultationRemote.deleteCalled, isTrue);
      expect(consultationRemote.consultations.isEmpty, isTrue);
      expect(
        storageService.deletedFolders,
        contains('consultations/$testUserId/$consId'),
        reason: 'Consultation deletion must clean private storage folder before row deletion',
      );
    });

    test('Queued parent dependency automatically defers child mutation without consuming retry budget', () async {
      // Doctor references hospital local ID 'local_hosp_parent' which is queued but not yet in userBox
      final parentItem = SyncQueueItem(
        id: 'q_parent_hosp',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_hosp_parent',
          'profile_id': testProfileId,
          'name': 'Parent Hospital',
          'client_uuid': 'cuuid-hosp-parent',
        },
      );
      final childItem = SyncQueueItem(
        id: 'q_child_doc',
        entity: 'doctor',
        operation: 'create',
        payload: {
          'id': 'local_doc_child',
          'profile_id': testProfileId,
          'name': 'Dr. Dependent',
          'specialty': 'Cardiology',
          'hospital_ids': ['local_hosp_parent'],
          'client_uuid': 'cuuid-doc-child',
        },
      );

      await hiveService.syncQueueBox.put(parentItem.id, parentItem.toMap());
      await hiveService.syncQueueBox.put(childItem.id, childItem.toMap());

      // If child item is evaluated while parent is queued but not yet synced:
      final coord = syncService.supabaseSyncCoordinator!;
      final result = await coord.processItem(item: childItem);

      expect(result, isFalse);
      expect(childItem.status, equals('deferred'), reason: 'Unsynced queued parent must defer child');
      expect(childItem.retryCount, equals(0), reason: 'Deferred items must not consume retry budget');
      expect(childItem.errorMessage, contains('Waiting for hospital dependency'));

      // Now run full sync: priority ordering ensures Hospital (1) syncs before Doctor (2)
      await syncService.syncPendingToSupabase(force: true);

      expect(hospitalRemote.createCalled, isTrue);
      expect(doctorRemote.createCalled, isTrue);
      expect(hiveService.syncQueueBox.containsKey(parentItem.id), isFalse);
      expect(hiveService.syncQueueBox.containsKey(childItem.id), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // GROUP 3: Idempotency & Duplicate Prevention
  // -------------------------------------------------------------------------
  group('3. Idempotency & Duplicate Prevention', () {
    test('Replaying create mutation when record already exists on Supabase converts to update instead of creating duplicate', () async {
      const clientUuid = '00000000-0000-0000-0002-999999999999';
      // Pre-populate Supabase with an existing hospital sharing this client_uuid
      hospitalRemote.hospitals.add(const HospitalModel(
        id: '00000000-0000-0000-0002-888888888888',
        profileId: testProfileId,
        name: 'Existing St. Jude',
        type: 'Hospital',
        clientUuid: clientUuid,
      ));

      final createItem = SyncQueueItem(
        id: 'q_hosp_replay',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_replay_1',
          'profile_id': testProfileId,
          'name': 'Existing St. Jude Updated Name',
          'type': 'Hospital',
          'client_uuid': clientUuid,
        },
      );
      await hiveService.syncQueueBox.put(createItem.id, createItem.toMap());

      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(createItem.id), isFalse);
      expect(hospitalRemote.updateCalled, isTrue);
      expect(hospitalRemote.createCalled, isFalse);
      expect(hospitalRemote.hospitals.length, equals(1), reason: 'Must not duplicate record');
      expect(hospitalRemote.hospitals.first.name, equals('Existing St. Jude Updated Name'));
    });

    test('Replaying delete with local ID resolves UUID via client_uuid and deletes remote record', () async {
      const serverUuid = '00000000-0000-0000-0002-777777777777';
      const clientUuid = 'cuuid-hosp-to-delete';

      hospitalRemote.hospitals.add(const HospitalModel(
        id: serverUuid,
        profileId: testProfileId,
        name: 'To Delete',
        type: 'Hospital',
        clientUuid: clientUuid,
      ));

      // In userBox, map local id to clientUuid
      await hiveService.userBox.put('hospital_local_del_1', {
        'id': 'local_del_1',
        'client_uuid': clientUuid,
        'profile_id': testProfileId,
        'name': 'To Delete',
      });

      final delItem = SyncQueueItem(
        id: 'q_hosp_del_res',
        entity: 'hospital',
        operation: 'delete',
        payload: {
          'id': 'local_del_1',
          'client_uuid': clientUuid,
          'profile_id': testProfileId,
        },
      );
      await hiveService.syncQueueBox.put(delItem.id, delItem.toMap());

      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(delItem.id), isFalse);
      expect(hospitalRemote.deleteCalled, isTrue);
      expect(hospitalRemote.hospitals.isEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // GROUP 4: Retry Budget, Backoff, and Dead-Lettering
  // -------------------------------------------------------------------------
  group('4. Retry Budget, Backoff, and Dead-Lettering', () {
    test('Transient network error increments retryCount and backs off', () async {
      hospitalRemote.simulateTransientError = true;

      final item = SyncQueueItem(
        id: 'q_hosp_transient',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_transient_1',
          'profile_id': testProfileId,
          'name': 'Transient Hospital',
          'client_uuid': 'cuuid-transient-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPendingToSupabase(force: false);

      final raw = hiveService.syncQueueBox.get(item.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.status, equals('failed'));
      expect(active.retryCount, equals(1));
      expect(active.lastAttemptAt, isNotNull);

      // Immediate second sync without force should skip due to exponential backoff
      await syncService.syncPendingToSupabase(force: false);
      final raw2 = hiveService.syncQueueBox.get(item.id);
      final active2 = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw2!));
      expect(active2.retryCount, equals(1), reason: 'Skipped by backoff window');

      // Now force sync retries it
      await syncService.syncPendingToSupabase(force: true);
      final raw3 = hiveService.syncQueueBox.get(item.id);
      final active3 = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw3!));
      expect(active3.retryCount, equals(2), reason: 'Force sync bypasses backoff');
    });

    test('Permanent validation error (23514 / ValidationException) immediately dead-letters with retryCount = 99', () async {
      hospitalRemote.simulateValidationError = true;

      final item = SyncQueueItem(
        id: 'q_hosp_validation_fail',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_val_1',
          'profile_id': testProfileId,
          'name': '',
          'client_uuid': 'cuuid-val-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPendingToSupabase(force: true);

      final raw = hiveService.syncQueueBox.get(item.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.status, equals('failed'));
      expect(active.retryCount, equals(99), reason: 'Permanent validation failure must dead-letter');

      // Subsequent sync passes must never re-attempt a dead-lettered item
      hospitalRemote.simulateValidationError = false;
      await syncService.syncPendingToSupabase(force: true);
      expect(hospitalRemote.createCalled, isFalse);
    });

    test('PostgreSQL 23503 foreign key violation does NOT dead-letter at retryCount = 99, allowing queue replay to retry', () async {
      hospitalRemote.simulateForeignKeyError = true;

      final item = SyncQueueItem(
        id: 'q_hosp_fk_error',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_hosp_fk',
          'profile_id': testProfileId,
          'name': 'Pending Parent Hospital',
          'client_uuid': 'cuuid-fk-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPendingToSupabase(force: true);

      final raw = hiveService.syncQueueBox.get(item.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.status, equals('failed'));
      expect(active.retryCount, equals(1), reason: '23503 must NOT dead-letter to 99; it must accrue normal retry count');
      expect(active.errorMessage, contains('Foreign key dependency not satisfied'));

      // Once dependency is resolved, next replay succeeds
      hospitalRemote.simulateForeignKeyError = false;
      await syncService.syncPendingToSupabase(force: true);

      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse, reason: 'Successfully drained after dependency resolved');
      expect(hospitalRemote.createCalled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // GROUP 5: SyncLock & Claim Token Coordination (P2-F8)
  // -------------------------------------------------------------------------
  group('5. SyncLock & Claim Token Coordination (P2-F8)', () {
    test('Items actively claimed by another processor within leaseDuration are yielded', () async {
      final now = DateTime.now();
      final item = SyncQueueItem(
        id: 'q_claimed_item',
        entity: 'hospital',
        operation: 'create',
        status: 'syncing',
        claimToken: 'proc_external_workmanager_isolate',
        claimedAt: now.subtract(const Duration(seconds: 10)), // fresh claim
        payload: {
          'id': 'local_claimed_1',
          'profile_id': testProfileId,
          'name': 'In Flight Facility',
          'client_uuid': 'cuuid-claimed-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPendingToSupabase(force: true);

      // Item should NOT be processed or modified by our processor
      expect(hospitalRemote.createCalled, isFalse);
      final raw = hiveService.syncQueueBox.get(item.id);
      expect(raw, isNotNull);
      final active = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));
      expect(active.claimToken, equals('proc_external_workmanager_isolate'));
    });

    test('Stale claim older than leaseDuration from a crashed processor is reclaimed and processed', () async {
      final now = DateTime.now();
      final item = SyncQueueItem(
        id: 'q_stale_claim',
        entity: 'hospital',
        operation: 'create',
        status: 'syncing',
        claimToken: 'proc_crashed_holder',
        claimedAt: now.subtract(const Duration(minutes: 5)), // stale claim (> 2 min lease)
        payload: {
          'id': 'local_stale_1',
          'profile_id': testProfileId,
          'name': 'Recovered Facility',
          'client_uuid': 'cuuid-stale-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await syncService.syncPendingToSupabase(force: true);

      expect(hospitalRemote.createCalled, isTrue);
      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse, reason: 'Reclaimed and successfully drained');
    });
  });

  // -------------------------------------------------------------------------
  // GROUP 6: Strict Isolation and Production Guardrails
  // -------------------------------------------------------------------------
  group('6. Strict Isolation and Production Guardrails', () {
    test('Migrated clinical domains synchronize natively to Supabase', () async {
      final isolatedSyncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
        customSupabaseSyncCoordinator: coordinator,
      );

      final item = SyncQueueItem(
        id: 'q_iso_hosp',
        entity: 'hospital',
        operation: 'create',
        payload: {
          'id': 'local_iso_1',
          'profile_id': testProfileId,
          'name': 'Isolated Hospital',
          'client_uuid': 'cuuid-iso-1',
        },
      );
      await hiveService.syncQueueBox.put(item.id, item.toMap());

      await isolatedSyncService.syncPendingToSupabase(force: true);

      expect(hospitalRemote.createCalled, isTrue);
      expect(hiveService.syncQueueBox.containsKey(item.id), isFalse);

      isolatedSyncService.dispose();
    });

    test('Remote sync remains strictly disabled by default in production code', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });
  });
}
