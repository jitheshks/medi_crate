import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/storage/supabase_storage_service.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../models/responses/auth_response_models.dart';

/// SupabaseAuthRemoteDataSource executes authentication against Supabase GoTrue
/// for email/password, OTP verification, password recovery, and native Google OAuth.
class SupabaseAuthRemoteDataSource {
  final sb.SupabaseClient _client;
  final SupabaseStorageService? customStorageService;

  SupabaseAuthRemoteDataSource(
    this._client, {
    this.customStorageService,
  });

  SupabaseStorageService get storageService =>
      customStorageService ?? SupabaseStorageService(customClient: _client);

  sb.GoTrueClient get _auth => _client.auth;

  String _getEndpointHost() {
    try {
      final restUrl = _client.rest.url;
      final uri = Uri.tryParse(restUrl);
      if (uri != null && uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return 'supabase.co';
  }

  AppException _handleAuthException(
    sb.AuthException e,
    StackTrace stackTrace,
    String operation,
  ) {
    final endpointHost = _getEndpointHost();
    AppLogger.warning(
      '[$operation] Supabase AuthException on $endpointHost: [status: ${e.statusCode}, code: ${e.code}] ${e.message}',
      'Auth',
    );
    return _parseAuthException(e, cause: e, stackTrace: stackTrace);
  }

  AppException _handleSocketException(
    SocketException e,
    StackTrace stackTrace,
    String operation,
  ) {
    final endpointHost = _getEndpointHost();
    final errCode = e.osError?.errorCode;
    final errMsg = e.osError?.message ?? e.message;

    AppLogger.error(
      '[$operation] Network failure (SocketException) on $endpointHost: $errMsg (errno: $errCode, address: ${e.address?.host ?? e.address}, port: ${e.port})',
      e,
      stackTrace,
      'Auth',
    );

    return NetworkException(
      'Unable to connect to the server. Check your internet connection and try again.',
      code: 'SOCKET_EXCEPTION_${errCode ?? 0}',
      cause: e,
      stackTrace: stackTrace,
    );
  }

  AppException _handleClientException(
    http.ClientException e,
    StackTrace stackTrace,
    String operation,
  ) {
    final endpointHost = _getEndpointHost();
    final message = e.message;
    final lower = message.toLowerCase();

    if (lower.contains('network is unreachable') ||
        lower.contains('errno = 101')) {
      AppLogger.error(
        '[$operation] Network unreachable on $endpointHost: $message (URI: ${e.uri})',
        e,
        stackTrace,
        'Auth',
      );
      return NetworkException(
        'Unable to connect to the server. Check your internet connection and try again.',
        code: 'NETWORK_UNREACHABLE',
        cause: e,
        stackTrace: stackTrace,
      );
    } else if (lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname')) {
      AppLogger.error(
        '[$operation] DNS resolution failure for $endpointHost: $message (URI: ${e.uri})',
        e,
        stackTrace,
        'Auth',
      );
      return NetworkException(
        'Unable to connect to the server. Check your internet connection and try again.',
        code: 'DNS_LOOKUP_FAILED',
        cause: e,
        stackTrace: stackTrace,
      );
    } else if (lower.contains('connection refused')) {
      AppLogger.error(
        '[$operation] Connection refused by $endpointHost: $message (URI: ${e.uri})',
        e,
        stackTrace,
        'Auth',
      );
      return NetworkException(
        'Unable to connect to the server. Check your internet connection and try again.',
        code: 'CONNECTION_REFUSED',
        cause: e,
        stackTrace: stackTrace,
      );
    } else if (lower.contains('timed out') || lower.contains('timeout')) {
      AppLogger.error(
        '[$operation] Connection timed out on $endpointHost: $message (URI: ${e.uri})',
        e,
        stackTrace,
        'Auth',
      );
      return ApiTimeoutException(
        'Connection timed out. Please check your network and try again.',
        cause: e,
        stackTrace: stackTrace,
      );
    } else if (lower.contains('handshake') ||
        lower.contains('certificate') ||
        lower.contains('tls') ||
        lower.contains('ssl')) {
      AppLogger.error(
        '[$operation] TLS/Certificate failure connecting to $endpointHost: $message (URI: ${e.uri})',
        e,
        stackTrace,
        'Auth',
      );
      return NetworkException(
        'Unable to establish a secure connection. Please check your network and security settings.',
        code: 'TLS_SECURITY_ERROR',
        cause: e,
        stackTrace: stackTrace,
      );
    } else if (lower.contains('socketexception') ||
        lower.contains('connection failed')) {
      AppLogger.error(
        '[$operation] Socket failure connecting to $endpointHost: $message (URI: ${e.uri})',
        e,
        stackTrace,
        'Auth',
      );
      return NetworkException(
        'Unable to connect to the server. Check your internet connection and try again.',
        code: 'SOCKET_CONNECTION_FAILED',
        cause: e,
        stackTrace: stackTrace,
      );
    }

    AppLogger.error(
      '[$operation] HTTP client exception connecting to $endpointHost: $message (URI: ${e.uri})',
      e,
      stackTrace,
      'Auth',
    );
    return UnknownApiException(
      'Communication with server failed: $message',
      code: 'CLIENT_EXCEPTION',
      cause: e,
      stackTrace: stackTrace,
    );
  }

  AppException _handleTimeoutException(
    TimeoutException e,
    StackTrace stackTrace,
    String operation,
  ) {
    final endpointHost = _getEndpointHost();
    AppLogger.error(
      '[$operation] Request timed out on $endpointHost: ${e.message} (duration: ${e.duration})',
      e,
      stackTrace,
      'Auth',
    );

    return ApiTimeoutException(
      'Connection timed out. Please check your network and try again.',
      cause: e,
      stackTrace: stackTrace,
    );
  }

  AppException _handleUnexpectedException(
    Object e,
    StackTrace stackTrace,
    String operation,
  ) {
    if (e is AppException) return e;

    final endpointHost = _getEndpointHost();
    AppLogger.error(
      '[$operation] Unexpected exception on $endpointHost: [${e.runtimeType}] $e',
      e,
      stackTrace,
      'Auth',
    );

    return UnknownApiException(
      'Registration failed unexpectedly: $e',
      cause: e,
      stackTrace: stackTrace,
    );
  }

  /// A1 — Sign Up: Creates account on Supabase with email and password.
  /// If email confirmation is required, returns pendingVerification.
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    String? dob,
    String? gender,
  }) async {
    const operation = 'signUp';
    final endpointHost = _getEndpointHost();
    AppLogger.info(
      'Registration request initiated for host: $endpointHost, operation: $operation',
      'Auth',
    );

    try {
      final data = <String, dynamic>{
        'full_name': name,
        if (dob != null && dob.isNotEmpty) ...{
          'dob': dob,
          'date_of_birth': dob,
        },
        if (gender != null && gender.isNotEmpty) 'gender': gender,
      };

      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: data,
      );

      final user = response.user;
      final session = response.session;
      final isPending = session == null || user?.emailConfirmedAt == null;

      AppLogger.info(
        'Registration completed successfully for host: $endpointHost, operation: $operation (pendingVerification: $isPending)',
        'Auth',
      );

      // In Supabase, if email confirmation is enabled, session is null
      if (isPending) {
        return const SignUpResult.pendingVerification(
          PendingVerificationResponseData(
            userId: null,
            message: 'Verification code sent to your email.',
          ),
        );
      }

      return const SignUpResult.success(
        SignUpResponseData(userId: 0, message: 'Registration successful.'),
      );
    } on sb.AuthException catch (e, st) {
      throw _handleAuthException(e, st, operation);
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, operation);
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, operation);
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, operation);
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, operation);
    }
  }

  /// A4 — Login: Authenticates user credentials with Supabase GoTrue.
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        throw const UnauthorizedException('Invalid login credentials.');
      }

      final authData = AuthTokensResponseData(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        userId: null,
        name:
            user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String? ??
            user.email?.split('@').first,
        email: user.email,
      );

      return LoginResult.success(authData);
    } on sb.AuthException catch (e, st) {
      final msg = e.message.toLowerCase();
      // Handle unconfirmed email
      if (msg.contains('email not confirmed') ||
          msg.contains('email_not_confirmed')) {
        try {
          await _auth.resend(type: sb.OtpType.signup, email: email.trim());
        } catch (_) {}
        return const LoginResult.pendingVerification(
          PendingVerificationResponseData(
            userId: null,
            message: 'Email not verified. OTP sent to your email.',
          ),
        );
      }
      throw _handleAuthException(e, st, 'login');
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, 'login');
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, 'login');
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, 'login');
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, 'login');
    }
  }

  /// A2 — Verify Email (OTP): Verifies email using 4-digit or 6-digit OTP.
  Future<sb.User> verifyEmail({
    required String email,
    required String otp,
    sb.OtpType type = sb.OtpType.signup,
  }) async {
    const operation = 'verifyEmail';
    try {
      final response = await _auth.verifyOTP(
        email: email.trim(),
        token: otp.trim(),
        type: type,
      );

      final user = response.user;
      if (user == null) {
        throw const ValidationException(
          'Verification failed: User record not found.',
        );
      }

      return user;
    } on sb.AuthException catch (e, st) {
      throw _handleAuthException(e, st, operation);
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, operation);
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, operation);
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, operation);
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, operation);
    }
  }

  /// A3 — Resend OTP: Requests a new verification code.
  Future<MessageResponseData> resendOtp({
    required String email,
    required String type,
  }) async {
    const operation = 'resendOtp';
    try {
      final otpType = (type == 'reset_password' || type == 'recovery')
          ? sb.OtpType.recovery
          : sb.OtpType.signup;

      await _auth.resend(type: otpType, email: email.trim());

      return const MessageResponseData(
        message: 'Verification code sent successfully.',
      );
    } on sb.AuthException catch (e, st) {
      throw _handleAuthException(e, st, operation);
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, operation);
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, operation);
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, operation);
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, operation);
    }
  }

  /// A5 — Forgot Password: Initiates password reset by emailing a recovery token.
  Future<MessageResponseData> forgotPassword(String email) async {
    const operation = 'forgotPassword';
    try {
      await _auth.resetPasswordForEmail(email.trim());
      return const MessageResponseData(
        message: 'Password reset code sent to your email.',
      );
    } on sb.AuthException catch (e, st) {
      throw _handleAuthException(e, st, operation);
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, operation);
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, operation);
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, operation);
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, operation);
    }
  }

  /// A6 — Reset Password: Verifies recovery OTP and updates password.
  Future<MessageResponseData> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    const operation = 'resetPassword';
    try {
      // Step 1: Verify the recovery OTP to establish authenticated recovery session
      final verifyRes = await _auth.verifyOTP(
        email: email.trim(),
        token: otp.trim(),
        type: sb.OtpType.recovery,
      );

      if (verifyRes.user == null) {
        throw const ValidationException(
          'Invalid or expired password reset code.',
        );
      }

      // Step 2: Update the user's password
      await _auth.updateUser(sb.UserAttributes(password: newPassword));

      // Step 3: Sign out from the recovery session
      await _auth.signOut();

      return const MessageResponseData(
        message: 'Password reset successfully. Please sign in with your new password.',
      );
    } on sb.AuthException catch (e, st) {
      throw _handleAuthException(e, st, operation);
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, operation);
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, operation);
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, operation);
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, operation);
    }
  }

  /// A8 — Native Google OAuth: Exchanges Google ID token directly with Supabase.
  Future<sb.User> signInWithGoogleIdToken(String idToken) async {
    const operation = 'signInWithGoogleIdToken';
    try {
      final response = await _auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) {
        throw const UnauthorizedException(
          'Google sign in failed: No user returned.',
        );
      }

      return user;
    } on sb.AuthException catch (e, st) {
      throw _handleAuthException(e, st, operation);
    } on SocketException catch (e, st) {
      throw _handleSocketException(e, st, operation);
    } on http.ClientException catch (e, st) {
      throw _handleClientException(e, st, operation);
    } on TimeoutException catch (e, st) {
      throw _handleTimeoutException(e, st, operation);
    } catch (e, st) {
      throw _handleUnexpectedException(e, st, operation);
    }
  }

  /// A10 — Sign Out: Terminates active Supabase session.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseAuth] Sign out error swallowed: $e');
    }
  }

  /// B4 (Step 1) — Request Change Email: Verifies current password and requests email change via GoTrue.
  Future<String> requestChangeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException('No active user session.');
    }

    final trimmedEmail = newEmail.trim();
    if (trimmedEmail.isEmpty) {
      throw const ValidationException('New email address cannot be empty.');
    }
    if (trimmedEmail.toLowerCase() == user.email?.toLowerCase()) {
      throw const ValidationException(
        'New email address must be different from current email.',
      );
    }

    // 1. Re-authenticate with current password to protect account
    final currentEmail = user.email;
    if (currentEmail != null && currentPassword.isNotEmpty) {
      try {
        await _auth.signInWithPassword(
          email: currentEmail,
          password: currentPassword,
        );
      } on sb.AuthException catch (e) {
        throw UnauthorizedException('Incorrect current password: ${e.message}');
      }
    }

    // 2. Request email change in GoTrue (sends confirmation token to new email)
    try {
      await _auth.updateUser(sb.UserAttributes(email: trimmedEmail));
      return 'Verification code sent to $trimmedEmail. Please verify to complete email change.';
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to request email change.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Failed to request email change: $e');
    }
  }

  /// B4 (Step 2) — Confirm Change Email: Verifies OTP token for email change.
  Future<sb.User> confirmChangeEmail({
    required String newEmail,
    required String otp,
  }) async {
    final trimmedEmail = newEmail.trim();
    final trimmedOtp = otp.trim();

    if (trimmedEmail.isEmpty) {
      throw const ValidationException(
        'New email address is required for verification.',
      );
    }
    if (trimmedOtp.isEmpty) {
      throw const ValidationException('Verification code cannot be empty.');
    }

    try {
      final response = await _auth.verifyOTP(
        email: trimmedEmail,
        token: trimmedOtp,
        type: sb.OtpType.emailChange,
      );

      final user = response.user;
      if (user == null) {
        throw const ValidationException(
          'Email change verification failed: user not found.',
        );
      }
      return user;
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to verify email change.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Failed to confirm email change: $e');
    }
  }

  /// B5 — Delete Account: Verifies password re-authentication and calls PostgreSQL
  /// SECURITY DEFINER RPC `delete_user_account` to delete user and cascade records.
  Future<void> deleteAccount({required String currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException('No active user session to delete.');
    }

    // 1. Password re-authentication check if email/password user
    final email = user.email;
    if (email != null && currentPassword.isNotEmpty) {
      try {
        await _auth.signInWithPassword(
          email: email.trim(),
          password: currentPassword,
        );
      } on sb.AuthException catch (e) {
        throw UnauthorizedException('Incorrect password: ${e.message}');
      } catch (e) {
        if (e is AppException) rethrow;
        throw UnauthorizedException('Failed to verify password: $e');
      }
    }

    // 2. Storage Cleanup via Supabase Storage API:
    // Purges all physical objects owned by this user across avatars, consultations,
    // and reports buckets. Must occur before calling delete_user_account RPC
    // so that positive parent-record existence in consultations and reports satisfies Storage RLS.
    try {
      await storageService.deleteAllUserFiles(userId: user.id);
    } on StorageOperationException catch (e) {
      throw ServerException(
        'Failed to purge account storage files: ${e.message}',
      );
    }

    // 3. Call SECURITY DEFINER RPC to delete auth.users (cascades to all DB tables)
    try {
      await _client.rpc('delete_user_account');
    } on sb.PostgrestException catch (e) {
      throw ServerException(
        'Failed to delete account: ${e.message}',
        code: e.code,
      );
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to delete account.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete account: $e');
    }

    // 4. Terminate local GoTrue session after successful deletion
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Converts Supabase [sb.AuthException] to typed [AppException].
  AppException _parseAuthException(
    sb.AuthException e, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final msg = e.message;
    final lower = msg.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return UnauthorizedException(
        'Invalid email or password.',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }
    if (lower.contains('user already registered') ||
        lower.contains('user_already_exists')) {
      return ValidationException(
        'An account with this email already exists.',
        code: 'USER_ALREADY_EXISTS',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return ValidationException(
        'Email not verified. Please verify your email.',
        code: 'EMAIL_NOT_CONFIRMED',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }
    if (lower.contains('token has expired') ||
        lower.contains('otp_expired') ||
        lower.contains('token is expired')) {
      return ValidationException(
        'Verification code has expired. Please request a new code.',
        code: 'OTP_EXPIRED',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }
    if (lower.contains('invalid token') ||
        (lower.contains('token') && lower.contains('invalid'))) {
      return ValidationException(
        'Invalid verification code.',
        code: 'INVALID_TOKEN',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }
    if (lower.contains('password should be') ||
        lower.contains('weak password') ||
        lower.contains('password')) {
      return ValidationException(
        msg,
        code: 'WEAK_PASSWORD',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return ServerException(
        'Too many requests. Please wait a moment before trying again.',
        code: 'RATE_LIMIT_EXCEEDED',
        cause: cause ?? e,
        stackTrace: stackTrace,
      );
    }

    return UnknownApiException(
      msg,
      code: e.code ?? 'AUTH_ERROR',
      statusCode: int.tryParse(e.statusCode ?? ''),
      cause: cause ?? e,
      stackTrace: stackTrace,
    );
  }
}
