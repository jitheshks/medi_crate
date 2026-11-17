import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';
import 'package:medi_crate/features/appointments/data/repositories/appointment_repository.dart';
import 'package:medi_crate/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
import 'package:medi_crate/features/consultations/presentation/screens/new_consultation_screen.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  _FakeActiveProfileNotifier(this._profile);
  final ProfileModel? _profile;

  @override
  ProfileModel? build() => _profile;
}

class _FakeConsultationRepository extends ConsultationRepository {
  _FakeConsultationRepository({required super.hiveService});

  ConsultationModel? savedConsultation;
  final Map<String, ConsultationModel> storedConsultations = {};

  @override
  Future<ConsultationModel?> getConsultationById(
    String profileId,
    String consultationId,
  ) async {
    return storedConsultations[consultationId];
  }

  @override
  Future<ConsultationModel> saveConsultationModel(
    String profileId,
    ConsultationModel consultation,
  ) async {
    savedConsultation = consultation;
    storedConsultations[consultation.id] = consultation;
    return consultation;
  }
}

class _FakeAppointmentRepository extends AppointmentRepository {
  _FakeAppointmentRepository({required super.hiveService});

  final Map<String, AppointmentModel> storedAppointments = {};

  @override
  Future<List<AppointmentModel>> getAppointmentModels(
    String profileId, {
    String? status,
    int? doctorId,
    int? hospitalId,
    String? from,
    String? to,
    String? sort,
    int limit = 20,
  }) async {
    return storedAppointments.values
        .where((a) => a.profileId == profileId)
        .toList();
  }

  @override
  Future<AppointmentModel?> getAppointmentById(
    String profileId,
    String id,
  ) async {
    return storedAppointments[id];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeConsultationRepository fakeConsultationRepo;
  late _FakeAppointmentRepository fakeAppointmentRepo;

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
    tempDir = await Directory.systemTemp.createTemp('consultation_date_val_');
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
    fakeConsultationRepo = _FakeConsultationRepository(
      hiveService: hiveService,
    );
    fakeAppointmentRepo = _FakeAppointmentRepository(hiveService: hiveService);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    '1. Today visit date is accepted during saveConsultationRecord',
    () async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(
            fakeConsultationRepo,
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      final today = DateTime.now();

      await saveConsultationRecordContainer(
        container: container,
        doctorName: 'Dr. Gregory House',
        chiefComplaint: 'Knee Pain',
        diagnosis: 'Tendonitis',
        visitDate: today,
        isFollowUpRequired: false,
      );

      expect(fakeConsultationRepo.savedConsultation, isNotNull);
      expect(
        fakeConsultationRepo.savedConsultation?.doctorName,
        'Dr. Gregory House',
      );
      expect(
        fakeConsultationRepo.savedConsultation?.visitDate.year,
        today.year,
      );
      expect(
        fakeConsultationRepo.savedConsultation?.visitDate.month,
        today.month,
      );
      expect(fakeConsultationRepo.savedConsultation?.visitDate.day, today.day);
    },
  );

  test(
    '2. A past visit date is accepted during saveConsultationRecord',
    () async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(
            fakeConsultationRepo,
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      final pastDate = DateTime.now().subtract(const Duration(days: 14));

      await saveConsultationRecordContainer(
        container: container,
        doctorName: 'Dr. Lisa Cuddy',
        chiefComplaint: 'Follow-up Checkup',
        diagnosis: 'Routine follow-up',
        visitDate: pastDate,
        isFollowUpRequired: false,
      );

      expect(fakeConsultationRepo.savedConsultation, isNotNull);
      expect(
        fakeConsultationRepo.savedConsultation?.doctorName,
        'Dr. Lisa Cuddy',
      );
      expect(
        fakeConsultationRepo.savedConsultation?.visitDate.day,
        pastDate.day,
      );
    },
  );

  test(
    '3. A future visit date is rejected by saveConsultationRecord with ValidationException',
    () async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(
            fakeConsultationRepo,
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      final futureDate = DateTime.now().add(const Duration(days: 5));

      expect(
        () => saveConsultationRecordContainer(
          container: container,
          doctorName: 'Dr. Eric Foreman',
          chiefComplaint: 'Future Checkup',
          diagnosis: 'Pending',
          visitDate: futureDate,
          isFollowUpRequired: false,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(fakeConsultationRepo.savedConsultation, isNull);
    },
  );

  testWidgets(
    '3b. A future visit date is rejected during form submission UI flow',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(
            fakeConsultationRepo,
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: NewConsultationScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in required form fields
      container.read(selectedDoctorProvider.notifier).state =
          'Dr. Allison Cameron';
      final complaintFinder = find.byType(TextFormField).at(0);
      await tester.enterText(complaintFinder, 'Fever');
      final diagnosisFinder = find.byType(TextFormField).at(1);
      await tester.enterText(diagnosisFinder, 'Viral Infection');

      // Force future visit date into provider
      container.read(visitDateProvider.notifier).state = DateTime.now().add(
        const Duration(days: 7),
      );
      await tester.pump();

      // Tap Save
      final saveButtonFinder = find.widgetWithText(
        ElevatedButton,
        'SAVE CONSULTATION',
      );
      await tester.tap(saveButtonFinder);
      await tester.pump();

      // Verify rejection snackbar appears and record is not saved
      expect(
        find.text('Consultation visit date cannot be in the future'),
        findsOneWidget,
      );
      expect(fakeConsultationRepo.savedConsultation, isNull);
    },
  );

  test('4. Future appointment dates remain allowed and can be linked', () async {
    final futureAppDate = DateTime.now().add(const Duration(days: 10));
    final futureAppointment = AppointmentModel(
      id: 'app_future_1',
      profileId: testProfile.profileId,
      title: 'Follow-up appointment',
      doctorName: 'Dr. James Wilson',
      department: 'Oncology',
      hospitalName: 'Princeton Plainsboro',
      date: futureAppDate,
      status: 'scheduled',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    fakeAppointmentRepo.storedAppointments[futureAppointment.id] =
        futureAppointment;

    expect(futureAppointment.date.isAfter(DateTime.now()), isTrue);

    final container = ProviderContainer(
      overrides: [
        activeProfileProvider.overrideWith(
          () => _FakeActiveProfileNotifier(testProfile),
        ),
        consultationRepositoryProvider.overrideWithValue(fakeConsultationRepo),
        appointmentRepositoryProvider.overrideWithValue(fakeAppointmentRepo),
        hiveServiceProvider.overrideWithValue(hiveService),
      ],
    );
    addTearDown(container.dispose);

    // Save consultation with valid past/today visitDate while linking future appointment
    await saveConsultationRecordContainer(
      container: container,
      doctorName: futureAppointment.doctorName,
      chiefComplaint: 'Pre-op assessment',
      diagnosis: 'General review',
      visitDate: DateTime.now(),
      appointmentId: futureAppointment.id,
      isFollowUpRequired: false,
    );

    expect(fakeConsultationRepo.savedConsultation, isNotNull);
    expect(
      fakeConsultationRepo.savedConsultation?.appointmentId,
      'app_future_1',
    );
  });

  test(
    '5. Future follow-up dates remain allowed in consultation records',
    () async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(
            fakeConsultationRepo,
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      final futureFollowUp = DateTime.now().add(const Duration(days: 30));

      await saveConsultationRecordContainer(
        container: container,
        doctorName: 'Dr. Robert Chase',
        chiefComplaint: 'Post-op recovery check',
        diagnosis: 'Healing well',
        visitDate: DateTime.now(),
        isFollowUpRequired: true,
        followUpDate: futureFollowUp,
        followUpTime: const TimeOfDay(hour: 14, minute: 0),
      );

      expect(fakeConsultationRepo.savedConsultation, isNotNull);
      expect(
        fakeConsultationRepo.savedConsultation?.isFollowUpRequired,
        isTrue,
      );
      expect(
        fakeConsultationRepo.savedConsultation?.followUpDate?.year,
        futureFollowUp.year,
      );
      expect(
        fakeConsultationRepo.savedConsultation?.followUpDate?.month,
        futureFollowUp.month,
      );
      expect(
        fakeConsultationRepo.savedConsultation?.followUpDate?.day,
        futureFollowUp.day,
      );
    },
  );

  testWidgets('6. Existing edit-mode data is preserved without modification', (
    tester,
  ) async {
    final existingVisitDate = DateTime(2025, 6, 15, 10, 30);
    final existingConsultation = ConsultationModel(
      id: 'con_existing_1',
      profileId: testProfile.profileId,
      doctorName: 'Dr. Chris Taub',
      hospitalName: 'Community Hospital',
      visitDate: existingVisitDate,
      visitTime: '10:30 AM',
      chiefComplaint: 'Chronic Fatigue',
      diagnosis: 'Vitamin D Deficiency',
      clinicalNotes: 'Prescribed supplements',
      createdAt: existingVisitDate,
    );
    fakeConsultationRepo.storedConsultations[existingConsultation.id] =
        existingConsultation;

    final container = ProviderContainer(
      overrides: [
        activeProfileProvider.overrideWith(
          () => _FakeActiveProfileNotifier(testProfile),
        ),
        consultationRepositoryProvider.overrideWithValue(fakeConsultationRepo),
        hiveServiceProvider.overrideWithValue(hiveService),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: NewConsultationScreen(
              consultationIdToEdit: 'con_existing_1',
              initialConsultation: existingConsultation,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify fields populated from existing saved consultation
    expect(find.text('Chronic Fatigue'), findsOneWidget);
    expect(find.text('Vitamin D Deficiency'), findsOneWidget);
    expect(container.read(selectedDoctorProvider), 'Dr. Chris Taub');
    expect(container.read(visitDateProvider), existingVisitDate);

    // Tap Save without changing date
    final saveButtonFinder = find.widgetWithText(
      ElevatedButton,
      'UPDATE CONSULTATION',
    );
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    // Verify saved data matches original record
    expect(fakeConsultationRepo.savedConsultation, isNotNull);
    expect(fakeConsultationRepo.savedConsultation?.id, 'con_existing_1');
    expect(
      fakeConsultationRepo.savedConsultation?.visitDate,
      existingVisitDate,
    );
    expect(
      fakeConsultationRepo.savedConsultation?.chiefComplaint,
      'Chronic Fatigue',
    );
  });
}
