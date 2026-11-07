import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../models/medical_department_model.dart';

/// MedicalDepartmentRemoteDataSource communicates with the backend REST API
/// `/api/v1/medical-departments` endpoint (MD1).
class MedicalDepartmentRemoteDataSource {
  final ApiClient apiClient;

  MedicalDepartmentRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// MD1: GET /medical-departments — Fetches the fixed reference list of medical departments.
  Future<List<MedicalDepartmentModel>> fetchMedicalDepartments() async {
    try {
      final response = await _dio.get(ApiConstants.medicalDepartments);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['departments'] is List) {
              final rawList = data['departments'] as List;
              return rawList
                  .whereType<Map>()
                  .map(
                    (item) => MedicalDepartmentModel.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList();
            }
          } else if (data is List) {
            return data
                .whereType<Map>()
                .map(
                  (item) => MedicalDepartmentModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
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
            .map(
              (item) => MedicalDepartmentModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
