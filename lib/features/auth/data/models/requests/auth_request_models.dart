library;

/// Request models for MediCrate Authentication APIs (A1–A9).
/// All field names strictly conform to the Backend API Contract v1.0.

/// A1: Sign Up Request DTO
class SignUpRequest {
  final String name;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String dob; // Format: YYYY-MM-DD
  final String? gender; // 'male' | 'female' | 'other' (optional)

  const SignUpRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.dob,
    this.gender,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'dob': dob,
    };
    if (gender != null && gender!.trim().isNotEmpty) {
      map['gender'] = gender!.trim().toLowerCase();
    }
    return map;
  }
}

/// A2: Verify Email (OTP) Request DTO
class VerifyEmailRequest {
  final String email;
  final String otp; // 4-digit numeric string

  const VerifyEmailRequest({required this.email, required this.otp});

  Map<String, dynamic> toJson() {
    return {'email': email, 'otp': otp};
  }
}

/// A3: Resend OTP Request DTO
class ResendOtpRequest {
  final String email;
  final String type; // 'signup' | 'reset_password' | 'change_email'

  const ResendOtpRequest({required this.email, required this.type});

  Map<String, dynamic> toJson() {
    return {'email': email, 'type': type};
  }
}

/// A4: Login Request DTO
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password};
  }
}

/// A5: Forgot Password Request DTO
class ForgotPasswordRequest {
  final String email;

  const ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}

/// A6: Reset Password Request DTO
class ResetPasswordRequest {
  final String email;
  final String otp; // 4-digit numeric string
  final String password;
  final String passwordConfirmation;

  const ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.password,
    required this.passwordConfirmation,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'otp': otp,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
  }
}

/// A7: Refresh Access Token Request DTO
class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() {
    return {'refresh_token': refreshToken};
  }
}

/// A8 & A9: Google / Apple Social Login Request DTO
class SocialLoginRequest {
  final String firebaseIdToken;

  const SocialLoginRequest({required this.firebaseIdToken});

  Map<String, dynamic> toJson() {
    return {'firebase_id_token': firebaseIdToken};
  }
}
