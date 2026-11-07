import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';

/// UserRemoteDataSource manages REST interactions for the authenticated user's account profile (B1 - B5 / B6).
class UserRemoteDataSource {
  final ApiClient apiClient;

  UserRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// B1: GET /users/me — Retrieves the authenticated user's account profile.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.usersMe);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['user'] is Map) {
              final userMap = Map<String, dynamic>.from(data['user'] as Map);
              if (data['profile'] is Map) {
                userMap['profile'] = data['profile'];
                userMap['profile_id'] ??=
                    (data['profile'] as Map)['id'] ??
                    (data['profile'] as Map)['profile_id'];
                userMap['server_profile_id'] ??=
                    (data['profile'] as Map)['id'] ??
                    (data['profile'] as Map)['server_profile_id'];
              }
              if (data['primary_profile'] is Map) {
                userMap['primary_profile'] = data['primary_profile'];
                userMap['profile_id'] ??=
                    (data['primary_profile'] as Map)['id'] ??
                    (data['primary_profile'] as Map)['profile_id'];
                userMap['server_profile_id'] ??=
                    (data['primary_profile'] as Map)['id'] ??
                    (data['primary_profile'] as Map)['server_profile_id'];
              }
              if (data['profile_id'] != null) {
                userMap['profile_id'] ??= data['profile_id'];
              }
              if (data['server_profile_id'] != null) {
                userMap['server_profile_id'] ??= data['server_profile_id'];
              }
              return userMap;
            }
            if (data['profile'] is Map) {
              return Map<String, dynamic>.from(data['profile'] as Map);
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

  /// B2: POST /users/me — Updates profile fields of the authenticated user.
  /// Supports multipart/form-data if a [photoFile] is provided.
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> fields, {
    File? photoFile,
  }) async {
    try {
      dynamic postData;
      Options? options;

      if (photoFile != null) {
        final fileName = photoFile.uri.pathSegments.isNotEmpty
            ? photoFile.uri.pathSegments.last
            : 'profile_photo.jpg';
        final map = Map<String, dynamic>.from(fields);
        map['photo'] = await MultipartFile.fromFile(
          photoFile.path,
          filename: fileName,
        );
        postData = FormData.fromMap(map);
        options = Options(contentType: 'multipart/form-data');
      } else {
        postData = fields;
      }

      Response response;
      try {
        response = await _dio.post(
          ApiConstants.usersMe,
          data: postData,
          options: options,
        );
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 405) {
          // Fallback to PUT if backend is strictly configured for PUT
          response = await _dio.put(
            ApiConstants.usersMe,
            data: postData,
            options: options,
          );
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
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['user'] is Map) {
              return Map<String, dynamic>.from(data['user'] as Map);
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

  /// B3: POST /users/me/password — Changes authenticated user password and revokes other tokens.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' || response.statusCode == 200) {
          final data = responseData['data'];
          if (data is Map && data['message'] != null) {
            return data['message'].toString();
          }
          if (responseData['message'] != null) {
            return responseData['message'].toString();
          }
          return 'Password changed successfully';
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

  /// B4 (PDF B5): POST /users/me/email — Step 1: Request change of account email and dispatch OTP.
  Future<String> requestChangeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.changeEmail,
        data: {'current_password': currentPassword, 'new_email': newEmail},
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' || response.statusCode == 200) {
          final data = responseData['data'];
          if (data is Map && data['message'] != null) {
            return data['message'].toString();
          }
          if (responseData['message'] != null) {
            return responseData['message'].toString();
          }
          return 'Verification code sent to your new email';
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

  /// B4 (PDF B6): POST /users/me/email/confirm — Step 2: Confirm OTP and finalize email update.
  Future<Map<String, dynamic>> confirmChangeEmail({required String otp}) async {
    try {
      final response = await _dio.post(
        ApiConstants.confirmChangeEmail,
        data: {'otp': otp},
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' || response.statusCode == 200) {
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

  /// B5 (PDF B4): DELETE /users/me — Permanently deletes user account after password confirmation.
  Future<String> deleteAccount({required String currentPassword}) async {
    try {
      final response = await _dio.delete(
        ApiConstants.usersMe,
        data: {'current_password': currentPassword},
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' || response.statusCode == 200) {
          final data = responseData['data'];
          if (data is Map && data['message'] != null) {
            return data['message'].toString();
          }
          if (responseData['message'] != null) {
            return responseData['message'].toString();
          }
          return 'Account deleted successfully';
        }
        throw ApiErrorParser.parseResponse(
          response.statusCode ?? 400,
          responseData,
        );
      }
      return 'Account deleted successfully';
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
