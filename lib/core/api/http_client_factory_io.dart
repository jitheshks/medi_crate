import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'api_constants.dart';
import 'ssl_security_context.dart';

/// IO implementation of HttpClientFactory that provisions HttpClients and IOHttpClientAdapters
/// configured with the augmented SslSecurityContext.
class HttpClientFactory {
  /// Creates a configured HttpClient using the augmented SslSecurityContext.
  static HttpClient createHttpClient({
    Duration connectTimeout = ApiConstants.connectTimeout,
    Duration idleTimeout = const Duration(seconds: 15),
  }) {
    final client = HttpClient(context: SslSecurityContext.context);
    client.connectionTimeout = connectTimeout;
    client.idleTimeout = idleTimeout;
    return client;
  }

  /// Creates a configured HttpClientAdapter for Dio.
  /// If [customAdapter] is provided (e.g. mock adapter in tests), it is returned directly.
  static HttpClientAdapter createAdapter({
    HttpClientAdapter? customAdapter,
    Duration connectTimeout = ApiConstants.connectTimeout,
    Duration idleTimeout = const Duration(seconds: 15),
  }) {
    if (customAdapter != null) {
      return customAdapter;
    }
    return IOHttpClientAdapter(
      createHttpClient: () => createHttpClient(
        connectTimeout: connectTimeout,
        idleTimeout: idleTimeout,
      ),
    );
  }
}
