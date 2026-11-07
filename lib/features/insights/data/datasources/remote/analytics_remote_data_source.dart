import 'package:dio/dio.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';

/// AnalyticsRemoteDataSource communicates with the backend REST API `/api/v1/analytics` endpoint (AN1).
///
/// NOTE: The backend Analytics API serves as an optional/secondary server-side representation.
/// The Flutter on-device HealthVaultScoreCalculator and VitalStatusCalculator remain authoritative.
class AnalyticsRemoteDataSource {
  final ApiClient apiClient;

  AnalyticsRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// AN1: GET /analytics?profile_id={id} — Fetches server-calculated analytics summary.
  Future<Map<String, dynamic>> fetchAnalytics({required int profileId}) async {
    try {
      final response = await _dio.get(
        ApiConstants.analytics,
        queryParameters: {'profile_id': profileId},
      );
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
          return responseData;
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      throw ApiErrorParser.parseResponse(
        response.statusCode ?? 400,
        responseData,
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
