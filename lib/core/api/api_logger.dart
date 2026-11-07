import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ApiLogger provides sanitized HTTP traffic logging for debugging while strictly
/// guarding sensitive authentication credentials, tokens, OTPs, and health data.
class ApiLogger extends Interceptor {
  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'x-api-key',
    'cookie',
    'set-cookie',
  };

  static const Set<String> _sensitiveBodyKeys = {
    'password',
    'password_confirmation',
    'otp',
    'access_token',
    'refresh_token',
    'firebase_id_token',
    'token',
    'code',
  };

  final Map<int, Stopwatch> _timers = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _timers[options.hashCode] = Stopwatch()..start();
    final sanitizedHeaders = _sanitizeMap(options.headers, isHeader: true);
    final sanitizedData = _sanitizeBody(options.data);
    final uriStr = options.uri.hasQuery
        ? '${options.uri.host}${options.uri.path}?${options.uri.query}'
        : '${options.uri.host}${options.uri.path}';

    final logMsg = '🌐 [HTTP REQUEST] ${options.method.toUpperCase()} $uriStr';
    debugPrint(logMsg);

    if (!kReleaseMode && sanitizedData != null) {
      try {
        final prettyJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(sanitizedData);
        debugPrint('   ↳ [Request Body]:\n$prettyJson');
      } catch (_) {
        debugPrint('   ↳ [Request Body]: $sanitizedData');
      }
    }

    developer.log(
      logMsg,
      name: 'MediCrate.Api',
      error: {
        'headers': sanitizedHeaders,
        'body': sanitizedData,
        if (options.uri.hasQuery) 'query': options.queryParameters,
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final timer = _timers.remove(response.requestOptions.hashCode);
    final durationMs = timer?.elapsedMilliseconds ?? 0;
    final sanitizedData = _sanitizeBody(response.data);
    final uriStr = response.requestOptions.uri.hasQuery
        ? '${response.requestOptions.uri.host}${response.requestOptions.uri.path}?${response.requestOptions.uri.query}'
        : '${response.requestOptions.uri.host}${response.requestOptions.uri.path}';

    final logMsg =
        '✅ [HTTP RESPONSE] ${response.requestOptions.method.toUpperCase()} '
        '$uriStr '
        '| Status: ${response.statusCode} | Duration: ${durationMs}ms';
    debugPrint(logMsg);

    developer.log(
      logMsg,
      name: 'MediCrate.Api',
      error: sanitizedData != null ? {'body': sanitizedData} : null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final timer = _timers.remove(err.requestOptions.hashCode);
    final durationMs = timer?.elapsedMilliseconds ?? 0;
    final sanitizedData = _sanitizeBody(err.response?.data);
    final underlying = err.error;

    final String host = err.requestOptions.uri.host;
    final String path = err.requestOptions.uri.path;
    final String method = err.requestOptions.method.toUpperCase();
    final String uriStr = err.requestOptions.uri.hasQuery
        ? '$host$path?${err.requestOptions.uri.query}'
        : '$host$path';

    final errorDetails = <String, dynamic>{
      'host': host,
      'path': path,
      'method': method,
      'query': err.requestOptions.queryParameters,
      'dioExceptionType': err.type.name,
      'dioMessage': err.message,
      'durationMs': durationMs,
      'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      if (underlying != null) ...{
        'underlyingType': underlying.runtimeType.toString(),
        'underlyingError': underlying.toString(),
      },
      if (underlying is SocketException) ...{
        'socketAddress': underlying.address?.address,
        'socketPort': underlying.port,
        if (underlying.osError != null) ...{
          'osErrorCode': underlying.osError!.errorCode,
          'osErrorMessage': underlying.osError!.message,
        },
      },
      if (underlying is HandshakeException ||
          underlying is TlsException ||
          underlying is CertificateException) ...{
        'tlsExceptionType': underlying.runtimeType.toString(),
        'tlsErrorMessage': underlying.toString(),
      },
      'responseStatus': err.response?.statusCode,
      'response': sanitizedData,
    };

    final logSummary =
        '❌ [HTTP ERROR] $method $uriStr '
        '| Status: ${err.response?.statusCode ?? "N/A"} '
        '| DioType: ${err.type.name} '
        '| Underlying: ${underlying?.runtimeType ?? "none"} (${underlying ?? err.message}) '
        '| OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion} '
        '| Duration: ${durationMs}ms';

    debugPrint(logSummary);
    if (!kReleaseMode && sanitizedData != null) {
      try {
        final prettyErrBody = const JsonEncoder.withIndent(
          '  ',
        ).convert(sanitizedData);
        debugPrint('   ↳ [Response Error Body]:\n$prettyErrBody');
      } catch (_) {
        debugPrint('   ↳ [Response Error Body]: $sanitizedData');
      }
    }
    if (underlying is SocketException && underlying.osError != null) {
      debugPrint(
        '   ↳ SocketException OS Error: errno=${underlying.osError!.errorCode}, message="${underlying.osError!.message}"',
      );
    }
    if (underlying is HandshakeException || underlying is TlsException) {
      debugPrint('   ↳ TLS/Handshake details: $underlying');
    }

    developer.log(logSummary, name: 'MediCrate.Api', error: errorDetails);
    handler.next(err);
  }

  dynamic _sanitizeBody(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return _sanitizeMap(data);
    }
    if (data is List) {
      return data.map(_sanitizeBody).toList();
    }
    return data;
  }

  Map<String, dynamic> _sanitizeMap(Map map, {bool isHeader = false}) {
    final Map<String, dynamic> sanitized = {};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final lowerKey = key.toLowerCase();
      if (isHeader && _sensitiveHeaders.contains(lowerKey)) {
        sanitized[key] = '[REDACTED]';
      } else if (!isHeader && _sensitiveBodyKeys.contains(lowerKey)) {
        sanitized[key] = '[REDACTED]';
      } else if (entry.value is Map) {
        sanitized[key] = _sanitizeMap(entry.value as Map, isHeader: isHeader);
      } else if (entry.value is List) {
        sanitized[key] = (entry.value as List).map(_sanitizeBody).toList();
      } else {
        sanitized[key] = entry.value;
      }
    }
    return sanitized;
  }
}
