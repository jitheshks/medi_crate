import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';

/// VitalsRemoteDataSource interacts with Laravel backend REST API `/api/v1/vitals` endpoints (V1 - V5).
class VitalsRemoteDataSource {
  final ApiClient apiClient;

  VitalsRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// V1: POST /vitals — Records a new vital measurement for a profile.
  Future<Map<String, dynamic>> addVital(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.vitals, data: data);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['vital'] is Map) {
              return Map<String, dynamic>.from(resData['vital'] as Map);
            }
            if (resData['measurement'] is Map) {
              return Map<String, dynamic>.from(resData['measurement'] as Map);
            }
            return resData;
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

  /// V2: GET /vitals — Lists vital readings for a profile with optional filtering.
  Future<List<Map<String, dynamic>>> fetchVitals({
    required int profileId,
    String? type,
    String? dateFrom,
    String? dateTo,
    bool? latestPerType,
    int limit = 50,
    void Function(int total)? onTotal,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'profile_id': profileId,
        'limit': limit,
      };
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (dateFrom != null && dateFrom.isNotEmpty) {
        queryParams['date_from'] = dateFrom;
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        queryParams['date_to'] = dateTo;
      }
      if (latestPerType != null) {
        queryParams['latest_per_type'] = latestPerType;
      }

      final response = await _dio.get(
        ApiConstants.vitals,
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
            reportListTotal(data, onTotal);
            if (data['vitals'] is List) {
              final rawList = data['vitals'] as List;
              return rawList
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
            if (data['measurements'] is List) {
              final rawList = data['measurements'] as List;
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

  /// V3: GET /vitals/{id} — Retrieves a single vital measurement by ID.
  Future<Map<String, dynamic>> getVital(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.vital(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['vital'] is Map) {
              return Map<String, dynamic>.from(data['vital'] as Map);
            }
            if (data['measurement'] is Map) {
              return Map<String, dynamic>.from(data['measurement'] as Map);
            }
            return data;
          }
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

  /// V4: PUT /vitals/{id} — Updates an existing vital measurement.
  /// BMI readings only allow editing notes; value/recorded_at are locked.
  Future<Map<String, dynamic>> updateVital(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      Response response;
      try {
        response = await _dio.put(ApiConstants.vital(id), data: data);
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 405) {
          response = await _dio.post(ApiConstants.vital(id), data: data);
        } else {
          rethrow;
        }
      }

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['vital'] is Map) {
              return Map<String, dynamic>.from(resData['vital'] as Map);
            }
            if (resData['measurement'] is Map) {
              return Map<String, dynamic>.from(resData['measurement'] as Map);
            }
            return resData;
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

  /// V5: DELETE /vitals/{id} — Deletes a vital reading.
  Future<void> deleteVital(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.vital(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 204) {
          return;
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
