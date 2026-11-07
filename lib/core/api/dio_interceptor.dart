import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import 'api_constants.dart';
import 'http_client_factory.dart';

/// AuthInterceptor manages static API Key header injection, Bearer Token injection,
/// and automatic token refresh via A7 on 401 Unauthorized responses.
class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService secureStorage;
  final String apiKey;
  final String baseUrl;
  final HttpClientAdapter? customAdapter;
  final void Function()? onSessionExpired;

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.secureStorage,
    String? apiKey,
    this.baseUrl = ApiConstants.baseUrl,
    this.customAdapter,
    this.onSessionExpired,
  }) : apiKey = apiKey ?? ApiConstants.apiKey;

  static bool _isPublicAuthEndpoint(String path) {
    return path.contains(ApiConstants.signup) ||
        path.contains(ApiConstants.verifyEmail) ||
        path.contains(ApiConstants.resendOtp) ||
        path.contains(ApiConstants.login) ||
        path.contains(ApiConstants.forgotPassword) ||
        path.contains(ApiConstants.resetPassword) ||
        path.contains(ApiConstants.refreshToken) ||
        path.contains(ApiConstants.googleLogin) ||
        path.contains(ApiConstants.appleLogin);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Inject static x-api-key required on ALL endpoints
    if (!options.headers.containsKey(ApiConstants.apiKeyHeader)) {
      options.headers[ApiConstants.apiKeyHeader] = apiKey;
    }

    // 2. Inject Authorization Bearer token on protected endpoints if present
    if (!_isPublicAuthEndpoint(options.path) &&
        !options.headers.containsKey('Authorization')) {
      try {
        final token = await secureStorage.getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // Defensive error containment: if reading secure storage fails,
        // do not abort the request; proceed so server can return 401.
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final path = err.requestOptions.path;

    // Check if error is 401 and request is not already a public auth endpoint
    if (response?.statusCode == 401 && !_isPublicAuthEndpoint(path)) {
      final refreshResult = await _performTokenRefresh();
      final newAccessToken = refreshResult.token;
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        // Retry original request with newly rotated access token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        try {
          final client = Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: ApiConstants.connectTimeout,
              receiveTimeout: ApiConstants.receiveTimeout,
            ),
          );
          client.httpClientAdapter = HttpClientFactory.createAdapter(
            customAdapter: customAdapter,
            connectTimeout: ApiConstants.connectTimeout,
          );
          final retryResponse = await client.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      } else if (refreshResult.isPermanentAuthError) {
        // Refresh failed with explicit auth rejection: clear invalid tokens and notify session expired
        await secureStorage.clearAuthToken();
        onSessionExpired?.call();
      }
    }

    handler.next(err);
  }

  Future<({String? token, bool isPermanentAuthError})>
  _performTokenRefresh() async {
    if (_isRefreshing) {
      final token = await _refreshCompleter?.future;
      return (token: token, isPermanentAuthError: false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter?.complete(null);
        return (token: null, isPermanentAuthError: true);
      }

      // Execute silent refresh request on independent Dio instance to prevent interceptor loops
      final refreshClient = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            ApiConstants.apiKeyHeader: apiKey,
          },
        ),
      );
      refreshClient.httpClientAdapter = HttpClientFactory.createAdapter(
        customAdapter: customAdapter,
        connectTimeout: ApiConstants.connectTimeout,
      );

      final response = await refreshClient.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final newAccessToken = data?['access_token'] as String?;
        final newRefreshToken = data?['refresh_token'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await secureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          _refreshCompleter?.complete(newAccessToken);
          return (token: newAccessToken, isPermanentAuthError: false);
        } else if (newAccessToken != null) {
          await secureStorage.saveAuthToken(newAccessToken);
          _refreshCompleter?.complete(newAccessToken);
          return (token: newAccessToken, isPermanentAuthError: false);
        }
      }

      _refreshCompleter?.complete(null);
      return (token: null, isPermanentAuthError: true);
    } on DioException catch (dioErr) {
      _refreshCompleter?.complete(null);
      final status = dioErr.response?.statusCode;
      final isAuthRejection =
          status == 401 || status == 400 || status == 403 || status == 422;
      return (token: null, isPermanentAuthError: isAuthRejection);
    } catch (_) {
      _refreshCompleter?.complete(null);
      return (token: null, isPermanentAuthError: false);
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}
