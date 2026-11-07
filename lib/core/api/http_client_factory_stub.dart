import 'package:dio/dio.dart';

import 'api_constants.dart';

/// Stub implementation of HttpClientFactory.
class HttpClientFactory {
  static dynamic createHttpClient({
    Duration connectTimeout = ApiConstants.connectTimeout,
    Duration idleTimeout = const Duration(seconds: 15),
  }) => null;

  static HttpClientAdapter createAdapter({
    HttpClientAdapter? customAdapter,
    Duration connectTimeout = ApiConstants.connectTimeout,
    Duration idleTimeout = const Duration(seconds: 15),
  }) {
    if (customAdapter != null) return customAdapter;
    throw UnsupportedError('Platform not supported for HttpClientAdapter');
  }
}
