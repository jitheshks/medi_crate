import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../datasources/local/auth_local_data_source.dart';
import '../datasources/remote/supabase_auth_remote_data_source.dart';
import '../models/responses/auth_response_models.dart';
import '../models/user_model.dart';

/// AuthRepository orchestrates authentication business logic and coordinates
/// between Supabase GoTrue, local secure storage, and Hive caching.
class AuthRepository {
  final AuthLocalDataSource localDataSource;
  final SupabaseAuthRemoteDataSource? customSupabaseRemoteDataSource;
  final SecureStorageService secureStorage;
  final ConnectivityService connectivityService;
  final sb.SupabaseClient? customSupabaseClient;

  AuthRepository({
    required this.localDataSource,
    SupabaseAuthRemoteDataSource? supabaseRemoteDataSource,
    required this.secureStorage,
    required this.connectivityService,
    sb.SupabaseClient? supabaseClient,
    dynamic userRemoteDataSource,
    dynamic remoteDataSource,
  }) : customSupabaseRemoteDataSource = supabaseRemoteDataSource,
       customSupabaseClient = supabaseClient;

  sb.SupabaseClient get _client {
    final client = customSupabaseClient;
    if (client != null) return client;
    if (SupabaseConfig.isInitialized) return SupabaseConfig.client;
    throw StateError(
      'SupabaseClient is not initialized and was not injected into AuthRepository.',
    );
  }

  SupabaseAuthRemoteDataSource get supabaseRemoteDataSource =>
      customSupabaseRemoteDataSource ?? SupabaseAuthRemoteDataSource(_client);

  /// Checks if a valid active session exists locally or via Supabase session persistence.
  Future<bool> checkSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null && !session.isExpired) {
        final cachedUser = await localDataSource.getUser();
        if (cachedUser == null) {
          final sbUser = _client.auth.currentUser;
          if (sbUser != null) {
            final user = UserModel.fromSupabaseUser(sbUser);
            await localDataSource.saveUser(user);
          }
        }
        return true;
      }

      if (session != null && session.isExpired) {
        try {
          final refreshed = await _client.auth.refreshSession();
          if (refreshed.session != null) {
            final sbUser = refreshed.user;
            if (sbUser != null) {
              final user = UserModel.fromSupabaseUser(sbUser);
              await localDataSource.saveUser(user);
            }
            return true;
          }
        } catch (_) {}
      }
    } catch (_) {
      // If client is not available or throws in offline state, fallback to local storage
    }

    final localUser = await localDataSource.getUser();
    final isLoggedIn = await localDataSource.isLoggedIn();
    return localUser != null && isLoggedIn;
  }

  /// Retrieves the currently cached authenticated user profile.
  Future<UserModel?> getCurrentUser() async {
    final cached = await localDataSource.getUser();
    if (cached != null) return cached;

    try {
      final sbUser = _client.auth.currentUser;
      if (sbUser != null) {
        final user = UserModel.fromSupabaseUser(sbUser);
        await localDataSource.saveUser(user);
        return user;
      }
    } catch (_) {}

    return null;
  }

  /// A1 — Sign Up
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String dob,
    String? gender,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to create your account.',
      );
    }

    if (password != passwordConfirmation) {
      throw const ValidationException('Passwords do not match.');
    }

    return await supabaseRemoteDataSource.signUp(
      name: name,
      email: email,
      password: password,
      dob: dob,
      gender: gender,
    );
  }

  /// A2 — Verify Email (OTP)
  Future<UserModel> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to verify your email.',
      );
    }

    final sbUser = await supabaseRemoteDataSource.verifyEmail(
      email: email,
      otp: otp,
    );

    final user = UserModel.fromSupabaseUser(sbUser);
    await localDataSource.saveUser(user);
    return user;
  }

  /// A3 — Resend OTP
  Future<MessageResponseData> resendOtp({
    required String email,
    required String type,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to resend verification code.',
      );
    }

    return await supabaseRemoteDataSource.resendOtp(email: email, type: type);
  }

  /// A4 — Sign In / Login
  Future<LoginResult> signIn({
    required String email,
    required String password,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException('Internet connection required to sign in.');
    }

    final result = await supabaseRemoteDataSource.login(
      email: email,
      password: password,
    );

    if (result.isSuccess) {
      try {
        final sbUser = _client.auth.currentUser;
        if (sbUser != null) {
          final user = UserModel.fromSupabaseUser(sbUser);
          await localDataSource.saveUser(user);
        }
      } catch (_) {}
    }

    return result;
  }

  /// A5 — Forgot Password
  Future<MessageResponseData> forgotPassword(String email) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to request password reset.',
      );
    }

    return await supabaseRemoteDataSource.forgotPassword(email);
  }

  /// A6 — Reset Password
  Future<MessageResponseData> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to reset password.',
      );
    }

    if (newPassword != passwordConfirmation) {
      throw const ValidationException('Passwords do not match.');
    }

    final res = await supabaseRemoteDataSource.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );

    await secureStorage.clearAuthToken();
    await localDataSource.clearUser();

    return res;
  }

  /// A7 — Refresh Access Token
  Future<AuthTokensResponseData> refreshToken() async {
    try {
      final response = await _client.auth.refreshSession();
      final session = response.session;
      if (session == null) {
        throw const UnauthorizedException(
          'Failed to refresh Supabase session.',
        );
      }
      return AuthTokensResponseData(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        email: session.user.email,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnauthorizedException('No valid refresh session: $e');
    }
  }

  /// A8 — Google Sign In (Direct Google ID token exchange with Supabase)
  Future<UserModel> googleLogin(String googleIdToken) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required for Google sign in.',
      );
    }

    final sbUser = await supabaseRemoteDataSource.signInWithGoogleIdToken(
      googleIdToken,
    );

    final user = UserModel.fromSupabaseUser(
      sbUser,
      provider: AuthProviderType.google,
    );
    await localDataSource.saveUser(user);

    return user;
  }

  /// A9 — Apple Sign In (Retained for backwards compatibility)
  Future<UserModel> appleLogin(String token) async {
    throw UnsupportedError(
      'Apple Sign In is not supported in the Supabase-first MediCrate architecture.',
    );
  }

  /// A10 — Sign Out / Logout
  Future<void> signOut() async {
    final isOnline = await connectivityService.checkConnectivity();
    if (isOnline) {
      try {
        await supabaseRemoteDataSource.signOut();
      } catch (_) {}
    }

    // Clear legacy secure storage keys
    await secureStorage.clearAuthToken();

    // Clear local user cache (preserves all Hive clinical boxes: profileBox, userBox clinical records, syncQueueBox)
    await localDataSource.clearUser();
  }

  String? _pendingNewEmail;

  /// B3 — Change Password
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to change password.',
      );
    }

    if (newPassword != newPasswordConfirmation) {
      throw const ValidationException('Passwords do not match.');
    }

    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
      return 'Password updated successfully.';
    } on sb.AuthException catch (e) {
      throw ValidationException('Failed to update password: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownApiException('Failed to change password: $e');
    }
  }

  /// B4 (Step 1 / PDF B5) — Request Change Email
  Future<String> requestChangeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to request email change.',
      );
    }

    _pendingNewEmail = newEmail.trim();

    return await supabaseRemoteDataSource.requestChangeEmail(
      currentPassword: currentPassword,
      newEmail: newEmail,
    );
  }

  /// B4 (Step 2 / PDF B6) — Confirm Change Email
  Future<Map<String, dynamic>> confirmChangeEmail({
    required String otp,
    String? newEmail,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to verify OTP.',
      );
    }

    final targetEmail = (newEmail != null && newEmail.trim().isNotEmpty)
        ? newEmail.trim()
        : (_pendingNewEmail ??
            _client.auth.currentUser?.newEmail ??
            _client.auth.currentUser?.email ??
            '');

    if (targetEmail.isEmpty) {
      throw const ValidationException(
        'Target email address not found for verification. Please request email change again.',
      );
    }

    final updatedUser = await supabaseRemoteDataSource.confirmChangeEmail(
      newEmail: targetEmail,
      otp: otp,
    );

    _pendingNewEmail = null;

    final effectiveEmail = updatedUser.email ?? targetEmail;
    final currentUser = await localDataSource.getUser();
    if (currentUser != null) {
      await localDataSource.saveUser(
        currentUser.copyWith(email: effectiveEmail),
      );
    }

    return {
      'status': 'success',
      'message': 'Email updated successfully.',
      'user': {
        'id': updatedUser.id,
        'email': effectiveEmail,
      },
    };
  }

  /// B5 (PDF B4) — Delete Account
  Future<String> deleteAccount({required String currentPassword}) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to delete account.',
      );
    }

    // 1. Execute Supabase RPC deletion workflow (verifies password, purges storage, cascades in DB)
    await supabaseRemoteDataSource.deleteAccount(
      currentPassword: currentPassword,
    );

    // 2. Clear local credentials and user cache only AFTER remote deletion succeeds.
    // Local cleanup failure cannot incorrectly report that server-side deletion failed.
    try {
      await secureStorage.clearAuthToken();
    } catch (_) {}
    try {
      await localDataSource.clearUser();
    } catch (_) {}

    return 'Account successfully deleted.';
  }
}
