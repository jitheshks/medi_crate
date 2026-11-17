// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('Hosted Supabase Flutter-to-Backend Integration Verification', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailA = 'test_user_a_$timestamp@medicrate.app';
    final emailB = 'test_user_b_$timestamp@medicrate.app';
    final emailC = 'test_user_c_$timestamp@medicrate.app';
    const password = 'IntegrationPassword123!';

    late SupabaseClient clientA;
    late SupabaseClient clientB;
    late SupabaseClient clientC;

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
    late SupabaseReportRemoteDataSource reportB;
    late SupabaseStorageService storageB;

    late SupabaseAuthRemoteDataSource authC;
    late SupabaseProfileRemoteDataSource profileC;
    late SupabaseHospitalRemoteDataSource hospitalC;
    late SupabaseDoctorRemoteDataSource doctorC;
    late SupabaseConsultationRemoteDataSource consultationC;
    late SupabaseStorageService storageC;

    String? userAId;
    String? userBId;
    String? userCId;

    ProfileModel? primaryProfileA;
    ProfileModel? secondaryProfileA;

    HospitalModel? createdHospitalA;
    DoctorModel? createdDoctorA;
    ConsultationModel? createdConsultationA;

    Future<void> confirmUsersInDatabase(List<String> emails) async {
      final emailList = emails.map((e) => "'$e'").join(', ');
      for (var attempt = 1; attempt <= 3; attempt++) {
        final res = await Process.run('supabase', [
          'db',
          'query',
          '--linked',
          'UPDATE auth.users SET email_confirmed_at = NOW() WHERE email IN ($emailList);',
        ]);
        if (res.exitCode == 0) return;
        if (attempt == 3) {
          throw Exception('Failed to confirm users (attempt $attempt): ${res.stdout} ${res.stderr}');
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    SupabaseClient createClient() {
      return SupabaseClient(
        supabaseUrl,
        anonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    }

    test('1. Authentication and Profile Lifecycle (User A)', () async {
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

      // 1. Sign up through actual Flutter auth remote data source
      final signUpRes = await authA.signUp(
        name: 'Alice Integration',
        email: emailA,
        password: password,
      );
      expect(signUpRes, isNotNull);

      // Confirm email in auth.users
      await confirmUsersInDatabase([emailA]);

      // 2. Log in through actual Flutter auth remote data source
      final loginRes = await authA.login(email: emailA, password: password);
      expect(loginRes, isNotNull);
      userAId = clientA.auth.currentUser?.id;
      expect(userAId, isNotNull);
      expect(userAId, isNotEmpty);

      // 3. Verify 'Self' primary profile was automatically bootstrapped by trigger
      final profiles = await profileA.fetchProfiles(ownerUserId: userAId!);
      expect(profiles, isNotEmpty);
      primaryProfileA = profiles.firstWhere((p) => p.isPrimary);
      expect(primaryProfileA!.fullName, 'Alice Integration');
      expect(primaryProfileA!.relationship, 'Self');
      expect(primaryProfileA!.isArchived, isFalse);

      // 4. Create secondary family profile
      final familyProfile = ProfileModel(
        profileId: '',
        ownerUserId: userAId!,
        fullName: 'Alice Mother',
        relationship: 'Mother',
        isPrimary: false,
        isArchived: false,
      );
      secondaryProfileA = await profileA.createFamilyProfile(
        profile: familyProfile,
        ownerUserId: userAId!,
      );
      expect(secondaryProfileA!.profileId, isNotEmpty);
      expect(secondaryProfileA!.isPrimary, isFalse);

      // 5. Test in-place soft archival on secondary profile
      final archivedSecondary = await profileA.archiveProfile(
        profileId: secondaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(archivedSecondary.isArchived, isTrue);
      expect(archivedSecondary.archivedAt, isNotNull);

      // 6. Verify primary profile protection (archiving primary MUST fail)
      expect(
        () async => await profileA.archiveProfile(
          profileId: primaryProfileA!.profileId,
          ownerUserId: userAId!,
        ),
        throwsA(isA<ValidationException>()),
      );

      // 7. Verify session restoration and logout
      await authA.signOut();
      expect(clientA.auth.currentUser, isNull);

      // Log back in to continue domain verification
      await authA.login(email: emailA, password: password);
      expect(clientA.auth.currentUser?.id, userAId);
    });

    test('2. Domain Integration Verification (All 10 Domain Entities)', () async {
      expect(userAId, isNotNull);
      expect(primaryProfileA, isNotNull);

      // A. Hospitals
      final hospital = HospitalModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        name: 'Metro Specialty Hospital',
        type: 'Hospital',
        phone: '+919876543210',
        email: 'contact@metrohosp.org',
      );
      createdHospitalA = await hospitalA.createHospital(
        hospital: hospital,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdHospitalA!.id, isNotEmpty);
      expect(createdHospitalA!.name, 'Metro Specialty Hospital');

      final hospitalsList = await hospitalA.fetchHospitals(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(hospitalsList.any((h) => h.id == createdHospitalA!.id), isTrue);

      final updatedHospital = await hospitalA.updateHospital(
        hospital: createdHospitalA!.copyWith(name: 'Metro Advanced Hospital'),
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(updatedHospital.name, 'Metro Advanced Hospital');

      // B. Doctors and Affiliations (Atomic RPC: save_doctor_with_affiliations)
      final doctor = DoctorModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        name: 'Dr. Gregory House',
        specialty: 'Diagnostic Medicine',
        hospitalName: 'Metro Advanced Hospital',
        hospitalIds: [createdHospitalA!.id],
        phone: '+919123456789',
        email: 'house@metro.org',
        isFavorite: true,
      );
      createdDoctorA = await doctorA.createDoctor(
        doctor: doctor,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdDoctorA!.id, isNotEmpty);
      expect(createdDoctorA!.name, 'Dr. Gregory House');
      expect(createdDoctorA!.hospitalIds, contains(createdHospitalA!.id));

      final doctorsList = await doctorA.fetchDoctors(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(doctorsList.any((d) => d.id == createdDoctorA!.id), isTrue);

      // C. Consultations
      final consultation = ConsultationModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        doctorId: createdDoctorA!.id,
        doctorName: createdDoctorA!.name,
        doctorSpecialty: createdDoctorA!.specialty,
        hospitalId: createdHospitalA!.id,
        hospitalName: createdHospitalA!.name,
        visitDate: DateTime.now(),
        chiefComplaint: 'Acute Gastritis Assessment',
        diagnosis: 'Mild Gastric Irritation',
        clinicalNotes: 'Prescribed PPI medication. Return in 2 weeks.',
        consultationFee: 600.0,
        currency: 'INR',
        followUpStatus: 'pending',
        createdAt: DateTime.now(),
      );
      createdConsultationA = await consultationA.createConsultation(
        consultation: consultation,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdConsultationA!.id, isNotEmpty);
      expect(createdConsultationA!.chiefComplaint, 'Acute Gastritis Assessment');

      final consultsList = await consultationA.fetchConsultations(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(consultsList.any((c) => c.id == createdConsultationA!.id), isTrue);

      // D. Consultation Attachments (Relational Metadata & Storage)
      final attachPath = '${userAId!}/${createdConsultationA!.id}/prescription_note.pdf';
      await storageA.uploadBytes(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: attachPath,
        fileName: 'prescription_note.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]),
        mimeType: 'application/pdf',
      );
      final attachId = UuidUtils.generateV4();
      await clientA.from('consultation_attachments').insert({
        'id': attachId,
        'user_id': userAId!,
        'consultation_id': createdConsultationA!.id,
        'name': 'prescription_note.pdf',
        'file_path': attachPath,
        'file_type': 'application/pdf',
        'size_bytes': 8,
      });

      // E. Prescriptions (Medicines)
      final medicine = MedicineModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        medicineName: 'Pantoprazole',
        dosage: '40mg',
        form: 'Tablet',
        frequency: 'Once daily before breakfast',
        startDate: DateTime.now(),
        linkedConsultationId: createdConsultationA!.id,
      );
      final createdMed = await medicineA.createMedicine(
        medicine: medicine,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdMed.id, isNotEmpty);
      expect(createdMed.medicineName, 'Pantoprazole');

      final medsList = await medicineA.fetchMedicines(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(medsList.any((m) => m.id == createdMed.id), isTrue);

      // F. Appointments
      final appointment = AppointmentModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        title: 'Gastritis Follow-up Visit',
        doctorId: createdDoctorA!.id,
        doctorName: createdDoctorA!.name,
        hospitalId: createdHospitalA!.id,
        hospitalName: createdHospitalA!.name,
        date: DateTime.now().add(const Duration(days: 14)),
        status: 'scheduled',
        cost: 450.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final createdAppt = await appointmentA.createAppointment(
        appointment: appointment,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdAppt.id, isNotEmpty);
      expect(createdAppt.title, 'Gastritis Follow-up Visit');

      final apptsList = await appointmentA.fetchAppointments(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(apptsList.any((a) => a.id == createdAppt.id), isTrue);

      // G. Reports, Attachments & Expenses
      final report = ReportModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        title: 'Complete Blood Count',
        category: 'Lab Test',
        date: DateTime.now(),
        doctorName: createdDoctorA!.name,
        hospitalName: createdHospitalA!.name,
      );
      final createdRep = await reportA.createReport(
        report: report,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdRep.id, isNotEmpty);
      expect(createdRep.title, 'Complete Blood Count');

      final repAttachPath = '${userAId!}/${createdRep.id}/cbc_result.pdf';
      await storageA.uploadBytes(
        bucket: SupabaseStorageService.reportsBucket,
        storagePath: repAttachPath,
        fileName: 'cbc_result.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]),
        mimeType: 'application/pdf',
      );
      await clientA.from('report_attachments').insert({
        'id': UuidUtils.generateV4(),
        'user_id': userAId!,
        'report_id': createdRep.id,
        'name': 'cbc_result.pdf',
        'file_path': repAttachPath,
        'file_type': 'application/pdf',
        'size_bytes': 8,
      });

      await clientA.from('report_expenses').insert({
        'id': UuidUtils.generateV4(),
        'user_id': userAId!,
        'report_id': createdRep.id,
        'amount': 350.0,
        'currency': 'INR',
        'status': 'PAID',
        'description': 'CBC Laboratory Fee',
      });

      final reportsList = await reportA.fetchReports(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(reportsList.any((r) => r.id == createdRep.id), isTrue);

      // H. Measurements (Vitals)
      final vital = MeasurementModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        type: 'blood_pressure',
        title: 'Blood Pressure',
        value: '120/80',
        systolic: 120.0,
        diastolic: 80.0,
        unit: 'mmHg',
        status: 'Normal',
        recordedAt: DateTime.now(),
      );
      final createdVital = await vitalsA.createMeasurement(
        measurement: vital,
        ownerUserId: userAId!,
        profileId: primaryProfileA!.profileId,
      );
      expect(createdVital.id, isNotEmpty);
      expect(createdVital.systolic, 120.0);
      expect(createdVital.diastolic, 80.0);

      final vitalsList = await vitalsA.fetchMeasurements(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userAId!,
      );
      expect(vitalsList.any((v) => v.id == createdVital.id), isTrue);
    });

    test('3. Storage Verification (Upload, Download, MIME/Size Validation, Signed URLs)', () async {
      expect(userAId, isNotNull);

      // 1. Upload Avatar
      final avatarPath = '${userAId!}/profile_pic.png';
      await storageA.uploadBytes(
        bucket: SupabaseStorageService.avatarsBucket,
        storagePath: avatarPath,
        fileName: 'profile_pic.png',
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        mimeType: 'image/png',
      );

      // 2. Signed URL Generation
      final signedUrl = await storageA.createSignedUrl(
        bucket: SupabaseStorageService.avatarsBucket,
        storagePath: avatarPath,
        expiresInSeconds: 300,
      );
      expect(signedUrl, contains('avatars'));
      expect(signedUrl, contains('token='));

      // 3. Authorized Download
      final downloadedBytes = await storageA.downloadBytes(
        bucket: SupabaseStorageService.avatarsBucket,
        storagePath: avatarPath,
      );
      expect(downloadedBytes.length, 8);

      // 4. Client-side MIME validation rejection
      expect(
        () async => await storageA.uploadBytes(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: '${userAId!}/malicious.exe',
          fileName: 'malicious.exe',
          bytes: Uint8List.fromList([0x4D, 0x5A]),
          mimeType: 'application/x-msdownload',
        ),
        throwsA(isA<StorageValidationException>()),
      );

      // 5. Client-side Size validation rejection (>5MB for avatar)
      final oversizedBytes = Uint8List(SupabaseStorageService.maxAvatarSizeBytes + 1024);
      expect(
        () async => await storageA.uploadBytes(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: '${userAId!}/huge_avatar.png',
          fileName: 'huge_avatar.png',
          bytes: oversizedBytes,
          mimeType: 'image/png',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('4. Security & RLS Isolation Verification (User B vs User A)', () async {
      clientB = createClient();
      authB = SupabaseAuthRemoteDataSource(clientB);
      profileB = SupabaseProfileRemoteDataSource(customClient: clientB);
      hospitalB = SupabaseHospitalRemoteDataSource(customClient: clientB);
      doctorB = SupabaseDoctorRemoteDataSource(customClient: clientB);
      consultationB = SupabaseConsultationRemoteDataSource(client: clientB);
      reportB = SupabaseReportRemoteDataSource(client: clientB);
      storageB = SupabaseStorageService(customClient: clientB);

      // Sign up and confirm User B
      await authB.signUp(
        name: 'Bob Attacker',
        email: emailB,
        password: password,
      );
      await confirmUsersInDatabase([emailB]);
      await authB.login(email: emailB, password: password);
      userBId = clientB.auth.currentUser?.id;
      expect(userBId, isNotNull);

      // Verify User B can fetch their own profile, but cannot see User A's profile
      final bProfiles = await profileB.fetchProfiles(ownerUserId: userBId!);
      expect(bProfiles, isNotEmpty);
      expect(bProfiles.first.ownerUserId, userBId);
      expect(bProfiles.any((p) => p.profileId == primaryProfileA!.profileId), isFalse);

      // 1. Cross-user SELECT: User B querying User A's data returns empty list
      final crossHospitals = await hospitalB.fetchHospitals(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userBId!,
      );
      expect(crossHospitals, isEmpty);

      final crossDoctors = await doctorB.fetchDoctors(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userBId!,
      );
      expect(crossDoctors, isEmpty);

      final crossConsultations = await consultationB.fetchConsultations(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userBId!,
      );
      expect(crossConsultations, isEmpty);

      final crossReports = await reportB.fetchReports(
        profileId: primaryProfileA!.profileId,
        ownerUserId: userBId!,
      );
      expect(crossReports, isEmpty);

      // 2. Cross-user INSERT: User B attempting to create consultation under User A's profile fails
      final unauthorizedConsultation = ConsultationModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        doctorName: 'Dr. Spy',
        hospitalName: 'Spy Hospital',
        visitDate: DateTime.now(),
        chiefComplaint: 'Unauthorized Inspection',
        diagnosis: 'Breach Attempt',
        createdAt: DateTime.now(),
      );
      expect(
        () async => await consultationB.createConsultation(
          consultation: unauthorizedConsultation,
          ownerUserId: userBId!,
          profileId: primaryProfileA!.profileId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // 3. Cross-user Storage Access Rejection: User B downloading User A's file fails
      expect(
        () async => await storageB.downloadBytes(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: '${userAId!}/profile_pic.png',
        ),
        throwsA(isA<StorageValidationException>()),
      );

      // 4. Cross-user RPC Rejection: User B calling save_doctor_with_affiliations with User A's profile
      final crossDoctor = DoctorModel(
        id: '',
        profileId: primaryProfileA!.profileId,
        name: 'Dr. Cross Clinician',
        specialty: 'Exploitation',
      );
      expect(
        () async => await doctorB.createDoctor(
          doctor: crossDoctor,
          ownerUserId: userBId!,
          profileId: primaryProfileA!.profileId,
        ),
        throwsA(isA<ValidationException>()),
      );

      // 5. Archived Profile Mutation Rejection: User A creating consultation under archived secondary profile
      final archivedProfileConsultation = ConsultationModel(
        id: '',
        profileId: secondaryProfileA!.profileId, // Archived profile
        doctorName: 'Dr. Gregory House',
        hospitalName: 'Metro Advanced Hospital',
        visitDate: DateTime.now(),
        chiefComplaint: 'Post-archival visit',
        diagnosis: 'Checkup',
        createdAt: DateTime.now(),
      );
      expect(
        () async => await consultationA.createConsultation(
          consultation: archivedProfileConsultation,
          ownerUserId: userAId!,
          profileId: secondaryProfileA!.profileId,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('5. Complete Account Deletion Lifecycle (User C)', () async {
      clientC = createClient();
      authC = SupabaseAuthRemoteDataSource(clientC);
      profileC = SupabaseProfileRemoteDataSource(customClient: clientC);
      hospitalC = SupabaseHospitalRemoteDataSource(customClient: clientC);
      doctorC = SupabaseDoctorRemoteDataSource(customClient: clientC);
      consultationC = SupabaseConsultationRemoteDataSource(client: clientC);
      storageC = SupabaseStorageService(customClient: clientC);

      // Sign up and confirm User C
      await authC.signUp(
        name: 'Charlie DeletionTarget',
        email: emailC,
        password: password,
      );
      await confirmUsersInDatabase([emailC]);
      await authC.login(email: emailC, password: password);
      userCId = clientC.auth.currentUser?.id;
      expect(userCId, isNotNull);

      final profilesC = await profileC.fetchProfiles(ownerUserId: userCId!);
      final profC = profilesC.firstWhere((p) => p.isPrimary);

      // Create hospital, doctor, consultation
      final hospC = await hospitalC.createHospital(
        hospital: HospitalModel(
          id: '',
          profileId: profC.profileId,
          name: 'Charlie Hospital',
          type: 'Hospital',
        ),
        ownerUserId: userCId!,
        profileId: profC.profileId,
      );

      final docC = await doctorC.createDoctor(
        doctor: DoctorModel(
          id: '',
          profileId: profC.profileId,
          name: 'Dr. Charlie Physician',
          specialty: 'Internal Medicine',
          hospitalIds: [hospC.id],
        ),
        ownerUserId: userCId!,
        profileId: profC.profileId,
      );

      final consultC = await consultationC.createConsultation(
        consultation: ConsultationModel(
          id: '',
          profileId: profC.profileId,
          doctorId: docC.id,
          doctorName: docC.name,
          hospitalId: hospC.id,
          hospitalName: hospC.name,
          visitDate: DateTime.now(),
          chiefComplaint: 'Charlie Complaint',
          diagnosis: 'Charlie Diagnosis',
          createdAt: DateTime.now(),
        ),
        ownerUserId: userCId!,
        profileId: profC.profileId,
      );

      // Upload file to consultations and avatars buckets
      final consultFilePath = '${userCId!}/${consultC.id}/report.pdf';
      await storageC.uploadBytes(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: consultFilePath,
        fileName: 'report.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        mimeType: 'application/pdf',
      );

      final avatarFilePath = '${userCId!}/avatar.png';
      await storageC.uploadBytes(
        bucket: SupabaseStorageService.avatarsBucket,
        storagePath: avatarFilePath,
        fileName: 'avatar.png',
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        mimeType: 'image/png',
      );

      // 1. Direct RPC invocation while storage objects exist MUST fail with precondition check
      expect(
        () async => await clientC.rpc('delete_user_account'),
        throwsA(isA<PostgrestException>()),
      );

      // 2. Call Flutter deleteAccount() workflow:
      // It must purge storage files, call delete_user_account RPC, and terminate GoTrue session!
      await authC.deleteAccount(currentPassword: password);

      // Session must be terminated
      expect(clientC.auth.currentUser, isNull);

      // 3. Verify in database that User C is completely purged
      final checkRes = await Process.run('supabase', [
        'db',
        'query',
        '--linked',
        "SELECT count(*) FROM auth.users WHERE id = '$userCId';",
      ]);
      expect(checkRes.stdout.toString(), contains('"count": 0'));

      // Verify clinical records were cascade-deleted
      final consultCheck = await Process.run('supabase', [
        'db',
        'query',
        '--linked',
        "SELECT count(*) FROM public.consultations WHERE user_id = '$userCId';",
      ]);
      expect(consultCheck.stdout.toString(), contains('"count": 0'));
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
