import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';

/// DoctorRemoteDataSource communicates with the backend REST API `/api/v1/doctors` endpoints (D1 - D5).
class DoctorRemoteDataSource {
  final ApiClient apiClient;

  DoctorRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// D1: GET /doctors — Fetches doctors directory for the authenticated user / active profile.
  Future<List<Map<String, dynamic>>> fetchDoctors({
    required int profileId,
    String? search,
    String? specialty,
    int? hospitalId,
    int limit = 20,
    void Function(int total)? onTotal,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.doctors,
        queryParameters: {
          'profile_id': profileId,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (specialty != null && specialty.trim().isNotEmpty)
            'specialty': specialty.trim(),
          'hospital_id': ?hospitalId,
        },
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
            if (data['doctors'] is List) {
              final rawList = data['doctors'] as List;
              return rawList
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
            if (data['doctor_list'] is List) {
              final rawList = data['doctor_list'] as List;
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

  /// D3: GET /doctors/{id} — Fetches a single doctor by ID.
  Future<Map<String, dynamic>> getDoctor(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.doctor(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['doctor'] is Map) {
              return Map<String, dynamic>.from(data['doctor'] as Map);
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

  /// D2: POST /doctors — Creates a new doctor record.
  Future<Map<String, dynamic>> addDoctor(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.doctors, data: data);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['doctor'] is Map) {
              return Map<String, dynamic>.from(resData['doctor'] as Map);
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

  /// D4: POST or PUT /doctors/{id} — Updates an existing doctor record.
  Future<Map<String, dynamic>> updateDoctor(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      // Backend collection uses POST /doctors/{id}
      Response response;
      try {
        response = await _dio.post(ApiConstants.doctor(id), data: data);
      } on DioException catch (e) {
        if (e.response?.statusCode == 405) {
          // Fallback to PUT if server requires PUT
          response = await _dio.put(ApiConstants.doctor(id), data: data);
        } else {
          rethrow;
        }
      }

      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' || response.statusCode == 200) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['doctor'] is Map) {
              return Map<String, dynamic>.from(resData['doctor'] as Map);
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

  /// D5: DELETE /doctors/{id} — Deletes a doctor record by ID.
  Future<void> deleteDoctor(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.doctor(id));
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
