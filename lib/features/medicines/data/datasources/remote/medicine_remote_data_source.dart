import 'package:dio/dio.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';

/// MedicineRemoteDataSource communicates with the Laravel backend REST API `/api/v1/medicines` endpoints (M1 - M5).
class MedicineRemoteDataSource {
  final ApiClient apiClient;

  MedicineRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// M1: GET /medicines — Fetches medicines for a profile with optional filters.
  Future<List<Map<String, dynamic>>> fetchMedicines({
    required int profileId,
    String? consultationId,
    String? search,
    String? status, // 'active' | 'completed'
    String? sort, // 'name_asc' | 'name_desc' | 'start_date_asc'
    int limit = 50,
    void Function(int total)? onTotal,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'profile_id': profileId,
        'limit': limit,
      };
      if (consultationId != null && consultationId.isNotEmpty) {
        queryParams['consultation_id'] = consultationId;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final response = await _dio.get(
        ApiConstants.medicines,
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
            if (data['medicines'] is List) {
              final rawList = data['medicines'] as List;
              return rawList
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            }
          } else if (data is List) {
            return data
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
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
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// M2: POST /medicines — Creates a new medicine course record.
  Future<Map<String, dynamic>> addMedicine(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.medicines, data: data);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['medicine'] is Map) {
              return Map<String, dynamic>.from(resData['medicine'] as Map);
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

  /// M3: GET /medicines/{id} — Fetches a single medicine detail by ID.
  Future<Map<String, dynamic>> getMedicine(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.medicine(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['medicine'] is Map) {
              return Map<String, dynamic>.from(data['medicine'] as Map);
            }
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

  /// M4: PUT /medicines/{id} — Updates an existing medicine record.
  Future<Map<String, dynamic>> updateMedicine(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(ApiConstants.medicine(id), data: data);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['medicine'] is Map) {
              return Map<String, dynamic>.from(resData['medicine'] as Map);
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

  /// M5: DELETE /medicines/{id} — Deletes a medicine record.
  Future<bool> deleteMedicine(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.medicine(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          return true;
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
