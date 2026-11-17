import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/storage/supabase_storage_service.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/report_model.dart';

/// SupabaseReportRemoteDataSource handles authenticated PostgREST operations
/// on `public.reports`, `public.report_attachments`, and `public.report_expenses` (R1–R6),
/// as well as the private Supabase Storage lifecycle on the `reports` bucket.
class SupabaseReportRemoteDataSource {
  final SupabaseClient? customClient;
  final SupabaseStorageService? customStorageService;

  SupabaseReportRemoteDataSource({
    SupabaseClient? client,
    SupabaseStorageService? storageService,
  })  : customClient = client,
        customStorageService = storageService;

  SupabaseClient get _client => customClient ?? SupabaseConfig.client;

  SupabaseStorageService get _storageService =>
      customStorageService ?? SupabaseStorageService(customClient: _client);

  /// R1 / R2: Fetches reports for [profileId] with optional filters,
  /// joining attachments and expenses in a single PostgREST query.
  Future<List<ReportModel>> fetchReports({
    required String ownerUserId,
    required String profileId,
    String? category,
    String? consultationId,
    String? doctorId,
    String? hospitalId,
    String? search,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch reports without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      var query = _client
          .from('reports')
          .select('*, report_attachments(*), report_expenses(*)')
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

      if (category != null &&
          category.trim().isNotEmpty &&
          category.trim().toUpperCase() != 'ALL') {
        final normalizedCat = ReportModel.normalizeCategoryToSupabase(category);
        query = query.eq('category', normalizedCat);
      }

      if (consultationId != null && consultationId.trim().isNotEmpty) {
        final cleanConId = IdUtils.unprefix(consultationId).trim();
        if (UuidUtils.isValidUuid(cleanConId)) {
          query = query.eq('consultation_id', cleanConId);
        }
      }

      if (doctorId != null && doctorId.trim().isNotEmpty) {
        final cleanDocId = IdUtils.unprefix(doctorId).trim();
        if (UuidUtils.isValidUuid(cleanDocId)) {
          query = query.eq('doctor_id', cleanDocId);
        }
      }

      if (hospitalId != null && hospitalId.trim().isNotEmpty) {
        final cleanHospId = IdUtils.unprefix(hospitalId).trim();
        if (UuidUtils.isValidUuid(cleanHospId)) {
          query = query.eq('hospital_id', cleanHospId);
        }
      }

      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim();
        query = query.or(
          'title.ilike.%$s%,notes.ilike.%$s%,doctor_name.ilike.%$s%,hospital_name.ilike.%$s%,consultation_title.ilike.%$s%',
        );
      }

      if (from != null && from.trim().isNotEmpty) {
        query = query.gte('report_date', from.trim());
      }
      if (to != null && to.trim().isNotEmpty) {
        query = query.lte('report_date', to.trim());
      }

      var orderedQuery = query.order('report_date', ascending: false);

      final response = limit != null && limit > 0
          ? await orderedQuery.limit(limit)
          : await orderedQuery;

      final reports = (response as List)
          .map((row) => ReportModel.fromSupabaseJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      onTotal?.call(reports.length);
      return reports;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchReports');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load reports.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch reports: $e');
    }
  }

  /// R3: Retrieves a single report by [reportId] with its attachments and expense.
  Future<ReportModel?> getReportById({
    required String reportId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(reportId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (cleanId.isEmpty ||
        !UuidUtils.isValidUuid(cleanId) ||
        trimmedOwnerId.isEmpty) {
      return null;
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        return null;
      }
    }

    try {
      var query = _client
          .from('reports')
          .select('*, report_attachments(*), report_expenses(*)')
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;

      return ReportModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getReportById');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load report.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get report: $e');
    }
  }

  /// R2: Creates a new report in `public.reports` and links any child attachments and expenses.
  Future<ReportModel> createReport({
    required ReportModel report,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create report without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }
    if (report.title.trim().isEmpty) {
      throw const ValidationException('Report title cannot be empty.');
    }

    final cleanId = IdUtils.unprefix(report.id).trim();
    final effectiveId =
        UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4();
    final clientUuid = report.clientUuid?.trim();
    final effectiveClientUuid =
        (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
            ? clientUuid
            : effectiveId;

    try {
      final reportPayload = report
          .copyWith(
            id: effectiveId,
            profileId: cleanProfileId,
            clientUuid: effectiveClientUuid,
          )
          .toSupabaseJson(includeId: true);

      reportPayload['user_id'] = trimmedOwnerId;

      final res = await _client
          .from('reports')
          .insert(reportPayload)
          .select('*, report_attachments(*), report_expenses(*)')
          .single();

      final created = ReportModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );

      // Persist child attachments metadata
      final List<ReportAttachmentModel> savedAttachments = [];
      if (report.attachments.isNotEmpty) {
        for (final att in report.attachments) {
          final attCleanId = IdUtils.unprefix(att.id).trim();
          final attEffectiveId = UuidUtils.isValidUuid(attCleanId)
              ? attCleanId
              : UuidUtils.generateV4();

          final attPayload = att
              .copyWith(id: attEffectiveId)
              .toSupabaseJson(
                reportId: effectiveId,
                userId: trimmedOwnerId,
                includeId: true,
              );

          try {
            final attRes = await _client
                .from('report_attachments')
                .insert(attPayload)
                .select()
                .single();
            savedAttachments.add(
              ReportAttachmentModel.fromSupabaseJson(
                Map<String, dynamic>.from(attRes),
              ),
            );
          } on PostgrestException catch (e) {
            throw _handlePostgrestException(
              e,
              'createReport (attachment: ${att.name})',
            );
          } catch (e) {
            if (e is AppException) rethrow;
            throw ServerException(
              'Failed to persist report attachment "${att.name}": $e',
            );
          }
        }
      }

      // Persist child expense metadata
      ReportExpenseModel? savedExpense = created.expense;
      if (report.expense != null) {
        final expCleanId = IdUtils.unprefix(report.expense!.id).trim();
        final expEffectiveId = UuidUtils.isValidUuid(expCleanId)
            ? expCleanId
            : UuidUtils.generateV4();

        final expPayload = report.expense!
            .copyWith(id: expEffectiveId)
            .toSupabaseJson(
              reportId: effectiveId,
              userId: trimmedOwnerId,
              includeId: true,
            );

        try {
          final expRes = await _client
              .from('report_expenses')
              .upsert(expPayload, onConflict: 'report_id')
              .select()
              .single();
          savedExpense = ReportExpenseModel.fromSupabaseJson(
            Map<String, dynamic>.from(expRes),
          );
        } on PostgrestException catch (e) {
          throw _handlePostgrestException(e, 'createReport (expense)');
        } catch (e) {
          if (e is AppException) rethrow;
          throw ServerException('Failed to persist report expense: $e');
        }
      }

      return created.copyWith(
        attachments: savedAttachments.isNotEmpty
            ? savedAttachments
            : created.attachments,
        expense: savedExpense,
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createReport');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to create report.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create report: $e');
    }
  }

  /// R4: Updates an existing report in `public.reports` and synchronizes its child entities.
  Future<ReportModel> updateReport({
    required ReportModel report,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(report.id).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update report without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException(
        'Report ID must be a valid UUID when updating.',
      );
    }
    if (report.title.trim().isEmpty) {
      throw const ValidationException('Report title cannot be empty.');
    }

    final effectiveProfileId =
        (profileId != null && profileId.trim().isNotEmpty)
            ? IdUtils.unprefix(profileId).trim()
            : IdUtils.unprefix(report.profileId).trim();

    if (effectiveProfileId.isNotEmpty &&
        !UuidUtils.isValidUuid(effectiveProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID.');
    }

    try {
      final updatePayload = report
          .copyWith(
            profileId:
                effectiveProfileId.isNotEmpty ? effectiveProfileId : null,
          )
          .toSupabaseJson(includeId: false);

      var query = _client
          .from('reports')
          .update(updatePayload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (effectiveProfileId.isNotEmpty) {
        query = query.eq('profile_id', effectiveProfileId);
      }

      await query;

      // Synchronize attachments
      final existingAttsRes = await _client
          .from('report_attachments')
          .select()
          .eq('report_id', cleanId)
          .eq('user_id', trimmedOwnerId);

      final existingAtts = (existingAttsRes as List)
          .map((a) => ReportAttachmentModel.fromSupabaseJson(
                Map<String, dynamic>.from(a as Map),
              ))
          .toList();

      final existingIds = existingAtts.map((a) => a.id).toSet();
      final newIds = report.attachments
          .map((a) => IdUtils.unprefix(a.id).trim())
          .where((id) => id.isNotEmpty && UuidUtils.isValidUuid(id))
          .toSet();

      // Delete removed attachments from database and storage
      for (final oldAtt in existingAtts) {
        if (!newIds.contains(oldAtt.id)) {
          await _client
              .from('report_attachments')
              .delete()
              .eq('id', oldAtt.id)
              .eq('user_id', trimmedOwnerId);

          if (oldAtt.filePath != null && oldAtt.filePath!.isNotEmpty) {
            try {
              await _storageService.deleteFile(
                bucket: SupabaseStorageService.reportsBucket,
                storagePath: oldAtt.filePath!,
              );
            } catch (_) {}
          }
        }
      }

      // Insert newly added attachments
      final List<ReportAttachmentModel> savedAttachments = [];
      for (final att in report.attachments) {
        final attCleanId = IdUtils.unprefix(att.id).trim();
        final attEffectiveId = UuidUtils.isValidUuid(attCleanId)
            ? attCleanId
            : UuidUtils.generateV4();

        if (!existingIds.contains(attEffectiveId)) {
          final attPayload = att
              .copyWith(id: attEffectiveId)
              .toSupabaseJson(
                reportId: cleanId,
                userId: trimmedOwnerId,
                includeId: true,
              );
          try {
            final attRes = await _client
                .from('report_attachments')
                .insert(attPayload)
                .select()
                .single();
            savedAttachments.add(
              ReportAttachmentModel.fromSupabaseJson(
                Map<String, dynamic>.from(attRes),
              ),
            );
          } on PostgrestException catch (e) {
            throw _handlePostgrestException(
              e,
              'updateReport (attachment: ${att.name})',
            );
          } catch (e) {
            if (e is AppException) rethrow;
            throw ServerException(
              'Failed to persist report attachment "${att.name}": $e',
            );
          }
        } else {
          savedAttachments.add(att.copyWith(id: attEffectiveId));
        }
      }

      // Synchronize expense (1:1 per report)
      ReportExpenseModel? savedExpense;
      if (report.expense != null) {
        final expCleanId = IdUtils.unprefix(report.expense!.id).trim();
        final expEffectiveId = UuidUtils.isValidUuid(expCleanId)
            ? expCleanId
            : UuidUtils.generateV4();

        final expPayload = report.expense!
            .copyWith(id: expEffectiveId)
            .toSupabaseJson(
              reportId: cleanId,
              userId: trimmedOwnerId,
              includeId: true,
            );

        try {
          final expRes = await _client
              .from('report_expenses')
              .upsert(expPayload, onConflict: 'report_id')
              .select()
              .single();
          savedExpense = ReportExpenseModel.fromSupabaseJson(
            Map<String, dynamic>.from(expRes),
          );
        } on PostgrestException catch (e) {
          throw _handlePostgrestException(e, 'updateReport (expense)');
        } catch (e) {
          if (e is AppException) rethrow;
          throw ServerException('Failed to synchronize report expense: $e');
        }
      } else {
        await _client
            .from('report_expenses')
            .delete()
            .eq('report_id', cleanId)
            .eq('user_id', trimmedOwnerId);
      }

      return report.copyWith(
        id: cleanId,
        profileId:
            effectiveProfileId.isNotEmpty ? effectiveProfileId : report.profileId,
        attachments: savedAttachments,
        expense: savedExpense,
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateReport');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to update report.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update report: $e');
    }
  }

  /// R5: Deletes a report from `public.reports` and cascades to delete all
  /// associated files in Supabase Storage to prevent orphaned objects.
  Future<void> deleteReport({
    required String reportId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(reportId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete report without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Report ID must be a valid UUID.');
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }

    try {
      // 1. Clean up Storage files for this report first (before deleting the parent row)
      // because Storage RLS requires positive parent existence to delete objects!
      // If Storage deletion fails, parent row is NOT deleted, ensuring objects don't become orphans.
      await _storageService.deleteParentFolder(
        bucket: SupabaseStorageService.reportsBucket,
        parentId: cleanId,
        userId: trimmedOwnerId,
      );

      // 2. Delete database row only after required Storage cleanup succeeds
      var query = _client
          .from('reports')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteReport');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to delete report.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete report: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // STORAGE LIFECYCLE OPERATIONS
  // ---------------------------------------------------------------------------

  /// Uploads a report attachment file to the private `reports` bucket.
  /// Object path convention: `{userId}/{reportId}/{attachmentId}_{sanitizedFileName}`.
  Future<String> uploadAttachmentFile({
    required String userId,
    required String reportId,
    required File file,
    String? customAttachmentId,
    String? fileName,
  }) async {
    final cleanReportId = IdUtils.unprefix(reportId).trim();
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot upload attachment without an active authenticated session.',
      );
    }
    if (cleanReportId.isEmpty || !UuidUtils.isValidUuid(cleanReportId)) {
      throw const ValidationException(
        'Parent Report ID must be a valid UUID to upload attachments.',
      );
    }

    final attId = customAttachmentId ?? UuidUtils.generateV4();
    final effectiveName = fileName ?? p.basename(file.path);

    final storagePath = SupabaseStorageService.buildObjectPath(
      userId: cleanUserId,
      parentId: cleanReportId,
      fileName: effectiveName,
      attachmentId: attId,
    );

    return await _storageService.uploadFile(
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: storagePath,
      file: file,
      expectedUserId: cleanUserId,
    );
  }

  /// Downloads an attachment file from the private `reports` bucket to [destinationFile].
  Future<File> downloadAttachmentFile({
    required String userId,
    required String storagePath,
    required File destinationFile,
  }) async {
    return await _storageService.downloadToFile(
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: storagePath,
      destinationFilePath: destinationFile.path,
    );
  }

  /// Generates a temporary signed URL for an attachment in the private `reports` bucket.
  Future<String> getAttachmentSignedUrl({
    required String userId,
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    return await _storageService.createSignedUrl(
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: storagePath,
      expiresInSeconds: expiresInSeconds,
    );
  }

  /// Deletes a single attachment file from the private `reports` bucket.
  Future<void> deleteAttachmentFile({
    required String userId,
    required String storagePath,
  }) async {
    await _storageService.deleteFile(
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: storagePath,
    );
  }

  AppException _handlePostgrestException(
    PostgrestException e,
    String operation,
  ) {
    final code = e.code ?? '';
    final msg = e.message;

    if (code == '42501') {
      return UnauthorizedException(
        'You do not have permission to perform this report operation: $msg',
      );
    }
    if (code == '23503') {
      return ValidationException(
        'Related entity (profile, doctor, hospital, or consultation) not found or invalid: $msg',
      );
    }
    if (code == '23505') {
      return ConflictException(
        'A report or attachment with this identifier already exists: $msg',
      );
    }
    if (code == '23514') {
      return ValidationException('Validation constraint violation: $msg');
    }
    if (code == 'PGRST116') {
      return const NotFoundException('Report record not found.');
    }

    return ServerException(
      'Supabase report operation failed ($operation): $msg (code: $code)',
    );
  }
}
