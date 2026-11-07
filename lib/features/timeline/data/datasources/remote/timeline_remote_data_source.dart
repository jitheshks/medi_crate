import 'package:dio/dio.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';

/// TimelineRemoteDataSource communicates with the backend REST API `/api/v1/timeline` endpoint (T1).
///
/// NOTE: The backend Timeline API serves as an optional/secondary server-side representation.
/// The Flutter on-device TimelineRepository and local event builders remain authoritative.
class TimelineRemoteDataSource {
  final ApiClient apiClient;

  TimelineRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// T1: GET /timeline — Fetches server-aggregated timeline feed.
  Future<List<Map<String, dynamic>>> fetchTimeline({
    required int profileId,
    String? type,
    String? from,
    String? to,
    String? sort,
    int? page,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'profile_id': profileId,
        'limit': limit,
      };
      if (type != null && type.trim().isNotEmpty) {
        queryParams['type'] = type.trim();
      }
      if (from != null && from.trim().isNotEmpty) {
        queryParams['from'] = from.trim();
      }
      if (to != null && to.trim().isNotEmpty) {
        queryParams['to'] = to.trim();
      }
      if (sort != null && sort.trim().isNotEmpty) {
        queryParams['sort'] = sort.trim();
      }
      if (page != null && page > 0) {
        queryParams['page'] = page;
      }

      final response = await _dio.get(
        ApiConstants.timeline,
        queryParameters: queryParams,
      );
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['timeline'] is List) {
              final rawList = data['timeline'] as List;
              return rawList
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
            if (data['events'] is List) {
              final rawList = data['events'] as List;
              return rawList
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
          } else if (data is List) {
            return data
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          }
          return [];
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      } else if (responseData is List) {
        return responseData
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
