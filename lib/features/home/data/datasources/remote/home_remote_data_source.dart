import 'package:dio/dio.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';

/// HomeRemoteDataSource communicates with the backend REST API `/api/v1/dashboard` endpoint (DB1).
///
/// NOTE: The backend Dashboard API serves as an optional/secondary server-side representation.
/// The Flutter on-device HomeRepository and local Hive caches remain authoritative.
class HomeRemoteDataSource {
  final ApiClient apiClient;

  HomeRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// DB1: GET /dashboard?profile_id={id} — Fetches server-aggregated dashboard summary.
  Future<Map<String, dynamic>> fetchDashboard({required int profileId}) async {
    try {
      final response = await _dio.get(
        ApiConstants.dashboard,
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
