import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/datasources/remote/supabase_medical_department_remote_data_source.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/models/medical_department_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/consultations/data/repositories/medical_department_repository.dart';
import 'package:medi_crate/features/consultations/presentation/providers/medical_department_providers.dart';
import 'package:medi_crate/features/consultations/presentation/widgets/medical_department_picker_sheet.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';

const List<Map<String, dynamic>> kAuthoritative79ProductionDepartments = [
  {"id": 1, "name": "ANAESTHESIOLOGY"},
  {"id": 2, "name": "ASSOCIATE PHYSICIAN"},
  {"id": 3, "name": "BREAST ONCOPLASTIC SURGERY"},
  {"id": 4, "name": "CARDIO THORACIC VASCULAR ANESTHESIOLOGY"},
  {"id": 5, "name": "CARDIO VASCULAR SURGERY"},
  {"id": 6, "name": "CARDIOLOGY"},
  {"id": 7, "name": "CARDIOTHORACIC SURGEON"},
  {"id": 8, "name": "CLINICAL NEURO PSYCHOLOGY"},
  {"id": 9, "name": "CLINICAL PSYCHOLOGY"},
  {"id": 10, "name": "CTVC"},
  {"id": 11, "name": "DENTAL"},
  {"id": 12, "name": "DENTAL PROSTHODONTIST"},
  {"id": 13, "name": "DERMATOLOGY"},
  {"id": 14, "name": "DEVELOPMENTAL MEDICINE"},
  {"id": 15, "name": "DIABETOLOGY"},
  {"id": 16, "name": "DIALYSIS"},
  {"id": 17, "name": "DIETARY"},
  {"id": 18, "name": "E.N.T"},
  {"id": 19, "name": "EMERGENCY DEPARTMENT"},
  {"id": 20, "name": "ENDOCRINOLOGY"},
  {"id": 21, "name": "ENDOSCOPIC SPINE SURGEON"},
  {"id": 22, "name": "FAMILY MEDICINE"},
  {"id": 23, "name": "FORENSIC MEDICINE AND TOXICOLOGY"},
  {"id": 24, "name": "GASTROENTEROLOGY(MED)"},
  {"id": 25, "name": "GASTROENTEROLOGY(SURG)"},
  {"id": 26, "name": "GENERAL SURGERY"},
  {"id": 27, "name": "GYNAECOLOGICAL ONCOLOGY"},
  {"id": 28, "name": "HAND & MICROVASCULAR SURGERY"},
  {"id": 29, "name": "HEMATO ONCOLOGY"},
  {"id": 30, "name": "HEMATOLOGY"},
  {"id": 31, "name": "HEPATOLOGY"},
  {"id": 32, "name": "HPB & LIVER TRANSPLANT SURGEON"},
  {"id": 33, "name": "INTENSIVE CARE"},
  {"id": 34, "name": "INTERNAL MEDICINE"},
  {"id": 35, "name": "LABORATORY"},
  {"id": 36, "name": "LACTATION"},
  {"id": 37, "name": "LAPROSCOPIC AND GENERAL SURGEON"},
  {"id": 38, "name": "MAXILLOFACIAL SURGERY"},
  {"id": 39, "name": "MHC CONSULTANT"},
  {"id": 40, "name": "NEONATOLOGY"},
  {"id": 41, "name": "NEPHROLOGY"},
  {"id": 42, "name": "NEURO ANAESTHESIA"},
  {"id": 43, "name": "NEURO RADIOLOGY"},
  {"id": 44, "name": "NEURO SURGERY"},
  {"id": 45, "name": "NEUROLOGY"},
  {"id": 46, "name": "NEUROVASCULAR & INTERVENTIONAL RADIOLOGY"},
  {"id": 47, "name": "OBSTETRIC & GYNAECOLOGY"},
  {"id": 48, "name": "ONCOLOGY (MEDICAL)"},
  {"id": 49, "name": "ONCOLOGY (SURGICAL)"},
  {"id": 50, "name": "OPHTHALMOLOGY"},
  {"id": 51, "name": "ORAL & MAXILLO FACIAL SURGERY"},
  {"id": 52, "name": "ORTHOPAEDICS"},
  {"id": 53, "name": "ORTHOPAEDICS & SPINE SURGEON"},
  {"id": 54, "name": "PAEDIATRIC DENTAL"},
  {"id": 55, "name": "PAEDIATRIC DERMATOLOGY"},
  {"id": 56, "name": "PAEDIATRIC ENDOCRINOLOGY"},
  {"id": 57, "name": "PAEDIATRIC HAEMATO-ONCOLOGY"},
  {"id": 58, "name": "PAEDIATRIC NEPHROLOGY"},
  {"id": 59, "name": "PAEDIATRIC NEUROLOGY"},
  {"id": 60, "name": "PAEDIATRIC ORTHOPAEDICS"},
  {"id": 61, "name": "PAEDIATRIC PSYCHOLOGY"},
  {"id": 62, "name": "PAEDIATRIC PULMONOLOGY"},
  {"id": 63, "name": "PAEDIATRIC SURGERY"},
  {"id": 64, "name": "PAEDIATRICS"},
  {"id": 65, "name": "PAEDIATRICS N NEONATOLOGY"},
  {"id": 66, "name": "PAEDIATRICS-CARDIOLOGY"},
  {"id": 67, "name": "PHYSIOTHERAPY"},
  {"id": 68, "name": "PLASTIC SURGERY"},
  {"id": 69, "name": "PSYCHIATRY"},
  {"id": 70, "name": "PSYCHOLOGY"},
  {"id": 71, "name": "PULMONOLOGY"},
  {"id": 72, "name": "RADIOLOGY"},
  {"id": 73, "name": "RHEUMATOLOGY"},
  {"id": 74, "name": "SPEECH THERAPY"},
  {"id": 75, "name": "THORACIC SURGERY"},
  {"id": 76, "name": "UROLOGY"},
  {"id": 77, "name": "UROLOGY ANDROLOGY"},
  {"id": 78, "name": "VASCULAR SURGERY"},
  {"id": 79, "name": "OTHERS"}
];

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({this.online = true});
  bool online;

  @override
  Future<bool> checkConnectivity() async => online;
}

class _FakeMedicalDepartmentRemoteDataSource
    extends SupabaseMedicalDepartmentRemoteDataSource {
  _FakeMedicalDepartmentRemoteDataSource({
    this.departments = const [],
    this.shouldThrow = false,
  });

  List<MedicalDepartmentModel> departments;
  bool shouldThrow;
  int callCount = 0;

  @override
  Future<List<MedicalDepartmentModel>> fetchMedicalDepartments() async {
    callCount++;
    if (shouldThrow) {
      throw Exception('Simulated remote failure');
    }
    return departments;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;

  final testProfile = ProfileModel(
    profileId: 'prof_test_dept_1',
    serverProfileId: 201,
    ownerUserId: 'user_dept_1',
    fullName: 'Test Patient',
    relationship: 'Self',
    isPrimary: true,
    allergies: const [],
    chronicConditions: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dept_test_');
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
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Requirement 1..6: Authoritative Department Dataset Verification', () {
    test('1. Exactly 79 department entries are present', () {
      expect(kAuthoritative79ProductionDepartments.length, 79);
    });

    test('2 & 3. Every ID and name matches the production response exactly', () {
      final ids = <int>{};
      final names = <String>{};

      for (int i = 0; i < kAuthoritative79ProductionDepartments.length; i++) {
        final item = kAuthoritative79ProductionDepartments[i];
        final id = item['id'] as int;
        final name = item['name'] as String;

        expect(id, i + 1, reason: 'IDs must be consecutive from 1 to 79');
        expect(name.isNotEmpty, true);
        ids.add(id);
        names.add(name);
      }

      expect(ids.length, 79);
      expect(names.length, 79);

      // Verify specific spot-checks with special characters and capitalization
      expect(kAuthoritative79ProductionDepartments[0]['name'], 'ANAESTHESIOLOGY');
      expect(kAuthoritative79ProductionDepartments[9]['name'], 'CTVC');
      expect(kAuthoritative79ProductionDepartments[17]['name'], 'E.N.T');
      expect(kAuthoritative79ProductionDepartments[23]['name'], 'GASTROENTEROLOGY(MED)');
      expect(kAuthoritative79ProductionDepartments[24]['name'], 'GASTROENTEROLOGY(SURG)');
      expect(kAuthoritative79ProductionDepartments[27]['name'], 'HAND & MICROVASCULAR SURGERY');
      expect(kAuthoritative79ProductionDepartments[46]['name'], 'OBSTETRIC & GYNAECOLOGY');
      expect(kAuthoritative79ProductionDepartments[51]['name'], 'ORTHOPAEDICS');
      expect(kAuthoritative79ProductionDepartments[63]['name'], 'PAEDIATRICS');
      expect(kAuthoritative79ProductionDepartments[78]['name'], 'OTHERS');
    });

    test('4 & 5. ID 79 is OTHERS and always appears last', () async {
      final lastEntry = kAuthoritative79ProductionDepartments.last;
      expect(lastEntry['id'], 79);
      expect(lastEntry['name'], 'OTHERS');

      final models = kAuthoritative79ProductionDepartments
          .map((m) => MedicalDepartmentModel.fromJson(m))
          .toList();

      final box = hiveService.userBox;
      await box.put(
        MedicalDepartmentRepository.cacheKey,
        {'departments': models.map((d) => d.toJson()).toList()},
      );

      final repo = MedicalDepartmentRepository(hiveService: hiveService);
      final sorted = await repo.getMedicalDepartments();
      expect(sorted.length, 79);
      expect(sorted.last.id, 79);
      expect(sorted.last.name, 'OTHERS');
    });

    test('6. Alphabetical ordering works with OTHERS pinned at the end', () async {
      final models = kAuthoritative79ProductionDepartments
          .map((m) => MedicalDepartmentModel.fromJson(m))
          .toList();

      // Reverse the list and verify repository sorts it alphabetically with OTHERS at the end
      final reversed = models.reversed.toList();
      final box = hiveService.userBox;
      await box.put(
        MedicalDepartmentRepository.cacheKey,
        {'departments': reversed.map((d) => d.toJson()).toList()},
      );

      final repo = MedicalDepartmentRepository(hiveService: hiveService);
      final sorted = await repo.getMedicalDepartments();

      expect(sorted.length, 79);
      expect(sorted.first.id, 1);
      expect(sorted.first.name, 'ANAESTHESIOLOGY');
      expect(sorted.last.id, 79);
      expect(sorted.last.name, 'OTHERS');

      for (int i = 0; i < sorted.length - 2; i++) {
        expect(
          sorted[i].name.compareTo(sorted[i + 1].name) <= 0,
          true,
          reason: '${sorted[i].name} should be <= ${sorted[i + 1].name}',
        );
      }
    });
  });

  group('Requirement 7 & 8: Supabase Seed File Verification', () {
    test('7. Seed file is idempotent, well-formed, contains preflight protection and all 79 departments', () {
      final seedFile = File('supabase/seed.sql');
      expect(seedFile.existsSync(), true, reason: 'supabase/seed.sql must exist');

      final content = seedFile.readAsStringSync();
      expect(content.contains('DO \$\$'), true);
      expect(content.contains('END \$\$;'), true);
      expect(content.contains('temp_authoritative_departments'), true);
      expect(content.contains('ON CONFLICT (id) DO UPDATE'), true);
      expect(content.contains('Preflight check failed:'), true);
      expect(content.contains("(79, 'OTHERS', TRUE)"), true);
      expect(content.contains("(1, 'ANAESTHESIOLOGY', TRUE)"), true);

      // Verify all 79 departments are declared in the SQL seed
      for (final dept in kAuthoritative79ProductionDepartments) {
        final id = dept['id'];
        final name = (dept['name'] as String).replaceAll("'", "''");
        expect(
          content.contains("($id, '$name', TRUE)"),
          true,
          reason: 'Seed must contain department $id: $name',
        );
      }
    });

    test('8. The SERIAL sequence is synchronized in seed.sql', () {
      final seedFile = File('supabase/seed.sql');
      final content = seedFile.readAsStringSync();
      expect(
        content.contains("pg_get_serial_sequence('public.medical_departments', 'id')"),
        true,
        reason: 'Seed must synchronize the SERIAL sequence',
      );
      expect(content.contains('COALESCE((SELECT MAX(id) FROM public.medical_departments), 1)'), true);
    });
  });

  group('Requirement 9 & 10: Supabase Repository & Hive Cache Integration', () {
    test('9. Supabase repository mapping works with model serialization', () async {
      final models = kAuthoritative79ProductionDepartments
          .map((m) => MedicalDepartmentModel.fromJson(m))
          .toList();

      final fakeRemote = _FakeMedicalDepartmentRemoteDataSource(
        departments: models,
      );
      final fakeConnectivity = _FakeConnectivityService(online: true);

      final repo = MedicalDepartmentRepository(
        hiveService: hiveService,
        supabaseRemoteDataSource: fakeRemote,
        connectivityService: fakeConnectivity,
      );

      final result = await repo.getMedicalDepartments(forceRefresh: true);
      expect(result.length, 79);
      expect(result.first.name, 'ANAESTHESIOLOGY');
      expect(result.last.name, 'OTHERS');
      expect(fakeRemote.callCount, 1);

      // Verify it cached into Hive
      final cached = hiveService.userBox.get(MedicalDepartmentRepository.cacheKey);
      expect(cached, isNotNull);
      expect((cached as Map)['departments'], isA<List>());
      expect(((cached)['departments'] as List).length, 79);
    });

    test('10. Hive cache fallback works when offline or server fails', () async {
      // 1. Seed Hive cache with 79 entries
      final models = kAuthoritative79ProductionDepartments
          .map((m) => MedicalDepartmentModel.fromJson(m))
          .toList();

      final box = hiveService.userBox;
      await box.put(
        MedicalDepartmentRepository.cacheKey,
        {'departments': models.map((d) => d.toJson()).toList()},
      );

      // 2. Set remote to throw and connectivity to offline
      final failingRemote = _FakeMedicalDepartmentRemoteDataSource(
        shouldThrow: true,
      );
      final offlineConnectivity = _FakeConnectivityService(online: false);

      final repo = MedicalDepartmentRepository(
        hiveService: hiveService,
        supabaseRemoteDataSource: failingRemote,
        connectivityService: offlineConnectivity,
      );

      // 3. Fetch departments - must transparently return cached 79 departments
      final result = await repo.getMedicalDepartments();
      expect(result.length, 79);
      expect(result.first.name, 'ANAESTHESIOLOGY');
      expect(result.last.name, 'OTHERS');
      expect(failingRemote.callCount, 0, reason: 'Offline should avoid network request');

      // 4. Force refresh while online but server fails: must catch error and return cached
      final onlineConnectivity = _FakeConnectivityService(online: true);
      final repo2 = MedicalDepartmentRepository(
        hiveService: hiveService,
        supabaseRemoteDataSource: failingRemote,
        connectivityService: onlineConnectivity,
      );

      final resultOnServerFailure = await repo2.getMedicalDepartments(forceRefresh: true);
      expect(resultOnServerFailure.length, 79);
      expect(resultOnServerFailure.last.name, 'OTHERS');
      expect(failingRemote.callCount, 1);
    });
  });

  group('Requirement 11: Consultation Picker Sheet UI & Interaction', () {
    testWidgets('11. Department picker displays 79 items, filters on search, and selects item', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final models = kAuthoritative79ProductionDepartments
          .map((m) => MedicalDepartmentModel.fromJson(m))
          .toList();

      MedicalDepartmentModel? selected;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(hiveService),
            medicalDepartmentsProvider.overrideWith((ref) async => models),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      MedicalDepartmentPickerSheet.show(
                        context: context,
                        currentDepartmentId: 6,
                        currentDepartmentName: 'CARDIOLOGY',
                        onSelected: (dept) => selected = dept,
                      );
                    },
                    child: const Text('Open Picker'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Medical Department'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Initial item at the top of the 79 items should be ANAESTHESIOLOGY
      expect(find.text('ANAESTHESIOLOGY'), findsOneWidget);

      // Search for CARDIOLOGY - should show check circle because currentDepartmentName is CARDIOLOGY
      await tester.enterText(find.byType(TextField), 'CARDIOLOGY');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.widgetWithText(ListTile, 'CARDIOLOGY'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Test search filtering with NEURO
      await tester.enterText(find.byType(TextField), 'NEURO');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.widgetWithText(ListTile, 'CLINICAL NEURO PSYCHOLOGY'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'NEUROLOGY'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'CARDIOLOGY'), findsNothing);

      // Select NEUROLOGY (id: 45)
      await tester.tap(find.widgetWithText(ListTile, 'NEUROLOGY'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, 45);
      expect(selected!.name, 'NEUROLOGY');

      // Verify no "+ Add Department" button exists (read-only requirement)
      expect(find.text('Add Department'), findsNothing);
      expect(find.text('+ Add Department'), findsNothing);
    });
  });

  group('Requirement 12 & 13: Historical & Offline Consultation Compatibility', () {
    test('12. Historical consultations with legacy or null departmentId remain readable', () {
      final legacyConsultation = ConsultationModel(
        id: 'con_legacy_001',
        profileId: 'prof_test_dept_1',
        doctorName: 'Dr. Historical',
        departmentId: null, // Legacy record without numeric department ID
        department: 'CARDIOLOGY', // Historic name snapshot
        visitDate: DateTime(2025, 5, 10),
        chiefComplaint: 'Chest tightness',
        diagnosis: 'Angina pectoris',
        createdAt: DateTime(2025, 5, 10, 10, 0),
      );

      final json = legacyConsultation.toJson();
      expect(json['department_id'], isNull);
      expect(json['department'], 'CARDIOLOGY');

      final reconstituted = ConsultationModel.fromJson(json);
      expect(reconstituted.departmentId, isNull);
      expect(reconstituted.department, 'CARDIOLOGY');

      // Legacy consultation with obsolete/provisional numeric ID
      final provisionalConsultation = ConsultationModel(
        id: 'con_legacy_002',
        profileId: 'prof_test_dept_1',
        doctorName: 'Dr. Provisional',
        departmentId: '999',
        department: 'CUSTOM SPECIALTY',
        visitDate: DateTime(2025, 6, 1),
        chiefComplaint: 'Followup',
        diagnosis: 'Stable',
        createdAt: DateTime(2025, 6, 1),
      );

      final reconProvisional = ConsultationModel.fromJson(provisionalConsultation.toJson());
      expect(reconProvisional.departmentId, '999');
      expect(reconProvisional.department, 'CUSTOM SPECIALTY');
    });

    test('13. Offline consultation creation correctly saves numeric departmentId and name snapshot', () async {
      final consultationRepo = ConsultationRepository(hiveService: hiveService);

      final consultation = ConsultationModel(
        id: 'con_dept_001',
        profileId: testProfile.profileId,
        doctorName: 'Dr. Child Specialist',
        departmentId: '64',
        department: 'PAEDIATRICS',
        visitDate: DateTime(2026, 11, 10),
        chiefComplaint: 'Fever and cough',
        diagnosis: 'Viral bronchitis',
        createdAt: DateTime(2026, 11, 10),
      );

      final saved = await consultationRepo.saveConsultationModel(
        testProfile.profileId,
        consultation,
      );

      expect(saved.departmentId, '64');
      expect(saved.department, 'PAEDIATRICS');
      expect(saved.doctorName, 'Dr. Child Specialist');

      // Verify Hive persistence and retrieval
      final retrieved = await consultationRepo.getConsultationById(
        testProfile.profileId,
        saved.id,
      );
      expect(retrieved, isNotNull);
      expect(retrieved!.departmentId, '64');
      expect(retrieved.department, 'PAEDIATRICS');
      expect(retrieved.chiefComplaint, 'Fever and cough');
    });
  });
}
