import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_attachment.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/consultations/presentation/providers/consultation_providers.dart';
import 'package:medi_crate/features/consultations/presentation/screens/new_consultation_screen.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/settings/presentation/providers/settings_providers.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeConsultationRepository fakeRepo;

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
    tempDir = await Directory.systemTemp.createTemp('consultation_lifecycle_');
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
    fakeRepo = _FakeConsultationRepository(hiveService: hiveService);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'resetConsultationForm resets all form-scoped state without touching shared state',
    () {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          appCurrencyProvider.overrideWith((ref) => 'EUR'),
        ],
      );

      // Dirty the consultation form providers
      container.read(selectedDoctorProvider.notifier).state =
          'Dr. Gregory House';
      container.read(selectedDoctorIdProvider.notifier).state = 'doc_42';
      container.read(selectedDoctorSpecialtyProvider.notifier).state =
          'Diagnostics';
      container.read(selectedHospitalProvider.notifier).state =
          'Princeton-Plainsboro';
      container.read(selectedHospitalIdProvider.notifier).state = 'hosp_99';
      container.read(selectedDepartmentProvider.notifier).state = 'Nephrology';
      container.read(selectedDepartmentIdProvider.notifier).state = 'dept_5';
      container.read(selectedAppointmentIdProvider.notifier).state = 'app_10';
      container.read(visitDateProvider.notifier).state = DateTime(2025, 1, 15);
      container.read(visitTimeProvider.notifier).state = const TimeOfDay(
        hour: 14,
        minute: 30,
      );
      container.read(isFollowUpEnabledProvider.notifier).state = true;
      container.read(followUpDateProvider.notifier).state = DateTime(
        2025,
        2,
        1,
      );
      container.read(followUpTimeProvider.notifier).state = const TimeOfDay(
        hour: 10,
        minute: 0,
      );
      container.read(followUpReminderProvider.notifier).state = false;
      container.read(selectedCurrencyProvider.notifier).state = 'USD';
      container.read(consultationAttachmentsProvider.notifier).state = const [
        ConsultationAttachment(
          id: 'att_1',
          name: 'scan.pdf',
          fileType: 'application/pdf',
          sizeKB: 120,
        ),
      ];

      // Assert form state is dirtied
      expect(container.read(selectedDoctorProvider), 'Dr. Gregory House');
      expect(container.read(selectedHospitalProvider), 'Princeton-Plainsboro');
      expect(container.read(isFollowUpEnabledProvider), isTrue);
      expect(container.read(consultationAttachmentsProvider), hasLength(1));

      // Reset
      resetConsultationFormContainer(container);

      // Verify all form providers returned to pristine defaults
      expect(container.read(selectedDoctorProvider), isNull);
      expect(container.read(selectedDoctorIdProvider), isNull);
      expect(container.read(selectedDoctorSpecialtyProvider), isNull);
      expect(container.read(selectedHospitalProvider), isNull);
      expect(container.read(selectedHospitalIdProvider), isNull);
      expect(container.read(selectedDepartmentProvider), isNull);
      expect(container.read(selectedDepartmentIdProvider), isNull);
      expect(container.read(selectedAppointmentIdProvider), isNull);
      expect(container.read(isFollowUpEnabledProvider), isFalse);
      expect(container.read(followUpDateProvider), isNull);
      expect(container.read(followUpTimeProvider), isNull);
      expect(container.read(followUpReminderProvider), isTrue);
      expect(container.read(selectedCurrencyProvider), isNull);
      expect(container.read(consultationAttachmentsProvider), isEmpty);

      // Verify shared app state was NOT cleared
      expect(container.read(activeProfileProvider)?.profileId, 'prof_test_1');
      expect(container.read(appCurrencyProvider), 'EUR');
    },
  );

  testWidgets(
    'Leaving a new consultation form without saving clears unsaved values upon Back/dispose',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(fakeRepo),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NewConsultationScreen(),
                      ),
                    );
                  },
                  child: const Text('Open New Consultation'),
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Open new consultation form
      await tester.tap(find.text('Open New Consultation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NewConsultationScreen), findsOneWidget);

      // 2. Set some values in Riverpod providers & text controllers
      container.read(selectedDoctorProvider.notifier).state =
          'Dr. Robert Chase';
      container.read(selectedHospitalProvider.notifier).state =
          'Mercy Hospital';
      container.read(isFollowUpEnabledProvider.notifier).state = true;
      container.read(consultationAttachmentsProvider.notifier).state = const [
        ConsultationAttachment(
          id: 'att_2',
          name: 'xray.jpg',
          fileType: 'image/jpeg',
          sizeKB: 250,
        ),
      ];

      final complaintFinder = find.byType(TextFormField).at(0);
      await tester.enterText(complaintFinder, 'Severe migraine');
      await tester.pump();

      expect(container.read(selectedDoctorProvider), 'Dr. Robert Chase');
      expect(container.read(selectedHospitalProvider), 'Mercy Hospital');
      expect(container.read(consultationAttachmentsProvider), hasLength(1));

      // 3. User taps Back button in AppBar without saving
      final backButtonFinder = find.byTooltip('Back');
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      // Form screen is popped and disposed
      expect(find.byType(NewConsultationScreen), findsNothing);

      // Verify all form-scoped Riverpod providers were reset on dispose
      expect(container.read(selectedDoctorProvider), isNull);
      expect(container.read(selectedHospitalProvider), isNull);
      expect(container.read(isFollowUpEnabledProvider), isFalse);
      expect(container.read(consultationAttachmentsProvider), isEmpty);
    },
  );

  testWidgets(
    'Reopening a new form starts clean with blank controllers and default values',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(fakeRepo),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NewConsultationScreen(),
                      ),
                    );
                  },
                  child: const Text('Open New Consultation'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open first time
      await tester.tap(find.text('Open New Consultation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in values
      container.read(selectedDoctorProvider.notifier).state =
          'Dr. Allison Cameron';
      final complaintFinder = find.byType(TextFormField).at(0);
      await tester.enterText(complaintFinder, 'Fever');
      await tester.pump();

      // Press Back
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Reopen second time
      await tester.tap(find.text('Open New Consultation'));
      await tester.pumpAndSettle();

      expect(find.byType(NewConsultationScreen), findsOneWidget);

      // Chief complaint controller must be empty
      final textField = tester.widget<TextFormField>(complaintFinder);
      expect(textField.controller?.text, isEmpty);

      // Providers must be clean
      expect(container.read(selectedDoctorProvider), isNull);
      expect(container.read(selectedHospitalProvider), isNull);
      expect(container.read(consultationAttachmentsProvider), isEmpty);
    },
  );

  testWidgets(
    'Editing an existing consultation loads and preserves its saved values',
    (tester) async {
      final existingConsultation = ConsultationModel(
        id: 'consultation_existing_99',
        profileId: testProfile.profileId,
        doctorName: 'Dr. James Wilson',
        doctorSpecialty: 'Oncology',
        hospitalName: 'General Hospital',
        visitDate: DateTime(2025, 3, 10, 11, 0),
        visitTime: '11:00',
        chiefComplaint: 'Routine checkup',
        diagnosis: 'All clear',
        clinicalNotes: 'Patient is healthy',
        isFollowUpRequired: true,
        followUpDate: DateTime(2025, 6, 10),
        tags: const ['routine', 'checkup'],
        consultationFee: 150.0,
        currency: 'USD',
        attachments: const [
          ConsultationAttachment(
            id: 'att_saved',
            name: 'blood_test.pdf',
            fileType: 'application/pdf',
            sizeKB: 80,
          ),
        ],
        createdAt: DateTime.now(),
      );

      fakeRepo.storedConsultations['consultation_existing_99'] =
          existingConsultation;

      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(fakeRepo),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: NewConsultationScreen(
              initialConsultation: existingConsultation,
              consultationIdToEdit: 'consultation_existing_99',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title indicates Edit mode
      expect(find.text('Edit Consultation'), findsOneWidget);

      // Verify text controllers populated from existing record
      final complaintFinder = find.byType(TextFormField).at(0);
      final complaintField = tester.widget<TextFormField>(complaintFinder);
      expect(complaintField.controller?.text, 'Routine checkup');

      final diagnosisFinder = find.byType(TextFormField).at(1);
      final diagnosisField = tester.widget<TextFormField>(diagnosisFinder);
      expect(diagnosisField.controller?.text, 'All clear');

      // Verify providers populated from existing record
      expect(container.read(selectedDoctorProvider), 'Dr. James Wilson');
      expect(container.read(selectedHospitalProvider), 'General Hospital');
      expect(container.read(isFollowUpEnabledProvider), isTrue);
      expect(container.read(consultationAttachmentsProvider), hasLength(1));
      expect(
        container.read(consultationAttachmentsProvider).first.name,
        'blood_test.pdf',
      );
    },
  );

  testWidgets(
    'Saving a consultation preserves the saved record and resets form state',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(fakeRepo),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NewConsultationScreen(),
                      ),
                    );
                  },
                  child: const Text('Open New Consultation'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open consultation screen
      await tester.tap(find.text('Open New Consultation'));
      await tester.pumpAndSettle();

      // Fill in required form fields
      container.read(selectedDoctorProvider.notifier).state =
          'Dr. Eric Foreman';
      final complaintFinder = find.byType(TextFormField).at(0);
      await tester.enterText(complaintFinder, 'Headache');

      final diagnosisFinder = find.byType(TextFormField).at(1);
      await tester.enterText(diagnosisFinder, 'Tension headache');
      await tester.pump();

      // Trigger save
      final saveButtonFinder = find.widgetWithText(
        ElevatedButton,
        'SAVE CONSULTATION',
      );
      expect(saveButtonFinder, findsOneWidget);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify repository received and saved the consultation
      expect(fakeRepo.savedConsultation, isNotNull);
      expect(fakeRepo.savedConsultation?.doctorName, 'Dr. Eric Foreman');
      expect(fakeRepo.savedConsultation?.chiefComplaint, 'Headache');
      expect(fakeRepo.savedConsultation?.diagnosis, 'Tension headache');

      // Verify form state was reset after save
      expect(container.read(selectedDoctorProvider), isNull);
      expect(container.read(selectedHospitalProvider), isNull);
      expect(container.read(consultationAttachmentsProvider), isEmpty);
    },
  );

  testWidgets(
    'Navigating away and immediately opening a new form starts clean and preserves new entries',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            () => _FakeActiveProfileNotifier(testProfile),
          ),
          consultationRepositoryProvider.overrideWithValue(fakeRepo),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );

      late BuildContext hostContext;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                hostContext = ctx;
                return const Scaffold(body: Text('Host Screen'));
              },
            ),
          ),
        ),
      );

      // 1. Open Form 1 and enter temporary values
      Navigator.of(
        hostContext,
      ).push(MaterialPageRoute(builder: (_) => const NewConsultationScreen()));
      await tester.pumpAndSettle();

      container.read(selectedDoctorProvider.notifier).state = 'Dr. OldForm';
      final oldComplaintFinder = find.byType(TextFormField).at(0);
      await tester.enterText(oldComplaintFinder, 'Old Complaint');
      await tester.pump();
      expect(container.read(selectedDoctorProvider), 'Dr. OldForm');

      // 2. Navigate away from Form 1 and immediately push Form 2 in the same turn
      Navigator.of(hostContext).pop();
      Navigator.of(
        hostContext,
      ).push(MaterialPageRoute(builder: (_) => const NewConsultationScreen()));
      await tester.pumpAndSettle();

      // Form 2 is now mounted and settled: verify it started clean
      expect(container.read(selectedDoctorProvider), isNull);
      final newComplaintFinder = find.byType(TextFormField).at(0);
      final initialField = tester.widget<TextFormField>(newComplaintFinder);
      expect(initialField.controller?.text, isEmpty);

      // 3. Enter values into Form 2
      container.read(selectedDoctorProvider.notifier).state = 'Dr. NewForm';
      await tester.enterText(newComplaintFinder, 'New Complaint');
      await tester.pump();

      // 4. Confirm Form 2 values are intact and were not cleared
      expect(container.read(selectedDoctorProvider), 'Dr. NewForm');
      final finalField = tester.widget<TextFormField>(newComplaintFinder);
      expect(finalField.controller?.text, 'New Complaint');
    },
  );
}
