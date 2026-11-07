import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ApiConstants defines base URL, API keys, timeouts, and endpoint routes
/// as specified in the official MediVault Backend API Documentation v1.0.
abstract class ApiConstants {
  static const String baseUrl =
      'https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1';

  static const String apiKeyHeader = 'x-api-key';
  static const String envApiKeyName = 'MEDIVAULT_API_KEY';

  /// Retrieves the active API key configured via flutter_dotenv (.env).
  ///
  /// Throws a [StateError] if dotenv has not loaded or if [envApiKeyName] is missing or empty.
  static String get apiKey {
    if (!dotenv.isInitialized) {
      throw StateError(
        'flutter_dotenv is not initialized. Ensure "await dotenv.load()" is called before accessing ApiConstants.apiKey.',
      );
    }
    final key = dotenv.maybeGet(envApiKeyName);
    if (key == null || key.trim().isEmpty) {
      throw StateError(
        'Missing required environment variable "$envApiKeyName". '
        'Ensure .env is configured with a valid $envApiKeyName.',
      );
    }
    return key;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  /// First-batch `limit` used by Server -> Hive pulls (D1/H1/C1/AP1/R1/M1/V1).
  ///
  /// The MediVault list API exposes only a `limit` query parameter (no
  /// `page`/`offset`/`cursor`) plus a `data.total` count. Pulls request this
  /// many rows first; if `total` exceeds it, a single follow-up request is
  /// issued with `limit == total`. Chosen high enough to cover realistic
  /// per-profile datasets in one round-trip while remaining a bounded value.
  static const int syncPullBatchLimit = 200;

  // Section A: Authentication Endpoints (A1 - A10)
  static const String signup = '/auth/signup'; // A1
  static const String verifyEmail = '/auth/verify-email'; // A2
  static const String resendOtp = '/auth/resend-otp'; // A3
  static const String login = '/auth/login'; // A4
  static const String forgotPassword = '/auth/forgot-password'; // A5
  static const String resetPassword = '/auth/reset-password'; // A6
  static const String refreshToken = '/auth/refresh-token'; // A7
  static const String googleLogin = '/auth/google-login'; // A8
  static const String appleLogin = '/auth/apple-login'; // A9
  static const String logout = '/auth/logout'; // A10

  // Section B: User Profile Endpoints (B1 - B5 / B6)
  static const String usersMe = '/users/me'; // B1, B2, B5 (delete in PDF B4)
  static const String changePassword = '/users/me/password'; // B3
  static const String changeEmail = '/users/me/email'; // B4 step 1 (PDF B5)
  static const String confirmChangeEmail =
      '/users/me/email/confirm'; // B4 step 2 (PDF B6)

  // Section D: Doctor Endpoints (D1 - D5)
  static const String doctors = '/doctors'; // D1 & D2
  static String doctor(dynamic id) => '/doctors/$id'; // D3, D4, D5

  // Section H: Hospital Endpoints (H1 - H5)
  static const String hospitals = '/hospitals'; // H1 & H2
  static String hospital(dynamic id) => '/hospitals/$id'; // H3, H4, H5

  // Section F: Family Member Endpoints (F1 - F8)
  static const String familyMembers = '/family-members'; // F1 & F3
  static String familyMember(dynamic id) => '/family-members/$id'; // F2, F4, F5
  static String familyMemberPhoto(dynamic id) =>
      '/family-members/$id/photo'; // F6
  static const String familyDashboard = '/family/dashboard'; // F7
  static const String familyAnalytics = '/family/analytics'; // F8

  // Section C: Consultation Endpoints (C1 - C6)
  static const String consultations = '/consultations'; // C1 & C2
  static String consultation(dynamic id) => '/consultations/$id'; // C3, C4, C5
  static String consultationFile(dynamic consultationId, dynamic fileId) =>
      '/consultations/$consultationId/files/$fileId'; // C6

  // Section V: Vitals Endpoints (V1 - V5)
  static const String vitals = '/vitals'; // V1 & V2
  static String vital(dynamic id) => '/vitals/$id'; // V3, V4, V5

  // Section MD: Medical Departments Endpoints (MD1)
  static const String medicalDepartments = '/medical-departments'; // MD1

  // Section M: Medicines Endpoints (M1 - M5)
  static const String medicines = '/medicines'; // M1 & M2
  static String medicine(dynamic id) => '/medicines/$id'; // M3, M4, M5

  // Section R: Report Endpoints (R1 - R6)
  static const String reports = '/reports'; // R1 & R2
  static String report(dynamic id) => '/reports/$id'; // R3, R4, R5
  static String reportFile(dynamic reportId, dynamic fileId) =>
      '/reports/$reportId/files/$fileId'; // R6

  // Section AP: Appointments Endpoints (AP1 - AP5)
  static const String appointments = '/appointments'; // AP1 & AP2
  static String appointment(dynamic id) => '/appointments/$id'; // AP3, AP4, AP5

  // Section AN: Analytics Endpoints (AN1)
  static const String analytics = '/analytics'; // AN1

  // Section DB: Dashboard Endpoints (DB1)
  static const String dashboard = '/dashboard'; // DB1

  // Section T: Timeline Endpoints (T1)
  static const String timeline = '/timeline'; // T1
}
