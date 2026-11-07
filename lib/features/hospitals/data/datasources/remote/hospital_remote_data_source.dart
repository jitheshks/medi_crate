import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';

/// HospitalRemoteDataSource handles HTTP interactions with the MediCrate Backend
/// Hospital / Clinic Endpoints (H1 - H5).
class HospitalRemoteDataSource {
  final ApiClient apiClient;

  HospitalRemoteDataSource({required this.apiClient});

  /// H1: GET /hospitals - List all hospitals
  Future<List<Map<String, dynamic>>> fetchHospitals({
    required int profileId,
    String? search,
    String? type,
    int limit = 20,
    void Function(int total)? onTotal,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.hospitals,
        queryParameters: {
          'profile_id': profileId,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        },
      );
      if (response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        final rawData = map['data'];
        // H1 envelope: data.hospitals[] + data.total. Also tolerate data:[...].
        if (rawData is Map) {
          reportListTotal(rawData, onTotal);
          final list = rawData['hospitals'] ?? rawData['hospital_list'];
          if (list is List) {
            return list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        if (rawData is List) {
          return rawData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// H3: GET /hospitals/{id} - Get single hospital details
  Future<Map<String, dynamic>> getHospital(dynamic id) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.hospital(id));
      if (response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        final data = map['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return Map<String, dynamic>.from(map);
      }
      return {};
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// H2: POST /hospitals - Add a new hospital
  Future<Map<String, dynamic>> addHospital(Map<String, dynamic> payload) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.hospitals,
        data: payload,
      );
      if (response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        final data = map['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return Map<String, dynamic>.from(map);
      }
      return {};
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// H4: POST /hospitals/{id} - Update an existing hospital
  Future<Map<String, dynamic>> updateHospital(
    dynamic id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.hospital(id),
        data: payload,
      );
      if (response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        final data = map['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return Map<String, dynamic>.from(map);
      }
      return {};
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        // Fallback to PUT if backend is strictly configured for REST standard
        try {
          final putResponse = await apiClient.dio.put(
            ApiConstants.hospital(id),
            data: payload,
          );
          if (putResponse.data is Map) {
            final map = putResponse.data as Map<String, dynamic>;
            final data = map['data'];
            if (data is Map) {
              return Map<String, dynamic>.from(data);
            }
            return Map<String, dynamic>.from(map);
          }
          return {};
        } on DioException catch (putErr) {
          throw ApiErrorParser.parseDioError(putErr);
        }
      }
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// H5: DELETE /hospitals/{id} - Delete a hospital
  Future<void> deleteHospital(dynamic id) async {
    try {
      await apiClient.dio.delete(ApiConstants.hospital(id));
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
