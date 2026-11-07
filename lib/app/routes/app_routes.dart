import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/screens/add_edit_appointment_screen.dart';
import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/appointments/presentation/screens/appointments_list_screen.dart';
import '../../features/consultations/data/models/consultation_model.dart';
import '../../features/consultations/presentation/screens/consultation_detail_screen.dart';
import '../../features/consultations/presentation/screens/consultations_list_screen.dart';
import '../../features/consultations/presentation/screens/new_consultation_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/doctor_summary/presentation/screens/doctor_summary_screen.dart';
import '../../features/doctors/presentation/screens/add_edit_doctor_screen.dart';
import '../../features/doctors/presentation/screens/doctor_profile_screen.dart';
import '../../features/doctors/presentation/screens/doctors_list_screen.dart';
import '../../features/hospitals/presentation/screens/add_edit_hospital_screen.dart';
import '../../features/hospitals/presentation/screens/hospital_profile_screen.dart';
import '../../features/hospitals/presentation/screens/hospitals_list_screen.dart';
import '../../features/medicines/presentation/screens/add_edit_medicine_screen.dart';
import '../../features/medicines/presentation/screens/medicine_detail_screen.dart';
import '../../features/medicines/presentation/screens/medicines_list_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/manage_profiles_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reports/presentation/screens/add_edit_report_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/reports/presentation/screens/view_report_screen.dart';
import '../../features/vitals/data/models/measurement_model.dart';
import '../../features/vitals/presentation/screens/add_measurement_form_screen.dart';
import '../../features/vitals/presentation/screens/add_measurement_type_screen.dart';
import '../../features/vitals/presentation/screens/measurements_list_screen.dart';
import 'auth_routes.dart';
import 'settings_routes.dart';

abstract final class AppRoutes {
  // Splash & Auth
  static const splash = '/splash';
  static const root = '/';
  static const welcome = '/sign-in';
  static const login = '/login';
  static const signIn = '/sign-in';
  static const signup = '/signup';
  static const signUp = '/sign-up';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static String resetPasswordWithParams({
    required String email,
    String? token,
  }) {
    final params = <String, String>{
      'email': email,
      if (token != null && token.isNotEmpty) 'token': token,
    };
    return Uri(path: '/reset-password', queryParameters: params).toString();
  }

  static const terms = '/terms';
  static const termsPrivacy = '/terms-privacy';
  static const otpVerification = '/otp-verification';
  static String otpVerificationWithParams({
    required String email,
    required String type,
    int? userId,
  }) {
    final params = <String, String>{
      'email': email,
      'type': type,
      if (userId != null) 'user_id': userId.toString(),
    };
    return Uri(path: '/otp-verification', queryParameters: params).toString();
  }

  // Core & Dashboard
  static const dashboard = '/dashboard';
  static const home = '/home';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const profiles = '/profiles';
  static const timeline = '/timeline';
  static const doctorSummary = '/doctor-summary';

  // Appointments & Follow-ups
  static const appointments = '/appointments';
  static const followups = '/followups';
  static const appointmentNew = '/appointments/new';
  static const newAppointment = appointmentNew;
  static const addAppointment = appointmentNew;
  static String appointmentDetail(String id) => '/appointments/$id';
  static String appointmentEdit(String id) => '/appointments/$id/edit';
  static String editAppointment(String id) => appointmentEdit(id);

  // Consultations
  static const consultations = '/consultations';
  static const consultationAdd = '/consultations/add';
  static const addConsultation = consultationAdd;
  static const newConsultation = consultationAdd;
  static String consultationDetail(String id) => '/consultations/$id';
  static String consultationEdit(String id) => '/consultations/$id/edit';
  static String editConsultation(String id) => consultationEdit(id);

  // Doctors
  static const doctors = '/doctors';
  static const doctorAdd = '/doctors/add';
  static const addDoctor = doctorAdd;
  static const newDoctor = doctorAdd;
  static String doctorProfile(String id) => '/doctors/$id';
  static String doctorEdit(String id) => '/doctors/$id/edit';
  static String editDoctor(String id) => doctorEdit(id);

  // Hospitals
  static const hospitals = '/hospitals';
  static const hospitalAdd = '/hospitals/add';
  static const addHospital = hospitalAdd;
  static const newHospital = hospitalAdd;
  static String hospitalProfile(String id) => '/hospitals/$id';
  static String hospitalEdit(String id) => '/hospitals/$id/edit';
  static String editHospital(String id) => hospitalEdit(id);

  // Medicines
  static const medicines = '/medicines';
  static const medicineAdd = '/medicines/add';
  static const addMedicine = medicineAdd;
  static const newMedicine = medicineAdd;
  static String medicineDetail(String id) => '/medicines/$id';
  static String medicineEdit(String id) => '/medicines/$id/edit';
  static String editMedicine(String id) => medicineEdit(id);

  // Reports
  static const reports = '/reports';
  static const reportAdd = '/reports/add';
  static const addReport = reportAdd;
  static const newReport = reportAdd;
  static String reportDetail(String id) => '/reports/$id';
  static String reportEdit(String id) => '/reports/$id/edit';
  static String editReport(String id) => reportEdit(id);

  // Vitals / Measurements
  static const measurements = '/measurements';
  static const vitals = '/vitals';
  static const measurementAdd = '/measurements/add';
  static const addMeasurement = measurementAdd;
  static const newMeasurement = measurementAdd;
  static const measurementForm = '/measurements/form';
  static String measurementFormWithType(String type) =>
      '/measurements/form?type=$type';

  // OCR
  static const scan = '/scan';
  static const ocrReview = '/ocr-review';

  // Settings
  static const settings = '/settings';
  static const settingsAccount = '/account';
  static const settingsSecurity = '/security';
  static const settingsChangePassword = '/change-password';
  static const settingsAccountSecurity = '/settings/account-security';
  static const accountSecurity = settingsAccountSecurity;
  static const settingsSecuritySub = '/settings/security';
  static const settingsAppearance = '/settings/appearance';
  static const settingsCurrency = '/settings/currency';
  static const settingsDataSync = '/settings/data-sync';
  static const settingsStorage = '/settings/storage';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsAbout = '/settings/about';
  static const settingsHelpSupport = '/settings/help-support';
  static const settingsNotifications = '/settings/notifications';
  static const settingsExport = '/settings/export';
  static const settingsExportRecords = '/settings/export-records';
}

typedef Routes = AppRoutes;

/// Complete list of application routes.
final List<RouteBase> appRoutes = [
  ...authRoutes,
  GoRoute(
    path: AppRoutes.notifications,
    builder: (context, state) => const NotificationsScreen(),
  ),
  GoRoute(
    path: AppRoutes.dashboard,
    builder: (context, state) => const DashboardScreen(),
  ),
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => const DashboardScreen(),
  ),
  GoRoute(
    path: AppRoutes.doctorSummary,
    builder: (context, state) => const DoctorSummaryScreen(),
  ),
  GoRoute(
    path: AppRoutes.profile,
    builder: (context, state) => const ProfileScreen(),
  ),
  GoRoute(
    path: AppRoutes.editProfile,
    builder: (context, state) => const ProfileScreen(),
  ),
  GoRoute(
    path: AppRoutes.profiles,
    builder: (context, state) => const ManageProfilesScreen(),
  ),
  GoRoute(
    path: AppRoutes.timeline,
    builder: (context, state) => const DashboardScreen(),
  ),
  GoRoute(
    path: AppRoutes.measurements,
    builder: (context, state) => const MeasurementsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.vitals,
    builder: (context, state) => const MeasurementsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.measurementAdd,
    builder: (context, state) => const AddMeasurementTypeScreen(),
  ),
  GoRoute(
    path: AppRoutes.measurementForm,
    builder: (context, state) {
      final type = state.uri.queryParameters['type'];
      final extraMap = state.extra as Map<String, dynamic>?;
      final initialMeasurement = extraMap?['measurement'] as MeasurementModel?;
      return AddMeasurementFormScreen(
        type: type,
        initialMeasurement: initialMeasurement,
      );
    },
  ),
  GoRoute(
    path: AppRoutes.consultations,
    builder: (context, state) => const ConsultationsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.consultationAdd,
    builder: (context, state) {
      final extraConsultation = state.extra is ConsultationModel
          ? state.extra as ConsultationModel
          : (state.extra is Map<String, dynamic>
                ? (state.extra as Map<String, dynamic>)['consultation']
                      as ConsultationModel?
                : null);
      return NewConsultationScreen(initialConsultation: extraConsultation);
    },
  ),
  GoRoute(
    path: '/consultations/:id',
    builder: (context, state) =>
        ConsultationDetailScreen(consultationId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/consultations/:id/edit',
    builder: (context, state) =>
        NewConsultationScreen(consultationIdToEdit: state.pathParameters['id']),
  ),
  GoRoute(
    path: AppRoutes.reports,
    builder: (context, state) =>
        const ReportsScreen(showStandaloneAppBar: true),
  ),
  GoRoute(
    path: AppRoutes.reportAdd,
    builder: (context, state) => const AddEditReportScreen(),
  ),
  GoRoute(
    path: '/reports/:id',
    builder: (context, state) =>
        ViewReportScreen(reportId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/reports/:id/edit',
    builder: (context, state) =>
        AddEditReportScreen(reportIdToEdit: state.pathParameters['id']),
  ),
  GoRoute(
    path: AppRoutes.medicines,
    builder: (context, state) => const MedicinesListScreen(),
  ),
  GoRoute(
    path: AppRoutes.medicineAdd,
    builder: (context, state) => const AddEditMedicineScreen(),
  ),
  GoRoute(
    path: '/medicines/:id',
    builder: (context, state) =>
        MedicineDetailScreen(medicineId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/medicines/:id/edit',
    builder: (context, state) =>
        AddEditMedicineScreen(medicineIdToEdit: state.pathParameters['id']),
  ),
  GoRoute(
    path: AppRoutes.appointments,
    builder: (context, state) => const AppointmentsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.followups,
    builder: (context, state) => const AppointmentsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.appointmentNew,
    builder: (context, state) => const AddEditAppointmentScreen(),
  ),
  GoRoute(
    path: '/appointments/:id',
    builder: (context, state) =>
        AppointmentDetailScreen(appointmentId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/appointments/:id/edit',
    builder: (context, state) => AddEditAppointmentScreen(
      appointmentIdToEdit: state.pathParameters['id'],
    ),
  ),
  GoRoute(
    path: AppRoutes.doctors,
    builder: (context, state) => const DoctorsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.doctorAdd,
    builder: (context, state) => const AddEditDoctorScreen(),
  ),
  GoRoute(
    path: '/doctors/:id',
    builder: (context, state) =>
        DoctorProfileScreen(doctorId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/doctors/:id/edit',
    builder: (context, state) =>
        AddEditDoctorScreen(doctorIdToEdit: state.pathParameters['id']),
  ),
  GoRoute(
    path: AppRoutes.hospitals,
    builder: (context, state) => const HospitalsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.hospitalAdd,
    builder: (context, state) => const AddEditHospitalScreen(),
  ),
  GoRoute(
    path: '/hospitals/:id',
    builder: (context, state) =>
        HospitalProfileScreen(hospitalId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/hospitals/:id/edit',
    builder: (context, state) =>
        AddEditHospitalScreen(hospitalIdToEdit: state.pathParameters['id']),
  ),
  // GoRoute(
  //   path: AppRoutes.scan,
  //   builder: (context, state) => const ScanPrescriptionScreen(),
  // ),
  // GoRoute(
  //   path: AppRoutes.ocrReview,
  //   builder: (context, state) => const OcrReviewScreen(),
  // ),
  ...settingsRoutes,
];
