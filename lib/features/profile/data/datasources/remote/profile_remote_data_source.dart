import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';

/// ProfileRemoteDataSource interacts with Laravel backend REST API `/api/v1/family-members` endpoints (F1 - F6).
class ProfileRemoteDataSource {
  final ApiClient apiClient;

  ProfileRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// F1: GET /family-members — Fetches all family member profiles for the authenticated user.
  Future<List<Map<String, dynamic>>> fetchFamilyMembers() async {
    try {
      final response = await _dio.get(ApiConstants.familyMembers);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['family_members'] is List) {
              final rawList = data['family_members'] as List;
              return rawList
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
            if (data['profiles'] is List) {
              final rawList = data['profiles'] as List;
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

  /// F2: GET /family-members/{id} — Fetches a single family member profile by ID.
  Future<Map<String, dynamic>> getFamilyMember(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.familyMember(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['family_member'] is Map) {
              return Map<String, dynamic>.from(data['family_member'] as Map);
            }
            if (data['profile'] is Map) {
              return Map<String, dynamic>.from(data['profile'] as Map);
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

  /// F3: POST /family-members — Creates a new family member sub-profile.
  Future<Map<String, dynamic>> addFamilyMember(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(ApiConstants.familyMembers, data: data);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['family_member'] is Map) {
              return Map<String, dynamic>.from(resData['family_member'] as Map);
            }
            if (resData['profile'] is Map) {
              return Map<String, dynamic>.from(resData['profile'] as Map);
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

  /// F4: PUT /family-members/{id} — Updates an existing family member sub-profile.
  Future<Map<String, dynamic>> updateFamilyMember(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(
        ApiConstants.familyMember(id),
        data: data,
      );
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' || response.statusCode == 200) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['family_member'] is Map) {
              return Map<String, dynamic>.from(resData['family_member'] as Map);
            }
            if (resData['profile'] is Map) {
              return Map<String, dynamic>.from(resData['profile'] as Map);
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

  /// F5: DELETE /family-members/{id} — Deletes a family member sub-profile.
  Future<void> deleteFamilyMember(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.familyMember(id));
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

  /// F6: POST /family-members/{id}/photo — Uploads avatar photo via multipart/form-data.
  Future<String> uploadFamilyMemberPhoto(dynamic id, File photoFile) async {
    try {
      final fileName = photoFile.uri.pathSegments.isNotEmpty
          ? photoFile.uri.pathSegments.last
          : 'photo.jpg';
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          photoFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        ApiConstants.familyMemberPhoto(id),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            final photoUrl =
                (data['photo_url'] ?? data['photo'] ?? data['avatar'] ?? '')
                    .toString();
            if (photoUrl.isNotEmpty) return photoUrl;
          }
          if (responseData['photo_url'] != null) {
            return responseData['photo_url'].toString();
          }
          return '';
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

  /// F7: GET /family/dashboard — Returns overview summary across all family profiles.
  Future<List<Map<String, dynamic>>> fetchFamilyDashboard() async {
    try {
      final response = await _dio.get(ApiConstants.familyDashboard);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['family_summary'] is List) {
              final list = data['family_summary'] as List;
              return list
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
          }
          if (data is List) {
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
      }
      return [];
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }

  /// F8: GET /family/analytics — Returns combined analytics across all family profiles.
  Future<List<Map<String, dynamic>>> fetchFamilyAnalytics() async {
    try {
      final response = await _dio.get(ApiConstants.familyAnalytics);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['profiles_analytics'] is List) {
              final list = data['profiles_analytics'] as List;
              return list
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
          }
          if (data is List) {
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
      }
      return [];
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
