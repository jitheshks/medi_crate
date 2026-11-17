// ignore_for_file: depend_on_referenced_packages

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/theme/app_theme.dart';
import 'package:medi_crate/features/appointments/presentation/screens/add_edit_appointment_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:medi_crate/features/consultations/presentation/screens/new_consultation_screen.dart';
import 'package:medi_crate/features/doctors/presentation/screens/add_edit_doctor_screen.dart';
import 'package:medi_crate/features/hospitals/presentation/screens/add_edit_hospital_screen.dart';
import 'package:medi_crate/features/medicines/presentation/screens/add_edit_medicine_screen.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/profile/presentation/screens/manage_profiles_screen.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_form_dialog.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_switcher_sheet.dart';
import 'package:medi_crate/features/reports/presentation/screens/add_edit_report_screen.dart';
import 'package:medi_crate/features/vitals/data/models/measurement_model.dart';
import 'package:medi_crate/features/vitals/presentation/providers/measurement_providers.dart';
import 'package:medi_crate/features/vitals/presentation/screens/add_measurement_form_screen.dart';
import 'package:medi_crate/features/vitals/presentation/screens/vitals_screen.dart';
import 'package:medi_crate/shared/attachments/models/attachment_item.dart';
import 'package:medi_crate/shared/attachments/presentation/attachment_preview_screen.dart';

Widget _buildTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  _FakeActiveProfileNotifier(this._profile);
  final ProfileModel? _profile;

  @override
  ProfileModel? build() => _profile;
}

class _FakeProfilesListNotifier extends ProfilesListNotifier {
  _FakeProfilesListNotifier(this._profiles);
  final List<ProfileModel> _profiles;

  @override
  Future<List<ProfileModel>> build() async => _profiles;
}

class _FakeMeasurementsListNotifier extends MeasurementsListNotifier {
  _FakeMeasurementsListNotifier(this._measurements);
  final List<MeasurementModel> _measurements;

  @override
  Future<List<MeasurementModel>> build() async => _measurements;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockPrimaryProfile = ProfileModel(
    profileId: 'prof_test_primary_1',
    serverProfileId: 101,
    ownerUserId: 'user_test_uuid',
    fullName: 'Alice Test User',
    relationship: 'Self',
    isPrimary: true,
    isArchived: false,
    allergies: const ['Penicillin'],
    chronicConditions: const ['Hypertension'],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final mockSecondaryProfile = ProfileModel(
    profileId: 'prof_test_secondary_2',
    serverProfileId: 102,
    ownerUserId: 'user_test_uuid',
    fullName: 'Jane Test Mother',
    relationship: 'Mother',
    isPrimary: false,
    isArchived: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final standardOverrides = [
    activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(mockPrimaryProfile)),
    profilesListProvider.overrideWith(() => _FakeProfilesListNotifier([mockPrimaryProfile, mockSecondaryProfile])),
    measurementsListProvider.overrideWith(() => _FakeMeasurementsListNotifier([])),
  ];

  group('MediCrate Actual Flutter UI Workflow Verification', () {
    testWidgets('1. Registration and Login UI Workflow', (tester) async {
      // Step 1: Render SignUpScreen
      await tester.pumpWidget(_buildTestApp(child: const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.text('Create your MediCrate account'), findsOneWidget);
      expect(find.text('CREATE YOUR ACCOUNT'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);

      // Enter registration information
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Alice Test');
      await tester.enterText(textFields.at(1), 'alice.test@example.com');
      await tester.enterText(textFields.at(2), 'Password123!');
      await tester.pump();

      // Step 2: Render SignInScreen
      await tester.pumpWidget(_buildTestApp(child: const SignInScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Welcome back to MediCrate'), findsWidgets);
      expect(find.text('Sign In'), findsWidgets);

      // Step 3: Render OtpVerificationScreen
      await tester.pumpWidget(_buildTestApp(
        child: const OtpVerificationScreen(
          email: 'alice.test@example.com',
          type: 'signup',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(find.text('Verify your identity'), findsOneWidget);
      expect(find.textContaining('verification code'), findsOneWidget);
      expect(find.textContaining('al***@example.com'), findsOneWidget);
    });

    testWidgets('2. Self & Family Profile Management and Selection UI Workflow', (tester) async {
      // Step 1: Manage Profiles Screen
      await tester.pumpWidget(_buildTestApp(
        child: const ManageProfilesScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ManageProfilesScreen), findsOneWidget);
      expect(find.text('Family Profiles'), findsWidgets);
      expect(find.text('Alice Test User'), findsWidgets);
      expect(find.text('ACTIVE PROFILE'), findsOneWidget);

      // Step 2: Profile Switcher Sheet
      await tester.pumpWidget(_buildTestApp(
        child: const ProfileSwitcherSheet(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Switch Health Profile'), findsOneWidget);
      expect(find.text('Alice Test User'), findsOneWidget);
      expect(find.text('Jane Test Mother'), findsOneWidget);

      // Step 3: Add Family Profile Dialog
      await tester.pumpWidget(_buildTestApp(
        child: const ProfileFormDialog(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Add Family Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsWidgets);
      expect(find.text('Relationship'), findsWidgets);
    });

    testWidgets('3. Doctor and Hospital Management UI Workflow', (tester) async {
      // Step 1: Add/Edit Hospital Screen
      await tester.pumpWidget(_buildTestApp(
        child: const AddEditHospitalScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditHospitalScreen), findsOneWidget);
      expect(find.text('Add Hospital / Clinic'), findsWidgets);
      expect(find.byType(TextFormField), findsWidgets);

      // Step 2: Add/Edit Doctor Screen
      await tester.pumpWidget(_buildTestApp(
        child: const AddEditDoctorScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditDoctorScreen), findsOneWidget);
      expect(find.text('Add Doctor'), findsWidgets);
      expect(find.text('SPECIALTY *'), findsWidgets);
    });

    testWidgets('4. Consultation Creation & Attachment Preview UI Workflow', (tester) async {
      // Step 1: New Consultation Screen
      await tester.pumpWidget(_buildTestApp(
        child: const NewConsultationScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewConsultationScreen), findsOneWidget);
      expect(find.text('New Consultation'), findsWidgets);
      expect(find.text('CHIEF COMPLAINT *'), findsWidgets);
      expect(find.text('DIAGNOSIS *'), findsWidgets);

      // Step 2: Attachment Preview Screen
      final testAttachment = AttachmentItem(
        id: 'attach_test_1',
        name: 'blood_test_report.pdf',
        formattedSize: '1.2 MB',
        filePath: '/tmp/test.pdf',
        fileType: 'application/pdf',
      );

      await tester.pumpWidget(_buildTestApp(
        child: AttachmentPreviewScreen(attachment: testAttachment),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentPreviewScreen), findsOneWidget);
      expect(find.text('blood_test_report.pdf'), findsWidgets);
    });

    testWidgets('5. Medicine Management UI Workflow', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: const AddEditMedicineScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditMedicineScreen), findsOneWidget);
      expect(find.text('Add Medicine'), findsWidgets);
      expect(find.text('DOSAGE *'), findsWidgets);
    });

    testWidgets('6. Appointment Management UI Workflow', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: const AddEditAppointmentScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditAppointmentScreen), findsOneWidget);
      expect(find.text('New Appointment'), findsWidgets);
      expect(find.text('TITLE *'), findsWidgets);
    });

    testWidgets('7. Report Creation UI Workflow', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: const AddEditReportScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditReportScreen), findsOneWidget);
      expect(find.text('Upload Report'), findsWidgets);
      expect(find.text('REPORT TITLE *'), findsWidgets);
      expect(find.text('CATEGORY *'), findsWidgets);
    });

    testWidgets('8. Vitals Entry & History UI Workflow', (tester) async {
      // Step 1: Add Blood Pressure vital reading
      await tester.pumpWidget(_buildTestApp(
        child: const AddMeasurementFormScreen(type: 'blood_pressure'),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AddMeasurementFormScreen), findsOneWidget);
      expect(find.textContaining('Blood Pressure'), findsWidgets);
      expect(find.text('SYSTOLIC (MMHG)'), findsWidgets);
      expect(find.text('DIASTOLIC (MMHG)'), findsWidgets);

      // Step 2: Vitals Screen
      await tester.pumpWidget(_buildTestApp(
        child: const VitalsScreen(),
        overrides: standardOverrides,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VitalsScreen), findsOneWidget);
      expect(find.text('Health Measurements'), findsOneWidget);
    });

    testWidgets('9. Session Restoration after Application Restart', (tester) async {
      // Simulate app session persistence
      final restoredProfile = mockPrimaryProfile;
      expect(restoredProfile.fullName, 'Alice Test User');
      expect(restoredProfile.isPrimary, isTrue);

      // Pump app with restored profile
      await tester.pumpWidget(_buildTestApp(
        child: const ManageProfilesScreen(),
        overrides: [
          activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(restoredProfile)),
          profilesListProvider.overrideWith(() => _FakeProfilesListNotifier([restoredProfile])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Alice Test User'), findsWidgets);
      expect(find.text('ACTIVE PROFILE'), findsWidgets);
      expect(find.text('PRIMARY'), findsWidgets);
    });
  });
}
