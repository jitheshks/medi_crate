import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import 'api_constants.dart';
import 'api_logger.dart';
import 'dio_interceptor.dart';
import 'http_client_factory.dart';

/// ApiClient configures the centralized Dio client for MediVault REST API operations
/// with automated API Key injection, Bearer Token authentication, and secure logging.
class ApiClient {
  late final Dio _dio;
  final SecureStorageService secureStorage;

  ApiClient({
    required this.secureStorage,
    String baseUrl = ApiConstants.baseUrl,
    String? apiKey,
    HttpClientAdapter? customAdapter,
    Dio? customDio,
    void Function()? onSessionExpired,
  }) {
    if (customDio != null) {
      _dio = customDio;
      return;
    }

    final effectiveApiKey = apiKey ?? ApiConstants.apiKey;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ApiConstants.apiKeyHeader: effectiveApiKey,
        },
      ),
    );

    _dio.httpClientAdapter = HttpClientFactory.createAdapter(
      customAdapter: customAdapter,
      connectTimeout: ApiConstants.connectTimeout,
    );

    _dio.interceptors.addAll([
      AuthInterceptor(
        secureStorage: secureStorage,
        apiKey: effectiveApiKey,
        baseUrl: baseUrl,
        customAdapter: customAdapter,
        onSessionExpired: onSessionExpired,
      ),
      ApiLogger(),
    ]);
  }

  Dio get dio => _dio;
}
