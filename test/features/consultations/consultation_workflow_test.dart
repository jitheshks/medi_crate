import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_attachment.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/features/medicines/data/models/medicine_model.dart';
import 'package:medi_crate/features/medicines/data/repositories/medicine_repository.dart';
import 'package:medi_crate/features/medicines/presentation/providers/medicine_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/reports/data/repositories/report_repository.dart';
import 'package:medi_crate/features/reports/presentation/providers/reports_providers.dart';

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  _FakeActiveProfileNotifier(this._profile);
  final ProfileModel? _profile;

  @override
  ProfileModel? build() => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late ConsultationRepository consultationRepo;

  final testProfile = ProfileModel(
    profileId: 'prof_test_1',
    serverProfileId: 101,
    ownerUserId: 'user_1',
    fullName: 'Jane Doe',
    relationship: 'Self',
    isPrimary: true,
    allergies: const [],
    chronicConditions: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('consultation_workflow_test_');
    Hive.init(tempDir.path);
    for (final boxName in const [
      HiveService.authBoxName,
      HiveService.syncQueueBoxName,
      HiveService.userBoxName,
      HiveService.settingsBoxName,
      HiveService.consentBoxName,
      HiveService.profileBoxName,
    ]) {
      await Hive.openBox<Map>(boxName);
    }
    hiveService = HiveService();

    // Store active profile in profileBox
    await hiveService.profileBox.put('profile_prof_test_1', testProfile.toMap());
    await hiveService.profileBox.put('active_profile_id', {'id': 'prof_test_1'});

    consultationRepo = ConsultationRepository(
      hiveService: hiveService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Consultation Workflow — Persistence, Offline & Duplicates', () {
    test('1. Create and retrieve consultation in Hive with normalized key', () async {
      final now = DateTime.now();
      final consultation = ConsultationModel(
        id: 'con_create_1',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Gregory House',
        doctorId: 'doc_101',
        doctorSpecialty: 'Diagnostic Medicine',
        hospitalName: 'Princeton Plainsboro',
        hospitalId: 'hosp_201',
        visitDate: now,
        chiefComplaint: 'Severe Migraine',
        diagnosis: 'Cluster Headache',
        clinicalNotes: 'Prescribed rest and sumatriptan.',
        isFollowUpRequired: true,
        followUpDate: now.add(const Duration(days: 7)),
        followUpTime: '10:00',
        tags: const ['Headache', 'Acute'],
        consultationFee: 750.0,
        currency: 'INR',
        createdAt: now,
      );

      final saved = await consultationRepo.saveConsultationModel(
        testProfile.profileId,
        consultation,
      );

      expect(saved.id, 'consultation_create_1');
      expect(saved.doctorName, 'Dr. Gregory House');
      expect(saved.doctorId, 'doc_101');
      expect(saved.hospitalName, 'Princeton Plainsboro');
      expect(saved.hospitalId, 'hosp_201');

      // Verify stored in Hive under normalized key
      final inBox = hiveService.userBox.get('consultation_create_1');
      expect(inBox, isNotNull);
      expect(inBox!['diagnosis'], 'Cluster Headache');

      // Verify retrieval by normalized ID, prefix, and unprefixed ID
      final retrievedByNorm = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'consultation_create_1',
      );
      expect(retrievedByNorm, isNotNull);
      expect(retrievedByNorm!.diagnosis, 'Cluster Headache');

      final retrievedByLegacy = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'con_create_1',
      );
      expect(retrievedByLegacy, isNotNull);
      expect(retrievedByLegacy!.id, 'consultation_create_1');

      final retrievedByUnprefixed = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'create_1',
      );
      expect(retrievedByUnprefixed, isNotNull);
      expect(retrievedByUnprefixed!.id, 'consultation_create_1');
    });

    test('2. Edit existing consultation in Hive and preserve createdAt & clientUuid', () async {
      final initialDate = DateTime(2025, 4, 10, 10, 0);
      final initialModel = ConsultationModel(
        id: 'con_edit_test',
        profileId: testProfile.profileId,
        doctorName: 'Dr. James Wilson',
        visitDate: initialDate,
        chiefComplaint: 'Fatigue',
        diagnosis: 'Anemia',
        clientUuid: 'uuid-1234-abcd',
        createdAt: initialDate,
      );

      await consultationRepo.saveConsultationModel(
        testProfile.profileId,
        initialModel,
      );

      final existing = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'con_edit_test',
      );
      expect(existing, isNotNull);
      expect(existing!.createdAt.year, 2025);
      expect(existing.clientUuid, 'uuid-1234-abcd');

      // Update the consultation (e.g. follow-up notes and fee)
      final updatedModel = existing.copyWith(
        diagnosis: 'Iron Deficiency Anemia',
        clinicalNotes: 'Initiated iron supplement therapy.',
        consultationFee: 500.0,
      );

      final savedUpdate = await consultationRepo.saveConsultationModel(
        testProfile.profileId,
        updatedModel,
      );

      expect(savedUpdate.diagnosis, 'Iron Deficiency Anemia');
      expect(savedUpdate.clinicalNotes, 'Initiated iron supplement therapy.');
      expect(savedUpdate.createdAt.year, 2025);
      expect(savedUpdate.createdAt.month, 4);
      expect(savedUpdate.createdAt.day, 10);
      expect(savedUpdate.clientUuid, 'uuid-1234-abcd');
    });

    test('3. Avoid duplicate records when saving or updating across prefix variants', () async {
      // Put a legacy record directly into userBox with 'con_dup_check'
      final rawData = {
        'id': 'con_dup_check',
        'profile_id': testProfile.profileId,
        'doctor_name': 'Dr. Robert Chase',
        'visit_date': DateTime.now().toIso8601String(),
        'chiefComplaint': 'Cough',
        'diagnosis': 'Bronchitis',
        'created_at': DateTime.now().toIso8601String(),
      };
      await hiveService.userBox.put('con_dup_check', rawData);

      expect(hiveService.userBox.containsKey('con_dup_check'), isTrue);

      // Now save via saveConsultationModel with id 'con_dup_check'
      final model = ConsultationModel.fromJson(rawData).copyWith(
        diagnosis: 'Acute Bronchitis',
      );
      await consultationRepo.saveConsultationModel(testProfile.profileId, model);

      // Verify normalized key exists
      expect(hiveService.userBox.containsKey('consultation_dup_check'), isTrue);
      // Verify legacy key was cleanly pruned to avoid duplicates
      expect(hiveService.userBox.containsKey('con_dup_check'), isFalse);

      final all = await consultationRepo.getConsultationModels(testProfile.profileId);
      final matching = all.where((c) => IdUtils.unprefix(c.id) == 'dup_check').toList();
      expect(matching.length, 1);
    });

    test('4. Profile ownership isolation: consultations of other profiles are excluded', () async {
      final myConsultation = ConsultationModel(
        id: 'con_my_prof',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Allison Cameron',
        visitDate: DateTime.now(),
        chiefComplaint: 'Rash',
        diagnosis: 'Allergic Dermatitis',
        createdAt: DateTime.now(),
      );
      final otherConsultation = ConsultationModel(
        id: 'con_other_prof',
        profileId: 'prof_other_999',
        doctorName: 'Dr. Lisa Cuddy',
        visitDate: DateTime.now(),
        chiefComplaint: 'Headache',
        diagnosis: 'Tension Headache',
        createdAt: DateTime.now(),
      );

      await consultationRepo.saveConsultationModel(testProfile.profileId, myConsultation);
      await consultationRepo.saveConsultationModel('prof_other_999', otherConsultation);

      final myList = await consultationRepo.getConsultationModels(testProfile.profileId);
      expect(myList.any((c) => c.id == 'consultation_my_prof'), isTrue);
      expect(myList.any((c) => c.id == 'consultation_other_prof'), isFalse);

      final otherRetrieved = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'consultation_other_prof',
      );
      expect(otherRetrieved, isNull);
    });
  });

  group('Consultation Workflow — Doctor, Hospital & Form Relationships', () {
    test('5. Doctor & Hospital snapshots and IDs are preserved', () async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(testProfile)),
          consultationRepositoryProvider.overrideWithValue(consultationRepo),
          medicineRepositoryProvider.overrideWithValue(MedicineRepository(hiveService: hiveService)),
          reportRepositoryProvider.overrideWithValue(ReportRepository(hiveService: hiveService)),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      // Pre-seed doctor and hospital into Hive
      final doctor = DoctorModel(
        id: 'doc_cardio_1',
        profileId: testProfile.profileId,
        name: 'Dr. John Watson',
        specialty: 'Cardiology',
        hospitalName: 'St. Jude Hospital',
        hospitalIds: const ['hosp_st_jude'],
      );
      final hospital = HospitalModel(
        id: 'hosp_st_jude',
        profileId: testProfile.profileId,
        name: 'St. Jude Hospital',
      );
      await hiveService.userBox.put('doctor_cardio_1', doctor.toJson());
      await hiveService.userBox.put('hospital_st_jude', hospital.toJson());

      // Save consultation using container form helper
      await saveConsultationRecordContainer(
        container: container,
        doctorName: doctor.name,
        doctorId: doctor.id,
        doctorSpecialty: doctor.specialty,
        hospitalName: hospital.name,
        hospitalId: hospital.id,
        chiefComplaint: 'Chest Pain on Exertion',
        diagnosis: 'Angina Pectoris',
        visitDate: DateTime.now(),
        isFollowUpRequired: true,
        followUpDate: DateTime.now().add(const Duration(days: 14)),
      );

      final consultations = await consultationRepo.getConsultationModels(testProfile.profileId);
      expect(consultations.isNotEmpty, isTrue);
      final con = consultations.first;
      expect(con.doctorName, 'Dr. John Watson');
      expect(con.doctorId, 'doc_cardio_1');
      expect(con.doctorSpecialty, 'Cardiology');
      expect(con.hospitalName, 'St. Jude Hospital');
      expect(con.hospitalId, 'hosp_st_jude');
    });
  });

  group('Consultation Workflow — Prescriptions, Reports & Attachments', () {
    test('6. Prescription medicines associated with consultation are queryable and block deletion', () async {
      final consultation = ConsultationModel(
        id: 'con_with_deps',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Eric Foreman',
        visitDate: DateTime.now(),
        chiefComplaint: 'Hypertension Check',
        diagnosis: 'Stage 1 Hypertension',
        createdAt: DateTime.now(),
      );
      await consultationRepo.saveConsultationModel(testProfile.profileId, consultation);

      // Link a prescribed medicine to this consultation
      final medicineData = {
        'id': 'med_amlodipine_1',
        'profile_id': testProfile.profileId,
        'medicine_name': 'Amlodipine',
        'dosage': '5mg',
        'frequency': 'Once Daily',
        'linked_consultation_id': 'consultation_with_deps',
        'created_at': DateTime.now().toIso8601String(),
      };
      await hiveService.userBox.put('medicine_amlodipine_1', medicineData);

      // Verify dependencies detect linked medicine
      final deps = await consultationRepo.getConsultationDependencies(
        testProfile.profileId,
        'consultation_with_deps',
      );
      expect(deps.medicines, 1);
      expect(deps.hasDependencies, isTrue);

      // Deleting consultation with active dependencies must throw ResourceHasDependenciesException
      await expectLater(
        consultationRepo.deleteConsultation(
          testProfile.profileId,
          'consultation_with_deps',
        ),
        throwsA(isA<ResourceHasDependenciesException>()),
      );

      // Delete the medicine dependency first
      await hiveService.userBox.delete('medicine_amlodipine_1');

      final depsAfter = await consultationRepo.getConsultationDependencies(
        testProfile.profileId,
        'consultation_with_deps',
      );
      expect(depsAfter.hasDependencies, isFalse);

      // Deletion now succeeds
      await consultationRepo.deleteConsultation(
        testProfile.profileId,
        'consultation_with_deps',
      );
      final afterDelete = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'consultation_with_deps',
      );
      expect(afterDelete, isNull);
    });

    test('7. Consultation attachments persist metadata and local files', () async {
      final testAttachmentFile = File('${tempDir.path}/prescription_photo.jpg');
      await testAttachmentFile.writeAsString('mock photo bytes');

      final attachment = ConsultationAttachment(
        id: 'att_rx_1',
        name: 'prescription_photo.jpg',
        sizeKB: 120,
        filePath: testAttachmentFile.path,
        fileType: 'image/jpeg',
      );

      final consultation = ConsultationModel(
        id: 'con_with_rx_att',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Chris Taub',
        visitDate: DateTime.now(),
        chiefComplaint: 'Sprained Ankle',
        diagnosis: 'Ligament Sprain',
        attachments: [attachment],
        createdAt: DateTime.now(),
      );

      await consultationRepo.saveConsultationModel(testProfile.profileId, consultation);

      final retrieved = await consultationRepo.getConsultationById(
        testProfile.profileId,
        'con_with_rx_att',
      );
      expect(retrieved, isNotNull);
      expect(retrieved!.attachments.length, 1);
      expect(retrieved.attachments.first.name, 'prescription_photo.jpg');
      expect(retrieved.attachments.first.filePath, testAttachmentFile.path);

      // Resolving attachment file returns the local file
      final resolvedFile = await consultationRepo.getOrDownloadAttachmentFile(
        profileId: testProfile.profileId,
        consultationId: retrieved.id,
        attachment: retrieved.attachments.first,
        customBaseDirectory: tempDir,
      );
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.existsSync(), isTrue);
    });

    test('8. consultationMedicinesProvider and consultationReportsProvider resolve linked records across prefix variants', () async {
      final consultation = ConsultationModel(
        id: 'con_prefix_test',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Remy Hadley',
        visitDate: DateTime.now(),
        chiefComplaint: 'Tremors',
        diagnosis: 'Huntingtons Follow-up',
        createdAt: DateTime.now(),
      );
      await consultationRepo.saveConsultationModel(testProfile.profileId, consultation);

      // Pre-seed a medicine linked via 'con_prefix_test'
      final medicine = MedicineModel(
        id: 'med_tetrabenazine',
        profileId: testProfile.profileId,
        medicineName: 'Tetrabenazine',
        dosage: '25mg',
        form: 'Tablet',
        frequency: 'Twice daily',
        startDate: DateTime.now(),
        linkedConsultationId: 'con_prefix_test',
        createdAt: DateTime.now(),
      );
      await hiveService.userBox.put('medicine_tetrabenazine', medicine.toJson());

      // Pre-seed a report linked via 'consultation_prefix_test'
      final report = ReportModel(
        id: 'rep_genetic_panel',
        profileId: testProfile.profileId,
        title: 'Genetic Marker Panel',
        category: 'LAB TEST',
        date: DateTime.now(),
        consultationId: 'consultation_prefix_test',
      );
      await hiveService.userBox.put('report_genetic_panel', report.toJson());

      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(testProfile)),
          consultationRepositoryProvider.overrideWithValue(consultationRepo),
          medicineRepositoryProvider.overrideWithValue(MedicineRepository(hiveService: hiveService)),
          reportRepositoryProvider.overrideWithValue(ReportRepository(hiveService: hiveService)),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      // Query medicines for 'consultation_prefix_test'
      final medicines = await container.read(
        consultationMedicinesProvider('consultation_prefix_test').future,
      );
      expect(medicines.length, 1);
      expect(medicines.first.medicineName, 'Tetrabenazine');

      // Query reports for 'consultation_prefix_test'
      final reports = await container.read(
        consultationReportsProvider('consultation_prefix_test').future,
      );
      expect(reports.length, 1);
      expect(reports.first.title, 'Genetic Marker Panel');
    });

    test('9. Repeated saves/retries do not create duplicate records in Hive', () async {
      final consultation = ConsultationModel(
        id: 'con_retry_idempotent',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Lawrence Kutner',
        visitDate: DateTime.now(),
        chiefComplaint: 'Cardiac Arrhythmia',
        diagnosis: 'Premature Ventricular Contractions',
        createdAt: DateTime.now(),
      );

      // Save 3 times in succession
      await consultationRepo.saveConsultationModel(testProfile.profileId, consultation);
      await consultationRepo.saveConsultationModel(testProfile.profileId, consultation);
      await consultationRepo.saveConsultationModel(testProfile.profileId, consultation);

      final models = await consultationRepo.getConsultationModels(testProfile.profileId);
      final count = models.where((c) => IdUtils.unprefix(c.id) == 'retry_idempotent').length;
      expect(count, 1);
    });
  });
}
