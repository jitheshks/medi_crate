import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/apple_auth_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref? _ref;
  final GoogleAuthService? _googleAuthService;
  final AppleAuthService? _appleAuthService;
  Future<void>? _initialSessionFuture;

  AuthNotifier(
    this._repository, [
    this._ref,
    this._googleAuthService,
    this._appleAuthService,
  ]) : super(const AuthState()) {
    _initialSessionFuture = checkInitialSession();
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

  /// Initiates device-level Google Sign-In and exchanges Firebase ID token with MediVault A8 endpoint.
  Future<bool> signInWithGoogle() async {
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearLoginError: true);
    try {
      final googleAuth = _googleAuthService ?? GoogleAuthService();
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

      final firebaseIdToken = authResult.firebaseIdToken;
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          loginError: 'Google Sign-In failed [Stage C]: Token was empty',
        );
        return false;
      }

      final user = await _repository.googleLogin(firebaseIdToken);
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

  /// A8 — Google Sign In with a pre-acquired Firebase ID Token
  Future<bool> googleLogin(String firebaseIdToken) {
    return _handleSocialLogin(
      () => _repository.googleLogin(firebaseIdToken),
      'Google sign in failed. Please try again.',
    );
  }

  /// A9 — Apple Sign In
  Future<bool> appleLogin(String firebaseIdToken) {
    return _handleSocialLogin(
      () => _repository.appleLogin(firebaseIdToken),
      'Apple sign in failed. Please try again.',
    );
  }

  /// Initiates device-level Apple Sign-In and exchanges Firebase ID token
  /// with MediVault A9 endpoint — mirrors signInWithGoogle().
  Future<bool> signInWithApple() async {
    debugPrint('[AppleAuth] AuthNotifier.signInWithApple() invoked');
    await _initialSessionFuture;
    state = state.copyWith(isLoading: true, clearLoginError: true);
    try {
      final appleAuth = _appleAuthService ?? AppleAuthService();
      final authResult = await appleAuth.authenticateWithApple();

      if (authResult.isCancelled) {
        // User dismissed the Apple authorization sheet — no error shown
        state = state.copyWith(isLoading: false);
        return false;
      }

      if (authResult.failureStage != null) {
        // AppleAuthService already logged the failing stage/errorType.
        final errorMsg = authResult.errorMessage ?? 'Apple Sign-In failed';
        state = state.copyWith(isLoading: false, loginError: errorMsg);
        return false;
      }

      final firebaseIdToken = authResult.firebaseIdToken;
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          loginError: 'Apple Sign-In failed [Stage C]: Token was empty',
        );
        return false;
      }

      debugPrint('[AppleAuth] Calling backend appleLogin()');
      final user = await _repository.appleLogin(firebaseIdToken);
      debugPrint('[AppleAuth] Backend Apple login succeeded');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isPendingVerification: false,
        user: user,
      );
      return true;
    } on AppException catch (e) {
      debugPrint('[AppleAuth] FAILED stage=D_BACKEND errorType=AppException');
      state = state.copyWith(isLoading: false, loginError: e.message);
      return false;
    } catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=D_BACKEND errorType=${e.runtimeType}',
      );
      state = state.copyWith(
        isLoading: false,
        loginError: 'Apple sign in failed: $e',
      );
      return false;
    }
  }

  void _clearSessionState([String? errorMsg]) {
    if (_ref != null) {
      try {
        _ref.invalidate(activeProfileProvider);
        _ref.invalidate(profilesListProvider);
      } catch (_) {}
    }
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
      if (_googleAuthService != null) {
        await _googleAuthService.signOut();
      }
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
