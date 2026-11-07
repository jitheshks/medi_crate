library;

/// Response models for MediVault Authentication APIs (A1–A10).
/// Strictly mapped from the Backend API Contract v1.0 specifications.

/// Standard Top-Level API Envelope wrapper
class ApiEnvelope<T> {
  final String status; // 'success' | 'error' | 'pending_verification'
  final String? message;
  final T? data;
  final Map<String, List<String>>? errors;

  const ApiEnvelope({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  bool get isSuccess => status == 'success';
  bool get isPendingVerification => status == 'pending_verification';
  bool get isError => status == 'error';
}

/// A1: Sign Up Response Data payload
class SignUpResponseData {
  final int userId;
  final String message;

  const SignUpResponseData({required this.userId, required this.message});

  factory SignUpResponseData.fromJson(Map<String, dynamic> json) {
    return SignUpResponseData(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      message:
          json['message'] as String? ?? 'Verification code sent to your email',
    );
  }
}

/// A2, A4, A7, A8, A9: Auth Session & Tokens Response Data payload
class AuthTokensResponseData {
  final int? userId;
  final String? name;
  final String? email;
  final String accessToken;
  final String refreshToken;
  final String? message;

  const AuthTokensResponseData({
    this.userId,
    this.name,
    this.email,
    required this.accessToken,
    required this.refreshToken,
    this.message,
  });

  factory AuthTokensResponseData.fromJson(Map<String, dynamic> json) {
    return AuthTokensResponseData(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? ''),
      name: json['name'] as String?,
      email: json['email'] as String?,
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      message: json['message'] as String?,
    );
  }
}

/// A3, A5, A6, A10: Message-only Response Data payload
class MessageResponseData {
  final String message;

  const MessageResponseData({required this.message});

  factory MessageResponseData.fromJson(Map<String, dynamic> json) {
    return MessageResponseData(message: json['message'] as String? ?? '');
  }
}

/// A1, A4: Pending Verification Response Data payload
class PendingVerificationResponseData {
  final int? userId;
  final String message;

  const PendingVerificationResponseData({this.userId, required this.message});

  factory PendingVerificationResponseData.fromJson(Map<String, dynamic> json) {
    return PendingVerificationResponseData(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? ''),
      message:
          json['message'] as String? ??
          'Email not verified. OTP resent successfully.',
    );
  }
}
