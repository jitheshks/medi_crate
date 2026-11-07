import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../exceptions/app_exception.dart';

/// ApiErrorParser parses structured Laravel API responses and converts Dio exceptions
/// into predictable, strongly-typed [AppException] instances with user-friendly messages.
abstract class ApiErrorParser {
  /// Parses a [DioException] into an appropriate [AppException].
  static AppException parseDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiTimeoutException(
          'The connection is taking too long. Please try again.',
        );

      case DioExceptionType.badCertificate:
        return const NetworkException(
          "We couldn't establish a secure connection to MediVault. Please try again later.",
          code: 'BAD_CERTIFICATE',
        );

      case DioExceptionType.badResponse:
        final response = error.response;
        if (response == null) {
          return const ServerException(
            'MediVault is temporarily unavailable. Please try again later.',
          );
        }
        return parseResponse(response.statusCode ?? 500, response.data);

      case DioExceptionType.cancel:
        return const UnknownApiException('The request was cancelled.');

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        final underlying = error.error;
        if (underlying is AppException) {
          return underlying;
        }

        // Deep inspection of underlying network/socket/SSL exceptions
        if (underlying != null) {
          final errorStr = underlying.toString().toLowerCase();

          // 1. SSL/TLS Certificate & Handshake issues
          if (underlying is HandshakeException ||
              underlying is TlsException ||
              underlying is CertificateException ||
              errorStr.contains('handshake') ||
              errorStr.contains('certificate') ||
              errorStr.contains('certpathvalidatorexception') ||
              errorStr.contains('ssl') ||
              errorStr.contains('tls')) {
            return const NetworkException(
              "We couldn't establish a secure connection to MediVault. Please try again later.",
              code: 'SECURE_CONNECTION_ERROR',
            );
          }

          // 2. DNS & Host lookup resolution failures (No internet / DNS error)
          if (underlying is SocketException) {
            final osMsg = underlying.osError?.message.toLowerCase() ?? '';
            final osCode = underlying.osError?.errorCode;

            if (errorStr.contains('failed host lookup') ||
                errorStr.contains('no address associated with hostname') ||
                errorStr.contains('network is unreachable') ||
                errorStr.contains('network unreachable') ||
                errorStr.contains('no route to host') ||
                osMsg.contains('unreachable') ||
                osMsg.contains('no route to host') ||
                osCode == 101 ||
                osCode == 110) {
              return const NetworkException(
                'No internet connection. Please check your Wi-Fi or mobile data and try again.',
                code: 'NO_INTERNET',
              );
            }

            if (errorStr.contains('connection refused') ||
                osMsg.contains('connection refused') ||
                osCode == 111) {
              return const ServerException(
                'MediVault is temporarily unavailable. Please try again later.',
                code: 'CONNECTION_REFUSED',
              );
            }

            if (errorStr.contains('permission denied') ||
                osMsg.contains('permission denied') ||
                osCode == 13) {
              return const NetworkException(
                "Couldn't connect to MediVault. Please check your internet connection and try again.",
                code: 'PERMISSION_DENIED',
              );
            }
          }

          // 3. Timeout exceptions
          if (underlying is TimeoutException ||
              errorStr.contains('timed out') ||
              errorStr.contains('timeout')) {
            return const ApiTimeoutException(
              'The connection is taking too long. Please try again.',
            );
          }

          // 4. Format exceptions (malformed response body)
          if (underlying is FormatException) {
            return const MalformedResponseException(
              'Invalid response received from server.',
            );
          }

          // 5. Connection dropped mid-response (server/proxy aborted the
          //    stream after the socket was established). The device is online
          //    and the request reached the server, so this is a server-side
          //    failure — not a connectivity problem. Seen on the R6 attachment
          //    stream as `HttpException: Connection closed while receiving
          //    data`; classify it like a 5xx rather than "check your internet".
          if (underlying is HttpException &&
              (errorStr.contains('connection closed') ||
                  errorStr.contains('connection reset') ||
                  errorStr.contains('connection terminated'))) {
            return const ServerException(
              'MediVault is temporarily unavailable. Please try again later.',
              code: 'CONNECTION_CLOSED',
            );
          }
        }

        // Check error message if message contains specific network signals
        if (error.message != null && error.message!.isNotEmpty) {
          final msgLower = error.message!.toLowerCase();
          if (msgLower.contains('failed host lookup') ||
              msgLower.contains('no address associated with hostname') ||
              msgLower.contains('network is unreachable') ||
              msgLower.contains('no route to host')) {
            return const NetworkException(
              'No internet connection. Please check your Wi-Fi or mobile data and try again.',
              code: 'NO_INTERNET',
            );
          }
          if (msgLower.contains('connection refused')) {
            return const ServerException(
              'MediVault is temporarily unavailable. Please try again later.',
              code: 'CONNECTION_REFUSED',
            );
          }
          if (msgLower.contains('handshake') ||
              msgLower.contains('certificate') ||
              msgLower.contains('ssl') ||
              msgLower.contains('tls')) {
            return const NetworkException(
              "We couldn't establish a secure connection to MediVault. Please try again later.",
              code: 'SECURE_CONNECTION_ERROR',
            );
          }
          if (msgLower.contains('timed out') || msgLower.contains('timeout')) {
            return const ApiTimeoutException(
              'The connection is taking too long. Please try again.',
            );
          }
        }

        // Generic fallback connection failure
        return const NetworkException(
          "Couldn't connect to MediVault. Please check your internet connection and try again.",
        );
    }
  }

  /// Parses an HTTP status code and raw response data into a specific [AppException].
  static AppException parseResponse(int statusCode, dynamic responseData) {
    String message = '';
    Map<String, List<String>>? validationErrors;

    if (responseData is Map<String, dynamic>) {
      if (responseData['message'] is String) {
        message = responseData['message'] as String;
      }

      if (responseData['errors'] is Map) {
        final rawErrors = responseData['errors'] as Map;
        validationErrors = {};
        rawErrors.forEach((key, value) {
          if (value is List) {
            validationErrors![key.toString()] = value
                .map((e) => e.toString())
                .toList();
          } else if (value is String) {
            validationErrors![key.toString()] = [value];
          }
        });

        // If message is generic, synthesize a more descriptive message from first validation error
        if ((message.isEmpty || message == 'Validation failed') &&
            validationErrors.isNotEmpty) {
          final firstEntry = validationErrors.entries.first;
          if (firstEntry.value.isNotEmpty) {
            message = firstEntry.value.first;
          }
        }
      }
    } else if (responseData is String && responseData.isNotEmpty) {
      message = responseData;
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(
          message.isNotEmpty
              ? message
              : 'Bad request. Please verify your input.',
          errors: validationErrors,
        );

      case 401:
        return UnauthorizedException(
          message.isNotEmpty
              ? message
              : 'Incorrect email or password. Please check your login details.',
          errors: validationErrors,
        );

      case 403:
        return ForbiddenException(
          message.isNotEmpty
              ? message
              : 'You do not have permission to perform this action.',
          errors: validationErrors,
        );

      case 404:
        return NotFoundException(
          message.isNotEmpty ? message : 'Requested resource not found.',
          errors: validationErrors,
        );

      case 409:
        final errorCode = responseData is Map
            ? (responseData['error_code'] ?? responseData['code'] ?? '')
            : '';
        if (errorCode == 'RESOURCE_HAS_DEPENDENCIES' ||
            message.toLowerCase().contains('dependenc') ||
            message.toLowerCase().contains('referenced by other') ||
            message.toLowerCase().contains('linked records')) {
          return ResourceHasDependenciesException(
            message.isNotEmpty
                ? message
                : 'This resource cannot be deleted because other records depend on it.',
            errors: validationErrors,
          );
        }
        return ConflictException(
          message.isNotEmpty ? message : 'Email or resource already exists.',
          errors: validationErrors,
        );

      case 422:
        return ValidationException(
          message.isNotEmpty ? message : 'Validation failed.',
          errors: validationErrors,
        );

      case 429:
        final retryAfter = responseData is Map
            ? (responseData['retry_after'] ??
                  responseData['lockout_duration'] ??
                  responseData['wait_seconds'])
            : null;
        final durationMsg = retryAfter != null
            ? 'Too many attempts. Account temporarily locked. Please try again in $retryAfter seconds.'
            : (message.isNotEmpty
                  ? message
                  : 'Too many attempts. Account locked temporarily. Please try again in 60 seconds.');
        return TooManyRequestsException(durationMsg, errors: validationErrors);

      case 501:
        return FeatureUnavailableException(
          message.isNotEmpty
              ? message
              : 'This feature is currently being integrated and will be available soon.',
          errors: validationErrors,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message.isNotEmpty
              ? message
              : 'MediVault is temporarily unavailable. Please try again later.',
          statusCode: statusCode,
          errors: validationErrors,
        );

      default:
        return UnknownApiException(
          message.isNotEmpty
              ? message
              : 'An unexpected error occurred (HTTP $statusCode).',
          statusCode: statusCode,
          errors: validationErrors,
        );
    }
  }
}
