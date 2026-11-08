import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/exceptions/app_exception.dart';
import '../../models/responses/auth_response_models.dart';
import 'auth_remote_data_source.dart';

/// SupabaseAuthRemoteDataSource executes authentication against Supabase GoTrue
/// for email/password, OTP verification, password recovery, and native Google OAuth.
class SupabaseAuthRemoteDataSource {
  final sb.SupabaseClient _client;

  SupabaseAuthRemoteDataSource(this._client);

  sb.GoTrueClient get _auth => _client.auth;

  /// A1 — Sign Up: Creates account on Supabase with email and password.
  /// If email confirmation is required, returns pendingVerification.
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    String? dob,
    String? gender,
  }) async {
    try {
      final data = <String, dynamic>{
        'full_name': name,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
      };

      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: data,
      );

      final user = response.user;
      final session = response.session;

      // In Supabase, if email confirmation is enabled, session is null
      if (session == null || user?.emailConfirmedAt == null) {
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
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException('Internet connection required to sign up.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Registration failed: $e');
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
    } on sb.AuthException catch (e) {
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
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException('Internet connection required to sign in.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Sign in failed: $e');
    }
  }

  /// A2 — Verify Email (OTP): Verifies email using 4-digit or 6-digit OTP.
  Future<sb.User> verifyEmail({
    required String email,
    required String otp,
    sb.OtpType type = sb.OtpType.signup,
  }) async {
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
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required for verification.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Verification failed: $e');
    }
  }

  /// A3 — Resend OTP: Requests a new verification code.
  Future<MessageResponseData> resendOtp({
    required String email,
    required String type,
  }) async {
    try {
      final otpType = (type == 'reset_password' || type == 'recovery')
          ? sb.OtpType.recovery
          : sb.OtpType.signup;

      await _auth.resend(type: otpType, email: email.trim());

      return const MessageResponseData(
        message: 'Verification code sent successfully.',
      );
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to resend code.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Failed to resend code: $e');
    }
  }

  /// A5 — Forgot Password: Initiates password reset by emailing a recovery token.
  Future<MessageResponseData> forgotPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
      return const MessageResponseData(
        message: 'Password reset code sent to your email.',
      );
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to request password reset.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Password reset request failed: $e');
    }
  }

  /// A6 — Reset Password: Verifies recovery OTP and updates password.
  Future<MessageResponseData> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
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
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to reset password.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Password reset failed: $e');
    }
  }

  /// A8 — Native Google OAuth: Exchanges Google ID token directly with Supabase.
  Future<sb.User> signInWithGoogleIdToken(String idToken) async {
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
    } on sb.AuthException catch (e) {
      throw _parseAuthException(e);
    } on SocketException {
      throw const NetworkException(
        'Internet connection required for Google sign in.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Google sign in failed: $e');
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

  /// Converts Supabase [sb.AuthException] to typed [AppException].
  AppException _parseAuthException(sb.AuthException e) {
    final msg = e.message;
    final lower = msg.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return const UnauthorizedException('Invalid email or password.');
    }
    if (lower.contains('user already registered') ||
        lower.contains('user_already_exists')) {
      return const ValidationException(
        'An account with this email already exists.',
      );
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return const ValidationException(
        'Email not verified. Please verify your email.',
      );
    }
    if (lower.contains('token has expired') ||
        lower.contains('otp_expired') ||
        lower.contains('token is expired')) {
      return const ValidationException(
        'Verification code has expired. Please request a new code.',
      );
    }
    if (lower.contains('invalid token') ||
        (lower.contains('token') && lower.contains('invalid'))) {
      return const ValidationException('Invalid verification code.');
    }
    if (lower.contains('password should be') ||
        lower.contains('weak password') ||
        lower.contains('password')) {
      return ValidationException(msg);
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return const ServerException(
        'Too many requests. Please wait a moment before trying again.',
      );
    }

    return UnknownApiException(msg);
  }
}
