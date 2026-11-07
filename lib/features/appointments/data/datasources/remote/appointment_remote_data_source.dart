import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';

/// AppointmentRemoteDataSource communicates with the backend REST API `/api/v1/appointments` endpoints (AP1 - AP5).
class AppointmentRemoteDataSource {
  final ApiClient apiClient;

  AppointmentRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// AP1: GET /appointments — Fetches appointments for a profile with canonical filters and sorting.
  Future<List<Map<String, dynamic>>> fetchAppointments({
    required int profileId,
    String? status,
    int? doctorId,
    int? hospitalId,
    String? from,
    String? to,
    String? sort,
    int limit = 20,
    void Function(int total)? onTotal,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'profile_id': profileId,
        'limit': limit,
      };
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim().toLowerCase();
      }
      if (doctorId != null) {
        queryParams['doctor_id'] = doctorId;
      }
      if (hospitalId != null) {
        queryParams['hospital_id'] = hospitalId;
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

      final response = await _dio.get(
        ApiConstants.appointments,
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
            if (data['appointments'] is List) {
              final rawList = data['appointments'] as List;
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

  /// AP2: POST /appointments — Schedules a new appointment.
  Future<Map<String, dynamic>> addAppointment(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.appointments, data: data);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['appointment'] is Map) {
              return Map<String, dynamic>.from(resData['appointment'] as Map);
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

  /// AP3: GET /appointments/{id} — Retrieves a single appointment by ID.
  Future<Map<String, dynamic>> getAppointment(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.appointment(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['appointment'] is Map) {
              return Map<String, dynamic>.from(data['appointment'] as Map);
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

  /// AP4: PUT /appointments/{id} — Updates one or more fields of an appointment.
  Future<Map<String, dynamic>> updateAppointment(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      Response response;
      try {
        response = await _dio.put(ApiConstants.appointment(id), data: data);
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 405) {
          response = await _dio.post(ApiConstants.appointment(id), data: data);
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
            if (resData['appointment'] is Map) {
              return Map<String, dynamic>.from(resData['appointment'] as Map);
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

  /// AP5: DELETE /appointments/{id} — Deletes an appointment.
  Future<void> deleteAppointment(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.appointment(id));
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
