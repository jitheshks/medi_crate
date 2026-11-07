import '../../data/models/user_model.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool isPendingVerification;
  final String? pendingEmail;
  final UserModel? user;
  final String? loginError;
  final String? signupError;
  final String? forgotPasswordError;
  final String? resetPasswordError;
  final String? otpError;
  final String? sessionError;
  final String? successMessage;

  /// Backwards-compatible generic error getter
  String? get error =>
      loginError ??
      signupError ??
      forgotPasswordError ??
      resetPasswordError ??
      otpError ??
      sessionError;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.isPendingVerification = false,
    this.pendingEmail,
    this.user,
    this.loginError,
    this.signupError,
    this.forgotPasswordError,
    this.resetPasswordError,
    this.otpError,
    this.sessionError,
    this.successMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? isPendingVerification,
    String? pendingEmail,
    UserModel? user,
    String? loginError,
    String? signupError,
    String? forgotPasswordError,
    String? resetPasswordError,
    String? otpError,
    String? sessionError,
    String? error, // Legacy support
    String? successMessage,
    bool clearLoginError = false,
    bool clearSignupError = false,
    bool clearForgotPasswordError = false,
    bool clearResetPasswordError = false,
    bool clearOtpError = false,
    bool clearSessionError = false,
    bool clearAllErrors = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isPendingVerification:
          isPendingVerification ?? this.isPendingVerification,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      user: user ?? this.user,
      loginError: (clearAllErrors || clearError || clearLoginError)
          ? null
          : (loginError ?? error ?? this.loginError),
      signupError: (clearAllErrors || clearError || clearSignupError)
          ? null
          : (signupError ?? this.signupError),
      forgotPasswordError:
          (clearAllErrors || clearError || clearForgotPasswordError)
          ? null
          : (forgotPasswordError ?? this.forgotPasswordError),
      resetPasswordError:
          (clearAllErrors || clearError || clearResetPasswordError)
          ? null
          : (resetPasswordError ?? this.resetPasswordError),
      otpError: (clearAllErrors || clearError || clearOtpError)
          ? null
          : (otpError ?? this.otpError),
      sessionError: (clearAllErrors || clearError || clearSessionError)
          ? null
          : (sessionError ?? this.sessionError),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          isAuthenticated == other.isAuthenticated &&
          isPendingVerification == other.isPendingVerification &&
          pendingEmail == other.pendingEmail &&
          user == other.user &&
          loginError == other.loginError &&
          signupError == other.signupError &&
          forgotPasswordError == other.forgotPasswordError &&
          resetPasswordError == other.resetPasswordError &&
          otpError == other.otpError &&
          sessionError == other.sessionError &&
          successMessage == other.successMessage;

  @override
  int get hashCode => Object.hash(
    isLoading,
    isAuthenticated,
    isPendingVerification,
    pendingEmail,
    user,
    loginError,
    signupError,
    forgotPasswordError,
    resetPasswordError,
    otpError,
    sessionError,
    successMessage,
  );
}
