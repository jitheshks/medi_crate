// ignore_for_file: depend_on_referenced_packages, unused_local_variable

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
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

  group('Deep Security, RLS & Storage Authorization Verification', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailA = 'sec_user_a_$timestamp@fldubai.com';
    final emailB = 'sec_user_b_$timestamp@fldubai.com';
    const password = 'SecurityPassword123!';

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
    late SupabaseHospitalRemoteDataSource hospitalB;
    late SupabaseDoctorRemoteDataSource doctorB;
    late SupabaseConsultationRemoteDataSource consultationB;
    late SupabaseAppointmentRemoteDataSource appointmentB;
    late SupabaseMedicineRemoteDataSource medicineB;
    late SupabaseReportRemoteDataSource reportB;
    late SupabaseVitalsRemoteDataSource vitalsB;
    late SupabaseStorageService storageB;

    String? userAId;
    String? userBId;
    ProfileModel? primaryProfileA;
    ProfileModel? secondaryProfileA;

    HospitalModel? hospA;
    DoctorModel? docA;
    ConsultationModel? conA;
    AppointmentModel? apptA;
    MedicineModel? medA;
    ReportModel? repA;
    MeasurementModel? vitA;
    String? reportFilePathA;

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
      hospitalB = SupabaseHospitalRemoteDataSource(customClient: clientB);
      doctorB = SupabaseDoctorRemoteDataSource(customClient: clientB);
      consultationB = SupabaseConsultationRemoteDataSource(client: clientB);
      appointmentB = SupabaseAppointmentRemoteDataSource(client: clientB);
      medicineB = SupabaseMedicineRemoteDataSource(client: clientB);
      reportB = SupabaseReportRemoteDataSource(client: clientB);
      vitalsB = SupabaseVitalsRemoteDataSource(client: clientB);
      storageB = SupabaseStorageService(customClient: clientB);

      // Sign up User A and User B
      await authA.signUp(name: 'Alice Security', email: emailA, password: password);
      await authB.signUp(name: 'Bob Malicious', email: emailB, password: password);
      await confirmUsers([emailA, emailB]);

      await authA.login(email: emailA, password: password);
      userAId = clientA.auth.currentUser?.id;
      final profsA = await profileA.fetchProfiles(ownerUserId: userAId!);
      primaryProfileA = profsA.firstWhere((p) => p.isPrimary);

      await authB.login(email: emailB, password: password);
      userBId = clientB.auth.currentUser?.id;

      // Seed complete baseline records under User A
      hospA = await hospitalA.createHospital(
        hospital: HospitalModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          name: 'Target Hospital A',
          type: 'Hospital',
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      docA = await doctorA.createDoctor(
        doctor: DoctorModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          name: 'Dr. Target Physician',
          specialty: 'Cardiology',
          hospitalIds: [hospA!.id],
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      conA = await consultationA.createConsultation(
        consultation: ConsultationModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          doctorId: docA!.id,
          doctorName: docA!.name,
          hospitalId: hospA!.id,
          hospitalName: hospA!.name,
          visitDate: DateTime.now(),
          chiefComplaint: 'Chest tightness',
          diagnosis: 'Stable Angina',
          createdAt: DateTime.now(),
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      apptA = await appointmentA.createAppointment(
        appointment: AppointmentModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          title: 'Cardio Follow-up',
          doctorId: docA!.id,
          doctorName: docA!.name,
          hospitalId: hospA!.id,
          hospitalName: hospA!.name,
          date: DateTime.now().add(const Duration(days: 7)),
          status: 'scheduled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      medA = await medicineA.createMedicine(
        medicine: MedicineModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          medicineName: 'Aspirin',
          dosage: '75mg',
          startDate: DateTime.now(),
          linkedConsultationId: conA!.id,
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      repA = await reportA.createReport(
        report: ReportModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          title: 'ECG Report',
          category: 'Diagnostic',
          date: DateTime.now(),
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      vitA = await vitalsA.createMeasurement(
        measurement: MeasurementModel(
          id: '',
          profileId: primaryProfileA!.profileId,
          type: 'heart_rate',
          title: 'Heart Rate',
          value: '72',
          numericValue: 72,
          unit: 'bpm',
          status: 'Normal',
          recordedAt: DateTime.now(),
        ),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );

      // Upload file to reports bucket under User A
      reportFilePathA = '${userAId!}/${repA!.id}/ecg_trace.pdf';
      await storageA.uploadBytes(
        bucket: SupabaseStorageService.reportsBucket,
        storagePath: reportFilePathA!,
        fileName: 'ecg_trace.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]),
        mimeType: 'application/pdf',
      );

      // Create and archive secondary family profile for User A
      secondaryProfileA = await profileA.createFamilyProfile(
        profile: ProfileModel(
          profileId: '',
          ownerUserId: userAId!,
          fullName: 'Alice Dependent Child',
          relationship: 'Daughter',
        ),
        ownerUserId: userAId!,
      );
      secondaryProfileA = await profileA.archiveProfile(
        profileId: secondaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
    });

    test('1. Cross-User UPDATE Mutation Rejection Across All Domains', () async {
      final cleanHospId = IdUtils.unprefix(hospA!.id);
      final cleanDocId = IdUtils.unprefix(docA!.id);
      final cleanConId = IdUtils.unprefix(conA!.id);
      final cleanApptId = IdUtils.unprefix(apptA!.id);
      final cleanMedId = IdUtils.unprefix(medA!.id);
      final cleanRepId = IdUtils.unprefix(repA!.id);
      final cleanVitId = IdUtils.unprefix(vitA!.id);

      // User B attempts to mutate User A's hospital
      final hospUpdate = await clientB
          .from('hospitals')
          .update({'name': 'Hijacked Hospital'})
          .eq('id', cleanHospId)
          .select();
      expect(hospUpdate, isEmpty, reason: 'RLS must reject cross-user hospital UPDATE');

      // User B attempts to mutate User A's doctor
      final docUpdate = await clientB
          .from('doctors')
          .update({'name': 'Hijacked Doctor'})
          .eq('id', cleanDocId)
          .select();
      expect(docUpdate, isEmpty, reason: 'RLS must reject cross-user doctor UPDATE');

      // User B attempts to mutate User A's consultation
      final conUpdate = await clientB
          .from('consultations')
          .update({'chief_complaint': 'Tampered Complaint'})
          .eq('id', cleanConId)
          .select();
      expect(conUpdate, isEmpty, reason: 'RLS must reject cross-user consultation UPDATE');

      // User B attempts to mutate User A's appointment
      final apptUpdate = await clientB
          .from('appointments')
          .update({'title': 'Tampered Appointment'})
          .eq('id', cleanApptId)
          .select();
      expect(apptUpdate, isEmpty, reason: 'RLS must reject cross-user appointment UPDATE');

      // User B attempts to mutate User A's prescription
      final medUpdate = await clientB
          .from('prescriptions')
          .update({'medicine_name': 'Poison'})
          .eq('id', cleanMedId)
          .select();
      expect(medUpdate, isEmpty, reason: 'RLS must reject cross-user prescription UPDATE');

      // User B attempts to mutate User A's report
      final repUpdate = await clientB
          .from('reports')
          .update({'title': 'Tampered Report'})
          .eq('id', cleanRepId)
          .select();
      expect(repUpdate, isEmpty, reason: 'RLS must reject cross-user report UPDATE');

      // User B attempts to mutate User A's vital measurement
      final vitUpdate = await clientB
          .from('measurements')
          .update({'value': '999'})
          .eq('id', cleanVitId)
          .select();
      expect(vitUpdate, isEmpty, reason: 'RLS must reject cross-user measurement UPDATE');
    });

    test('2. Cross-User DELETE Rejection Across All Domains', () async {
      final cleanHospId = IdUtils.unprefix(hospA!.id);
      final cleanDocId = IdUtils.unprefix(docA!.id);
      final cleanConId = IdUtils.unprefix(conA!.id);
      final cleanApptId = IdUtils.unprefix(apptA!.id);
      final cleanMedId = IdUtils.unprefix(medA!.id);
      final cleanRepId = IdUtils.unprefix(repA!.id);
      final cleanVitId = IdUtils.unprefix(vitA!.id);

      // User B attempts to delete User A's records
      final delHosp = await clientB.from('hospitals').delete().eq('id', cleanHospId).select();
      expect(delHosp, isEmpty, reason: 'RLS must block cross-user hospital DELETE');

      final delDoc = await clientB.from('doctors').delete().eq('id', cleanDocId).select();
      expect(delDoc, isEmpty, reason: 'RLS must block cross-user doctor DELETE');

      final delCon = await clientB.from('consultations').delete().eq('id', cleanConId).select();
      expect(delCon, isEmpty, reason: 'RLS must block cross-user consultation DELETE');

      final delAppt = await clientB.from('appointments').delete().eq('id', cleanApptId).select();
      expect(delAppt, isEmpty, reason: 'RLS must block cross-user appointment DELETE');

      final delMed = await clientB.from('prescriptions').delete().eq('id', cleanMedId).select();
      expect(delMed, isEmpty, reason: 'RLS must block cross-user prescription DELETE');

      final delRep = await clientB.from('reports').delete().eq('id', cleanRepId).select();
      expect(delRep, isEmpty, reason: 'RLS must block cross-user report DELETE');

      final delVit = await clientB.from('measurements').delete().eq('id', cleanVitId).select();
      expect(delVit, isEmpty, reason: 'RLS must block cross-user measurement DELETE');

      // Verify that all User A records are intact
      final checkHosp = await clientA.from('hospitals').select().eq('id', cleanHospId).single();
      expect(checkHosp['name'], 'Target Hospital A');
    });

    test('3. Storage UPDATE, DELETE & Ownership Boundary Verification', () async {
      // User B attempting to delete User A's file in storage via service
      expect(
        () async => await storageB.deleteFile(
          bucket: SupabaseStorageService.reportsBucket,
          storagePath: reportFilePathA!,
        ),
        throwsA(isA<StorageValidationException>()),
      );

      // User B attempting direct Storage API remove on User A's file
      final directRemoveRes = await clientB.storage
          .from(SupabaseStorageService.reportsBucket)
          .remove([reportFilePathA!]);
      expect(directRemoveRes, isEmpty, reason: 'Storage RLS must block cross-user file removal');

      // User B attempting to overwrite User A's file with upsert: true
      expect(
        () async => await storageB.uploadBytes(
          bucket: SupabaseStorageService.reportsBucket,
          storagePath: reportFilePathA!,
          fileName: 'ecg_trace.pdf',
          bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
          mimeType: 'application/pdf',
          upsert: true,
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('4. Signed URLs: Bearer Download vs Unauthenticated Raw Access & Tampering', () async {
      // User A creates signed URL for ecg_trace.pdf
      final signedUrlString = await storageA.createSignedUrl(
        bucket: SupabaseStorageService.reportsBucket,
        storagePath: reportFilePathA!,
        expiresInSeconds: 300,
      );

      // 1. Authorized bearer download via HTTP GET without any auth headers
      final publicHttpClient = http.Client();
      final signedResponse = await publicHttpClient.get(Uri.parse(signedUrlString));
      expect(signedResponse.statusCode, 200, reason: 'Valid signed URL must permit bearer download');
      expect(signedResponse.bodyBytes.length, 8);

      // 2. Raw unauthenticated access without signed token must be rejected (400 or 404)
      final rawObjectUri = Uri.parse('$supabaseUrl/storage/v1/object/${SupabaseStorageService.reportsBucket}/$reportFilePathA');
      final unauthResponse = await publicHttpClient.get(rawObjectUri);
      expect(unauthResponse.statusCode, anyOf([400, 403, 404]), reason: 'Raw private bucket access without token must be rejected');

      // 3. Tampered signed URL (modifying token) must be rejected
      final tamperedUri = Uri.parse('$signedUrlString&tamper=true').replace(
        queryParameters: {
          ...Uri.parse(signedUrlString).queryParameters,
          'token': 'invalid_tampered_token_signature_xyz',
        },
      );
      final tamperedResponse = await publicHttpClient.get(tamperedUri);
      expect(tamperedResponse.statusCode, anyOf([400, 403]), reason: 'Tampered token signature must be rejected');
      publicHttpClient.close();
    });

    test('5. Archived Profile Mutation Invariants (All Domains)', () async {
      final archivedId = secondaryProfileA!.profileId;

      // Inserting consultation under archived profile must be rejected
      expect(
        () async => await consultationA.createConsultation(
          consultation: ConsultationModel(
            id: '',
            profileId: archivedId,
            doctorName: 'Dr. Gregory House',
            hospitalName: 'Metro Hospital',
            visitDate: DateTime.now(),
            chiefComplaint: 'Archived Visit',
            diagnosis: 'Blocked',
            createdAt: DateTime.now(),
          ),
          ownerUserId: userAId!,
          profileId: archivedId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // Inserting appointment under archived profile must be rejected
      expect(
        () async => await appointmentA.createAppointment(
          appointment: AppointmentModel(
            id: '',
            profileId: archivedId,
            title: 'Archived Appointment',
            doctorName: 'Dr. Gregory House',
            date: DateTime.now().add(const Duration(days: 2)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ownerUserId: userAId!,
          profileId: archivedId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // Inserting medicine under archived profile must be rejected
      expect(
        () async => await medicineA.createMedicine(
          medicine: MedicineModel(
            id: '',
            profileId: archivedId,
            medicineName: 'Archived Drug',
            dosage: '10mg',
            startDate: DateTime.now(),
          ),
          ownerUserId: userAId!,
          profileId: archivedId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // Inserting report under archived profile must be rejected
      expect(
        () async => await reportA.createReport(
          report: ReportModel(
            id: '',
            profileId: archivedId,
            title: 'Archived Report',
            category: 'Lab',
            date: DateTime.now(),
          ),
          ownerUserId: userAId!,
          profileId: archivedId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // Inserting vitals measurement under archived profile must be rejected
      expect(
        () async => await vitalsA.createMeasurement(
          measurement: MeasurementModel(
            id: '',
            profileId: archivedId,
            type: 'blood_pressure',
            title: 'Blood Pressure',
            value: '120/80',
            unit: 'mmHg',
            status: 'Normal',
            recordedAt: DateTime.now(),
          ),
          ownerUserId: userAId!,
          profileId: archivedId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('6. RPC Ownership Enforcement (save_doctor_with_affiliations)', () async {
      // User B calling RPC attempting to link their doctor to User A's hospital
      final foreignHospDoctor = DoctorModel(
        id: '',
        profileId: (await profileB.fetchProfiles(ownerUserId: userBId!)).first.profileId,
        name: 'Dr. Malicious Affiliation',
        specialty: 'Exploitation',
        hospitalIds: [hospA!.id], // User A's hospital!
      );

      expect(
        () async => await doctorB.createDoctor(
          doctor: foreignHospDoctor,
          ownerUserId: userBId!,
          profileId: foreignHospDoctor.profileId,
        ),
        throwsA(isA<ValidationException>()),
        reason: 'save_doctor_with_affiliations must reject linking foreign hospital not owned by user',
      );
    });

    tearDownAll(() async {
      // Clean up User A and User B
      if (userAId != null) {
        try {
          await authA.deleteAccount(currentPassword: password);
        } catch (_) {
          await Process.run('supabase', [
            'db',
            'query',
            '--linked',
            "DELETE FROM auth.users WHERE id = '$userAId';",
          ]);
        }
      }
      if (userBId != null) {
        try {
          await authB.deleteAccount(currentPassword: password);
        } catch (_) {
          await Process.run('supabase', [
            'db',
            'query',
            '--linked',
            "DELETE FROM auth.users WHERE id = '$userBId';",
          ]);
        }
      }
    });
  });
}
