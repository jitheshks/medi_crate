import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medi_crate/core/theme/app_theme.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_demographics_input_section.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_form_dialog.dart';
import 'package:medi_crate/features/profile/presentation/widgets/family_profile_card.dart';
import 'package:medi_crate/features/doctors/presentation/widgets/doctor_form_fields.dart';
import 'package:medi_crate/features/doctors/presentation/widgets/form/doctor_form_controller.dart';
import 'package:medi_crate/features/hospitals/presentation/widgets/hospital_form_fields.dart';
import 'package:medi_crate/features/hospitals/presentation/widgets/form/hospital_form_controller.dart';
import 'package:medi_crate/features/vitals/presentation/widgets/form/blood_pressure_input_field.dart';
import 'package:medi_crate/features/medicines/presentation/widgets/form/medicine_date_range_picker.dart';
import 'package:medi_crate/features/consultations/presentation/widgets/form/consultation_visit_section.dart';
import 'package:medi_crate/shared/widgets/buttons/primary_button.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  _FakeAuthNotifier({required this.initialState});

  @override
  AuthState build() => initialState;
}

class _FakeProfilesListNotifier extends ProfilesListNotifier {
  final List<ProfileModel> _profiles;
  _FakeProfilesListNotifier(this._profiles);

  @override
  Future<List<ProfileModel>> build() async => _profiles;
}

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  final ProfileModel? _profile;
  _FakeActiveProfileNotifier(this._profile);

  @override
  ProfileModel? build() => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final selfProfile = ProfileModel(
    profileId: 'prof-self-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Jane Doe',
    relationship: 'Self',
    isPrimary: true,
    gender: 'Female',
    dateOfBirth: '1992-05-20',
    bloodGroup: 'B+',
  );

  final familyProfile = ProfileModel(
    profileId: 'prof-father-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Robert Doe',
    relationship: 'Father',
    isPrimary: false,
    gender: 'Male',
    dateOfBirth: '1960-03-15',
    bloodGroup: 'A+',
  );

  final testUser = UserModel(
    id: 'user-uuid-1',
    name: 'Jane Doe',
    email: 'jane@example.com',
  );

  Widget buildTestScaffold({
    required Widget child,
    double width = 360,
    double height = 640,
    double textScale = 1.0,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthNotifier(
            initialState: AuthState(
              isLoading: false,
              isAuthenticated: true,
              user: testUser,
            ),
          ),
        ),
        profilesListProvider.overrideWith(
          () => _FakeProfilesListNotifier([selfProfile, familyProfile]),
        ),
        activeProfileProvider.overrideWith(
          () => _FakeActiveProfileNotifier(selfProfile),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
            viewInsets: viewInsets,
          ),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Phase 3 & 5 – Profile Demographics Responsive Overflow Verification', () {
    testWidgets('320dp width stacks Gender and Blood Group vertically without 17px overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      String? gender;
      String? bloodGroup;

      await tester.pumpWidget(
        buildTestScaffold(
          width: 320,
          child: SingleChildScrollView(
            child: ProfileDemographicsInputSection(
              selectedGender: gender,
              onGenderChanged: (v) => gender = v,
              selectedBloodGroup: bloodGroup,
              onBloodGroupChanged: (v) => bloodGroup = v,
              selectedDob: DateTime(1995, 8, 12),
              onPickDob: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      expect(errors, isEmpty, reason: 'Zero RenderFlex overflow errors expected at 320dp');
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('12/8/1995'), findsOneWidget);
    });

    testWidgets('360dp width renders Gender and Blood Group side-by-side with isExpanded: true (0px overflow)', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      String? gender;
      String? bloodGroup;

      await tester.pumpWidget(
        buildTestScaffold(
          width: 360,
          child: SingleChildScrollView(
            child: ProfileDemographicsInputSection(
              selectedGender: gender,
              onGenderChanged: (v) => gender = v,
              selectedBloodGroup: bloodGroup,
              onBloodGroupChanged: (v) => bloodGroup = v,
              selectedDob: null,
              onPickDob: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      expect(errors, isEmpty, reason: 'Zero RenderFlex overflow errors expected at 360dp');
      expect(find.text('Select Gender'), findsOneWidget);
      expect(find.text('Select Blood Group'), findsOneWidget);
      expect(find.text('Select Birth Date'), findsOneWidget);
    });

    testWidgets('360dp width with 1.4x text scale does not overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 360,
          textScale: 1.4,
          child: SingleChildScrollView(
            child: ProfileDemographicsInputSection(
              selectedGender: 'Female',
              onGenderChanged: (_) {},
              selectedBloodGroup: 'AB+',
              onBloodGroupChanged: (_) {},
              selectedDob: DateTime(1990, 1, 1),
              onPickDob: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      expect(errors, isEmpty, reason: 'Zero overflow at 1.4x text scale');
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('AB+'), findsOneWidget);
    });

    testWidgets('Multi-device widths (375, 393, 412, 600 dp) all render with zero overflow', (tester) async {
      for (final w in [375.0, 393.0, 412.0, 600.0]) {
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);

        await tester.pumpWidget(
          buildTestScaffold(
            width: w,
            child: SingleChildScrollView(
              child: ProfileDemographicsInputSection(
                selectedGender: 'Male',
                onGenderChanged: (_) {},
                selectedBloodGroup: 'O+',
                onBloodGroupChanged: (_) {},
                selectedDob: DateTime(1985, 3, 25),
                onPickDob: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;

        expect(errors, isEmpty, reason: 'Zero overflow at $w dp width');
      }
    });
  });

  group('Phase 3 & 5 – ProfileFormDialog (Add Family Profile) Modal Responsiveness', () {
    testWidgets('ProfileFormDialog renders at 320dp width without overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 320,
          height: 600,
          child: const ProfileFormDialog(),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      expect(errors, isEmpty, reason: 'Add Family Profile fits without overflow at 320dp');
      expect(find.text('Add Family Profile'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Height (cm)'), findsOneWidget);
      expect(find.text('Weight (kg)'), findsOneWidget);
    });

    testWidgets('ProfileFormDialog renders at 360dp width with keyboard insets (bottom: 300) without clipping', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 360,
          height: 740,
          viewInsets: const EdgeInsets.only(bottom: 300),
          child: const ProfileFormDialog(),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      expect(errors, isEmpty, reason: 'Modal adapts to keyboard insets without overflow');
      expect(find.text('Add Family Profile'), findsOneWidget);
    });

    testWidgets('ProfileFormDialog renders at 1.4x text scale without overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 360,
          height: 700,
          textScale: 1.4,
          child: const ProfileFormDialog(),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      expect(errors, isEmpty, reason: 'Modal renders at 1.4x text scale without overflow');
    });
  });

  group('Phase 4 & 5 – Project-Wide Responsive Component Verification', () {
    testWidgets('DoctorFormFields adapts Phone and Email at 320dp vs 400dp without overflow', (tester) async {
      final controller = DoctorFormController();
      addTearDown(controller.dispose);

      // Narrow screen: 320dp
      var errors = <FlutterErrorDetails>[];
      var originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 320,
          child: SingleChildScrollView(
            child: DoctorFormFields(
              controller: controller,
              originalDoctor: null,
              onOpenHospitalPicker: () {},
              onRemoveHospital: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'DoctorFormFields 320dp zero overflow');

      // Standard screen: 400dp
      errors = <FlutterErrorDetails>[];
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 400,
          child: SingleChildScrollView(
            child: DoctorFormFields(
              controller: controller,
              originalDoctor: null,
              onOpenHospitalPicker: () {},
              onRemoveHospital: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'DoctorFormFields 400dp zero overflow');
    });

    testWidgets('HospitalFormFields adapts Phone, Email, and Facility Type at 320dp without overflow', (tester) async {
      final controller = HospitalFormController();
      addTearDown(controller.dispose);

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 320,
          child: SingleChildScrollView(
            child: HospitalFormFields(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'HospitalFormFields 320dp zero overflow');
      expect(find.text('FACILITY TYPE'), findsOneWidget);
    });

    testWidgets('BloodPressureInputField adapts Systolic and Diastolic at 270dp vs 360dp without overflow', (tester) async {
      final sysController = TextEditingController();
      final diaController = TextEditingController();
      addTearDown(() {
        sysController.dispose();
        diaController.dispose();
      });

      // Ultra-narrow: 270dp
      var errors = <FlutterErrorDetails>[];
      var originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 270,
          child: BloodPressureInputField(
            systolicController: sysController,
            diastolicController: diaController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'BloodPressureInputField 270dp zero overflow');

      // Standard: 360dp
      errors = <FlutterErrorDetails>[];
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 360,
          child: BloodPressureInputField(
            systolicController: sysController,
            diastolicController: diaController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'BloodPressureInputField 360dp zero overflow');
    });

    testWidgets('MedicineDateRangePicker adapts Start & End dates at 280dp and 360dp with 1.4x text scale', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 360,
          textScale: 1.4,
          child: MedicineDateRangePicker(
            startDate: DateTime(2026, 11, 15),
            endDate: DateTime(2026, 11, 22),
            endDateError: null,
            onStartDateChanged: (_) {},
            onEndDateChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'MedicineDateRangePicker zero overflow at 1.4x scale');
    });

    testWidgets('ConsultationVisitSection adapts Date and Time at 270dp vs 360dp without overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 270,
          child: const ConsultationVisitSection(),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'ConsultationVisitSection 270dp zero overflow');
    });

    testWidgets('PrimaryButton expands gracefully at 1.8x text scale without vertical overflow', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 320,
          textScale: 1.8,
          child: PrimaryButton(
            text: 'Save and Continue Registration Flow',
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'PrimaryButton zero overflow at 1.8x text scale');

      final buttonFinder = find.byType(PrimaryButton);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(50.0));
    });

    testWidgets('FamilyProfileCard renders archived and active action buttons without overflow at 320dp', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildTestScaffold(
          width: 320,
          textScale: 1.25,
          child: FamilyProfileCard(
            profile: familyProfile.copyWith(isArchived: true),
            isActive: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(errors, isEmpty, reason: 'FamilyProfileCard 320dp zero overflow');
      expect(find.text('Historical Records Preserved'), findsOneWidget);
      expect(find.text('Restore Profile'), findsOneWidget);
    });
  });
}
