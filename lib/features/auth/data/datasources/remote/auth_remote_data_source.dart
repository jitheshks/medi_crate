import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/network_diagnostic.dart';
import '../../models/requests/auth_request_models.dart';
import '../../models/responses/auth_response_models.dart';

/// Result container for Sign Up API (A1) supporting both normal success
/// and pending_verification status.
class SignUpResult {
  final bool isSuccess;
  final bool isPendingVerification;
  final SignUpResponseData? data;
  final PendingVerificationResponseData? pendingData;

  const SignUpResult.success(this.data)
    : isSuccess = true,
      isPendingVerification = false,
      pendingData = null;

  const SignUpResult.pendingVerification(this.pendingData)
    : isSuccess = false,
      isPendingVerification = true,
      data = null;

  int? get userId => isSuccess ? data?.userId : pendingData?.userId;
  String? get message => isSuccess ? data?.message : pendingData?.message;
}

/// Result container for Login API (A4) supporting both verified success
/// and pending_verification status.
class LoginResult {
  final bool isSuccess;
  final bool isPendingVerification;
  final AuthTokensResponseData? authData;
  final PendingVerificationResponseData? pendingData;

  const LoginResult.success(this.authData)
    : isSuccess = true,
      isPendingVerification = false,
      pendingData = null;

  const LoginResult.pendingVerification(this.pendingData)
    : isSuccess = false,
      isPendingVerification = true,
      authData = null;
}

/// AuthRemoteDataSource connects to the MediVault Laravel REST API
/// and executes authentication endpoints A1 through A10.
class AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSource(this._apiClient);

  Dio get _dio => _apiClient.dio;

  /// A1 — Sign Up: Registers new user and sends 4-digit OTP.
  /// Handles both new registrations (success) and unverified accounts (pending_verification).
  Future<SignUpResult> signUp(SignUpRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.signup,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final status = responseData['status'];
        if (status == 'success') {
          return SignUpResult.success(
            SignUpResponseData.fromJson(
              responseData['data'] as Map<String, dynamic>? ?? {},
            ),
          );
        } else if (status == 'pending_verification') {
          return SignUpResult.pendingVerification(
            PendingVerificationResponseData.fromJson(
              responseData['data'] as Map<String, dynamic>? ?? {},
            ),
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 400,
        responseData,
      );
    } on DioException catch (e) {
      // Check if backend returned pending_verification with 4xx / 200
      final data = e.response?.data;
      if (data is Map<String, dynamic> &&
          data['status'] == 'pending_verification') {
        return SignUpResult.pendingVerification(
          PendingVerificationResponseData.fromJson(
            data['data'] as Map<String, dynamic>? ?? {},
          ),
        );
      }
      if (e.response == null) {
        NetworkDiagnosticService.runDiagnostic();
      }
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A2 — Verify Email (OTP): Verifies 4-digit OTP and issues tokens.
  Future<AuthTokensResponseData> verifyEmail(VerifyEmailRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyEmail,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return AuthTokensResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 400,
        responseData,
      );
    } on DioException catch (e) {
      if (e.response == null) {
        NetworkDiagnosticService.runDiagnostic();
      }
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A3 — Resend OTP: Requests fresh 4-digit OTP for signup, reset_password, or change_email.
  Future<MessageResponseData> resendOtp(ResendOtpRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.resendOtp,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return MessageResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 400,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A4 — Login: Authenticates user credentials.
  Future<LoginResult> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final status = responseData['status'];
        if (status == 'success') {
          return LoginResult.success(
            AuthTokensResponseData.fromJson(
              responseData['data'] as Map<String, dynamic>? ?? {},
            ),
          );
        } else if (status == 'pending_verification') {
          return LoginResult.pendingVerification(
            PendingVerificationResponseData.fromJson(
              responseData['data'] as Map<String, dynamic>? ?? {},
            ),
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 401,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 401,
        responseData,
      );
    } on DioException catch (e) {
      // Check if backend returned pending_verification with 403 / 200
      final data = e.response?.data;
      if (data is Map<String, dynamic> &&
          data['status'] == 'pending_verification') {
        return LoginResult.pendingVerification(
          PendingVerificationResponseData.fromJson(
            data['data'] as Map<String, dynamic>? ?? {},
          ),
        );
      }
      if (e.response == null) {
        NetworkDiagnosticService.runDiagnostic();
      }
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A5 — Forgot Password: Initiates password reset flow by emailing a 4-digit OTP.
  Future<MessageResponseData> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.forgotPassword,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return MessageResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 400,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A6 — Reset Password: Completes password reset with 4-digit OTP and new password.
  Future<MessageResponseData> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.resetPassword,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return MessageResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 400,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A7 — Refresh Access Token: Rotates refresh token and gets new access token pair.
  Future<AuthTokensResponseData> refreshToken(
    RefreshTokenRequest request,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return AuthTokensResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 401,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 401,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A8 — Google Sign In: Verifies Firebase ID Token and authenticates user.
  Future<AuthTokensResponseData> googleLogin(SocialLoginRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.googleLogin,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return AuthTokensResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 401,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 401,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A9 — Apple Sign In: Verifies Firebase ID Token and authenticates user.
  Future<AuthTokensResponseData> appleLogin(SocialLoginRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.appleLogin,
        data: request.toJson(),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return AuthTokensResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 401,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 401,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// A10 — Logout: Revokes current access token and refresh tokens on server.
  Future<MessageResponseData> logout() async {
    try {
      final response = await _dio.post(ApiConstants.logout);

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success') {
          return MessageResponseData.fromJson(
            responseData['data'] as Map<String, dynamic>? ?? {},
          );
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 401,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 401,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
