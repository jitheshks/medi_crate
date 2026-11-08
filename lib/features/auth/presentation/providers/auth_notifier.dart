import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/exceptions/app_exception.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/apple_auth_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'auth_providers.dart';

class AuthNotifier extends Notifier<AuthState> {
  final AuthRepository? _customRepository;
  final GoogleAuthService? _customGoogleAuthService;
  final AppleAuthService? _customAppleAuthService;
  final sb.SupabaseClient? _customSupabaseClient;
  Future<void>? _initialSessionFuture;
  StreamSubscription<sb.AuthState>? _authStateSubscription;

  AuthNotifier([
    this._customRepository,
    Ref? _,
    this._customGoogleAuthService,
    this._customAppleAuthService,
    this._customSupabaseClient,
  ]);

  AuthRepository get _repository =>
      _customRepository ?? ref.read(authRepositoryProvider);
  GoogleAuthService get _googleAuthService =>
      _customGoogleAuthService ?? ref.read(googleAuthServiceProvider);
  AppleAuthService? get appleAuthService => _customAppleAuthService;
  sb.SupabaseClient? get _supabaseClient {
    if (_customSupabaseClient != null) return _customSupabaseClient;
    try {
      return ref.read(supabaseClientProvider);
    } catch (_) {
      return null;
    }
  }

  /// Whether this notifier is currently mounted and active.
  bool get mounted => ref.mounted;

  @override
  AuthState build() {
    _initialSessionFuture = Future.microtask(checkInitialSession);

    final client = _supabaseClient;
    if (client != null) {
      try {
        _authStateSubscription = client.auth.onAuthStateChange.listen((data) {
          _handleSupabaseAuthEvent(data.event, data.session);
        });
      } catch (_) {}
    }

    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    return const AuthState();
  }

  void _handleSupabaseAuthEvent(sb.AuthChangeEvent event, sb.Session? session) {
    if (!mounted) return;

    switch (event) {
      case sb.AuthChangeEvent.signedIn:
      case sb.AuthChangeEvent.tokenRefreshed:
      case sb.AuthChangeEvent.userUpdated:
        if (session?.user != null) {
          final user = UserModel.fromSupabaseUser(session!.user);
          if (!state.isAuthenticated || state.user?.id != user.id) {
            state = state.copyWith(
              isLoading: false,
              isAuthenticated: true,
              isPendingVerification: false,
              user: user,
            );
          }
        }
        break;
      case sb.AuthChangeEvent.signedOut:
        if (state.isAuthenticated) {
          _clearSessionState();
        }
        break;
      default:
        break;
    }
  }

  /// Completes when the one-time initial session restoration has finished.
  /// Used by SplashScreen to advance on readiness instead of a fixed timer.
  Future<void> get initialSessionReady =>
      _initialSessionFuture ?? Future<void>.value();

  void clearLoginError() {
    state = state.copyWith(clearLoginError: true);
  }

  void clearSignupError() {
    state = state.copyWith(clearSignupError: true);
  }

  void clearForgotPasswordError() {
    state = state.copyWith(clearForgotPasswordError: true);
  }

  void clearResetPasswordError() {
    state = state.copyWith(clearResetPasswordError: true);
  }

  void clearOtpError() {
    state = state.copyWith(clearOtpError: true);
  }

  void clearSessionError() {
    state = state.copyWith(clearSessionError: true);
  }

  void clearAllErrors() {
    state = state.copyWith(clearAllErrors: true);
  }

  void clearError() {
    state = state.copyWith(clearAllErrors: true);
  }

  Future<void> checkInitialSession() async {
    state = state.copyWith(isLoading: true, clearAllErrors: true);
    try {
      final hasSession = await _repository.checkSession();
      if (!mounted) return;
      if (state.isAuthenticated && state.user != null) {
        return;
      }
      if (hasSession) {
        final user = await _repository.getCurrentUser();
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
        );
      } else {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          user: null,
        );
      }
    } catch (_) {
      if (!mounted) return;
      if (!state.isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          user: null,
        );
      }
    }
  }

  /// A4 — Sign In
  Future<LoginResult?> signIn(String email, String password) async {
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearLoginError: true);
    try {
      final result = await _repository.signIn(email: email, password: password);

      if (result.isSuccess && result.authData != null) {
        final user = await _repository.getCurrentUser();
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          isPendingVerification: false,
          user: user,
        );
      } else if (result.isPendingVerification) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          isPendingVerification: true,
          pendingEmail: email,
          loginError:
              result.pendingData?.message ??
              'Email not verified. OTP sent to your email.',
        );
      }
      return result;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, loginError: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loginError: 'An unexpected error occurred. Please try again.',
      );
      return null;
    }
  }

  /// A1 — Sign Up
  Future<SignUpResult?> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String dob,
    String? gender,
  }) async {
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearSignupError: true);
    try {
      final response = await _repository.signUp(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        dob: dob,
        gender: gender,
      );

      final message =
          response.message ??
          (response.isPendingVerification
              ? 'Email not verified. OTP resent successfully.'
              : 'Verification code sent to your email');

      state = state.copyWith(
        isLoading: false,
        isPendingVerification: true,
        pendingEmail: email,
        successMessage: message,
      );
      return response;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, signupError: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        signupError: 'Registration failed. Please try again.',
      );
      return null;
    }
  }

  /// A2 — Verify Email (OTP)
  Future<bool> verifyEmail({required String email, required String otp}) async {
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearOtpError: true);
    try {
      final user = await _repository.verifyEmail(email: email, otp: otp);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isPendingVerification: false,
        pendingEmail: null,
        user: user,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, otpError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        otpError: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  /// A3 — Resend OTP
  Future<bool> resendOtp({required String email, required String type}) async {
    state = state.copyWith(isLoading: true, clearOtpError: true);
    try {
      final res = await _repository.resendOtp(email: email, type: type);
      state = state.copyWith(isLoading: false, successMessage: res.message);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, otpError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        otpError: 'Failed to resend code. Please try again.',
      );
      return false;
    }
  }

  /// A5 — Forgot Password
  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearForgotPasswordError: true);
    try {
      final res = await _repository.forgotPassword(email);
      state = state.copyWith(
        isLoading: false,
        pendingEmail: email,
        successMessage: res.message,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, forgotPasswordError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        forgotPasswordError: 'Password reset request failed. Please try again.',
      );
      return false;
    }
  }

  /// A6 — Reset Password
  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, clearResetPasswordError: true);
    try {
      final res = await _repository.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
        passwordConfirmation: passwordConfirmation,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        user: null,
        successMessage: res.message,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, resetPasswordError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        resetPasswordError: 'Password reset failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> _handleSocialLogin(
    Future<UserModel> Function() loginCall,
    String fallbackError,
  ) async {
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearLoginError: true);
    try {
      final user = await loginCall();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, loginError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, loginError: fallbackError);
      return false;
    }
  }

  /// Initiates device-level Google Sign-In and exchanges Google ID token directly with Supabase.
  Future<bool> signInWithGoogle() async {
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearLoginError: true);
    try {
      final googleAuth = _googleAuthService;
      final authResult = await googleAuth.authenticateWithGoogle();

      if (authResult.isCancelled) {
        // User cancelled Google account selection
        state = state.copyWith(isLoading: false);
        return false;
      }

      if (authResult.failureStage != null) {
        final errorMsg = authResult.errorMessage ?? 'Google Sign-In failed';
        state = state.copyWith(isLoading: false, loginError: errorMsg);
        return false;
      }

      final idToken = authResult.idToken ?? authResult.firebaseIdToken;
      if (idToken == null || idToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          loginError: 'Google Sign-In failed: Token was empty',
        );
        return false;
      }

      final user = await _repository.googleLogin(idToken);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isPendingVerification: false,
        user: user,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, loginError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loginError: 'Google sign in failed: $e',
      );
      return false;
    }
  }

  /// A8 — Google Sign In with an ID Token
  Future<bool> googleLogin(String googleIdToken) {
    return _handleSocialLogin(
      () => _repository.googleLogin(googleIdToken),
      'Google sign in failed. Please try again.',
    );
  }

  /// A9 — Apple Sign In (Disabled in Supabase-first architecture)
  Future<bool> appleLogin(String token) {
    state = state.copyWith(
      isLoading: false,
      loginError: 'Apple Sign-In is not supported in the Supabase-first MediCrate architecture.',
    );
    return Future.value(false);
  }

  /// Initiates device-level Apple Sign-In (Disabled in Supabase-first architecture)
  Future<bool> signInWithApple() async {
    state = state.copyWith(
      isLoading: false,
      loginError: 'Apple Sign-In is not supported in the Supabase-first MediCrate architecture.',
    );
    return false;
  }

  void _clearSessionState([String? errorMsg]) {
    try {
      ref.invalidate(activeProfileProvider);
      ref.invalidate(profilesListProvider);
    } catch (_) {}
    state = AuthState(
      isLoading: false,
      isAuthenticated: false,
      user: null,
      sessionError: errorMsg,
    );
  }

  /// A10 — Sign Out
  Future<void> signOut() async {
    if (state.isLoading && !state.isAuthenticated) return;
    state = state.copyWith(isLoading: true);
    try {
      await _googleAuthService.signOut();
      await _repository.signOut();
    } finally {
      _clearSessionState();
    }
  }

  /// Central handler when an unrecoverable 401 Unauthorized / token expiration occurs.
  Future<void> handleSessionExpired() async {
    try {
      await _repository.signOut();
    } finally {
      _clearSessionState('Your session has expired. Please sign in again.');
    }
  }
}
