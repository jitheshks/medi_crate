import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_error_parser.dart';
import '../../../../../core/api/list_pull_support.dart';
import '../../models/report_model.dart';

/// ReportRemoteDataSource communicates with the backend REST API `/api/v1/reports` endpoints (R1 - R6).
class ReportRemoteDataSource {
  final ApiClient apiClient;

  ReportRemoteDataSource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// R1: GET /reports — Fetches diagnostic reports for a profile with canonical filters and pagination.
  Future<List<Map<String, dynamic>>> fetchReports({
    required int profileId,
    String? category,
    int? consultationId,
    int? doctorId,
    int? hospitalId,
    String? search,
    String? from,
    String? to,
    String? sort,
    int? page,
    int limit = 20,
    void Function(int total)? onTotal,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'profile_id': profileId,
        'limit': limit,
      };
      if (category != null && category.trim().isNotEmpty) {
        queryParams['category'] = category.trim();
      }
      if (consultationId != null) {
        queryParams['consultation_id'] = consultationId;
      }
      if (doctorId != null) {
        queryParams['doctor_id'] = doctorId;
      }
      if (hospitalId != null) {
        queryParams['hospital_id'] = hospitalId;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
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
        ApiConstants.reports,
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
            if (data['reports'] is List) {
              final rawList = data['reports'] as List;
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

  /// R2: POST /reports — Creates a new report record with real multipart files[].
  ///
  /// Transmits metadata and zero or more binary attachment files using `multipart/form-data`.
  /// Dio automatically constructs the appropriate multipart boundary.
  Future<Map<String, dynamic>> addReport(
    Map<String, dynamic> metadata, {
    List<ReportAttachmentModel> attachments = const [],
  }) async {
    try {
      dynamic requestData;

      if (attachments.isNotEmpty) {
        final formData = FormData();

        // 1. Add scalar metadata fields
        for (final entry in metadata.entries) {
          if (entry.value != null) {
            formData.fields.add(MapEntry(entry.key, entry.value.toString()));
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

      final response = await _dio.post(ApiConstants.reports, data: requestData);
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final resData = responseData['data'];
          if (resData is Map<String, dynamic>) {
            if (resData['report'] is Map) {
              return Map<String, dynamic>.from(resData['report'] as Map);
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

  /// R3: GET /reports/{id} — Retrieves a single report by ID.
  Future<Map<String, dynamic>> getReport(dynamic id) async {
    try {
      final response = await _dio.get(ApiConstants.report(id));
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['status'] == 'success' ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            if (data['report'] is Map) {
              return Map<String, dynamic>.from(data['report'] as Map);
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

  /// R4: PUT /reports/{id} — Updates an existing report's metadata.
  Future<Map<String, dynamic>> updateReport(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      Response response;
      try {
        response = await _dio.put(ApiConstants.report(id), data: data);
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 405) {
          response = await _dio.post(ApiConstants.report(id), data: data);
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
            if (resData['report'] is Map) {
              return Map<String, dynamic>.from(resData['report'] as Map);
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

  /// R5: DELETE /reports/{id} — Deletes a report and its server attachments.
  Future<void> deleteReport(dynamic id) async {
    try {
      final response = await _dio.delete(ApiConstants.report(id));
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

  /// R6: GET /reports/{report}/files/{file} — Streams binary file download.
  Future<Uint8List> downloadReportAttachment(
    dynamic reportId,
    dynamic fileId,
  ) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiConstants.reportFile(reportId, fileId),
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
