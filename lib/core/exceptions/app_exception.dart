/// Base exception class for all MediCrate application errors.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Map<String, List<String>>? errors;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.errors,
    this.cause,
    this.stackTrace,
  });

  bool get isNetworkError =>
      this is NetworkException || this is ApiTimeoutException;
  bool get isAuthError => this is UnauthorizedException;
  bool get isForbidden => this is ForbiddenException;
  bool get isNotFound => this is NotFoundException;
  bool get isValidationError => this is ValidationException;
  bool get isRateLimited => this is TooManyRequestsException;
  bool get isServerError => this is ServerException;
  bool get isFeatureUnavailable => this is FeatureUnavailableException;
  bool get isMalformed => this is MalformedResponseException;

  /// User-friendly message suitable for presentation widgets.
  String get userFriendlyMessage {
    if (message.isNotEmpty) {
      return message;
    }
    return 'An unexpected error occurred. Please try again.';
  }

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return '$message: $errors';
    }
    return message;
  }
}

/// Thrown when device lacks network connectivity or socket connection fails.
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code = 'NETWORK_ERROR',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when an HTTP request or connection times out.
class ApiTimeoutException extends AppException {
  const ApiTimeoutException(
    super.message, {
    super.code = 'TIMEOUT_ERROR',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 5xx internal server errors.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException(
    super.message, {
    super.code = 'SERVER_ERROR',
    this.statusCode,
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 401 Unauthorized responses (invalid credentials, expired/invalid token).
class UnauthorizedException extends AppException {
  const UnauthorizedException(
    super.message, {
    super.code = 'UNAUTHORIZED',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 403 Forbidden responses (insufficient permissions, access denied).
class ForbiddenException extends AppException {
  const ForbiddenException(
    super.message, {
    super.code = 'FORBIDDEN',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 400 Bad Request responses (invalid/expired OTP, malformed requests).
class BadRequestException extends AppException {
  const BadRequestException(
    super.message, {
    super.code = 'BAD_REQUEST',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 404 Not Found responses (e.g. no OTP found for this email, missing record).
class NotFoundException extends AppException {
  const NotFoundException(
    super.message, {
    super.code = 'NOT_FOUND',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 409 Conflict responses (e.g. email already registered).
class ConflictException extends AppException {
  const ConflictException(
    super.message, {
    super.code = 'CONFLICT',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 409 RESOURCE_HAS_DEPENDENCIES when deletion is blocked due to linked records.
class ResourceHasDependenciesException extends ConflictException {
  final Map<String, int>? dependencyCounts;

  const ResourceHasDependenciesException(
    super.message, {
    super.code = 'RESOURCE_HAS_DEPENDENCIES',
    this.dependencyCounts,
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 422 Unprocessable Entity or client validation failures.
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.code = 'VALIDATION_ERROR',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown on 429 Too Many Requests / Lockout responses.
class TooManyRequestsException extends AppException {
  final int? lockoutMinutes;

  const TooManyRequestsException(
    super.message, {
    super.code = 'TOO_MANY_REQUESTS',
    this.lockoutMinutes,
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when an API module/endpoint is not yet implemented or temporarily unavailable.
class FeatureUnavailableException extends AppException {
  const FeatureUnavailableException(
    super.message, {
    super.code = 'FEATURE_UNAVAILABLE',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when the API response structure is unexpected or cannot be parsed.
class MalformedResponseException extends AppException {
  const MalformedResponseException(
    super.message, {
    super.code = 'MALFORMED_RESPONSE',
    super.errors,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown for any unhandled or unrecognized API response status.
class UnknownApiException extends AppException {
  final int? statusCode;

  const UnknownApiException(
    super.message, {
    super.code = 'UNKNOWN_API_ERROR',
    this.statusCode,
    super.errors,
    super.cause,
    super.stackTrace,
  });
}
