import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';
import '../../models/consultation_attachment.dart';

/// ConsultationRemoteDataSource interacts with Laravel backend REST API `/api/v1/consultations` endpoints (C1 - C6).
class ConsultationRemoteDataSource {
  final ApiClient apiClient;

  ConsultationRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// C1: GET /consultations — Fetches consultations for a profile with optional filters.
  Future<List<Map<String, dynamic>>> fetchConsultations({
    required int profileId,
    String? doctorId,
    String? hospitalId,
    String? search,
    String? from,
    String? to,
    int limit = 50,
    void Function(int total)? onTotal,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'profile_id': profileId,
        'limit': limit,
      };
      if (doctorId != null && doctorId.isNotEmpty) {
        queryParams['doctor_id'] = doctorId;
      }
      if (hospitalId != null && hospitalId.isNotEmpty) {
        queryParams['hospital_id'] = hospitalId;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (from != null && from.isNotEmpty) {
        queryParams['from'] = from;
      }
      if (to != null && to.isNotEmpty) {
        queryParams['to'] = to;
      }

      final response = await _dio.get(
        ApiConstants.consultations,
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
            if (data['consultations'] is List) {
              final rawList = data['consultations'] as List;
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

  /// C2: POST /consultations — Creates a new consultation record with optional multipart files[].
  Future<Map<String, dynamic>> addConsultation(
    Map<String, dynamic> metadata, {
    List<ConsultationAttachment> attachments = const [],
  }) async {
    try {
      dynamic requestData;

      if (attachments.isNotEmpty) {
        final formData = FormData();

        // 1. Add scalar metadata fields
        for (final entry in metadata.entries) {
          if (entry.value != null) {
            if (entry.value is List) {
              for (final item in (entry.value as List)) {
                formData.fields.add(
                  MapEntry('${entry.key}[]', item.toString()),
                );
              }
            } else {
              formData.fields.add(MapEntry(entry.key, entry.value.toString()));
            }
          }
        }

        // 2. Validate and add files[]
        for (final att in attachments) {
          if (att.filePath != null && att.filePath!.trim().isNotEmpty) {
            final file = File(att.filePath!);
            if (!file.existsSync()) {
              throw FileSystemException(
                'Local attachment file does not exist on disk: ${att.filePath}',
                att.filePath,
              );
            }
            final length = file.lengthSync();
            if (length > 25 * 1024 * 1024) {
              throw const FormatException('Each file must not exceed 25MB.');
            }

            final fileName = att.name.isNotEmpty
                ? att.name
                : file.path.split(Platform.pathSeparator).last;
            final ext = fileName.contains('.')
                ? fileName.split('.').last.toLowerCase()
                : '';
            if (ext != 'pdf' && ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
              throw const FormatException(
                'Each file must be a PDF, JPG, or PNG.',
              );
            }

            final multipartFile = await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            );
            formData.files.add(MapEntry('files[]', multipartFile));
          }
        }

        requestData = formData;
      } else {
        requestData = metadata;
      }

      final response = await _dio.post(
        ApiConstants.consultations,
        data: requestData,
      );
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['consultation'] is Map) {
              return Map<String, dynamic>.from(resData['consultation'] as Map);
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

  /// C3: GET /consultations/{id} — Retrieves a single consultation by ID.
  Future<Map<String, dynamic>> getConsultation(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.consultation(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['consultation'] is Map) {
              return Map<String, dynamic>.from(data['consultation'] as Map);
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

  /// C4: PUT /consultations/{id} — Updates an existing consultation record.
  /// Includes fallback to POST /consultations/{id} if required by backend router.
  Future<Map<String, dynamic>> updateConsultation(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      Response response;
      try {
        response = await _dio.put(ApiConstants.consultation(id), data: data);
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 405) {
          response = await _dio.post(ApiConstants.consultation(id), data: data);
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
            if (resData['consultation'] is Map) {
              return Map<String, dynamic>.from(resData['consultation'] as Map);
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

  /// C5: DELETE /consultations/{id} — Deletes a consultation record.
  Future<void> deleteConsultation(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.consultation(id));
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

  /// C6: GET /consultations/{consultation}/files/{file} — Streams binary file download.
  Future<Uint8List> downloadConsultationAttachment(
    dynamic consultationId,
    dynamic fileId,
  ) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiConstants.consultationFile(consultationId, fileId),
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        return Uint8List.fromList(response.data!);
      }
      throw const FormatException(
        'Empty attachment body received from server.',
      );
    } on DioException catch (e) {
      throw ApiErrorParser.parseDioError(e);
    }
  }
}
