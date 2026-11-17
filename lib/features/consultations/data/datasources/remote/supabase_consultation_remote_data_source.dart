import 'dart:io';

import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_attachment.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase data source for clinical consultations and attached documents (Endpoints C1–C6).
/// Operates directly against `public.consultations` and `public.consultation_attachments`.
class SupabaseConsultationRemoteDataSource {
  final SupabaseClient? customClient;
  final SupabaseStorageService? customStorageService;

  SupabaseConsultationRemoteDataSource({
    SupabaseClient? client,
    this.customStorageService,
  }) : customClient = client;

  SupabaseClient get _client => customClient ?? SupabaseConfig.client;
  SupabaseStorageService get _storageService =>
      customStorageService ?? SupabaseStorageService(customClient: _client);

  /// C1: Fetches consultations for [profileId] with optional clinician, facility, date, and text filters.
  Future<List<ConsultationModel>> fetchConsultations({
    required String ownerUserId,
    required String profileId,
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
        'Cannot fetch consultations without a valid authenticated user ID.',
      );
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty.');
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      var query = _client
          .from('consultations')
          .select('*, consultation_attachments(*)')
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

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
          'chief_complaint.ilike.%$s%,diagnosis.ilike.%$s%,doctor_name.ilike.%$s%,hospital_name.ilike.%$s%',
        );
      }

      if (from != null && from.trim().isNotEmpty) {
        query = query.gte('visit_date', from.trim());
      }
      if (to != null && to.trim().isNotEmpty) {
        query = query.lte('visit_date', to.trim());
      }

      var orderedQuery = query.order('visit_date', ascending: false);

      final response = limit != null && limit > 0
          ? await orderedQuery.limit(limit)
          : await orderedQuery;

      final consultations = (response as List)
          .map((row) => ConsultationModel.fromSupabaseJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      onTotal?.call(consultations.length);
      return consultations;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchConsultations');
    } on SocketException {
      throw const NetworkException('Internet connection required to load consultations.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch consultations: $e');
    }
  }

  /// C3: Fetches a single consultation encounter by ID with embedded attachments.
  Future<ConsultationModel?> getConsultationById({
    required String consultationId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(consultationId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId) || trimmedOwnerId.isEmpty) {
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
          .from('consultations')
          .select('*, consultation_attachments(*)')
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;

      return ConsultationModel.fromSupabaseJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getConsultationById');
    } on SocketException {
      throw const NetworkException('Internet connection required to load consultation.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get consultation: $e');
    }
  }

  /// C2: Creates a new consultation record and links its attachment metadata.
  Future<ConsultationModel> createConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create consultation without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty.');
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }
    if (consultation.doctorName.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }
    if (consultation.chiefComplaint.trim().isEmpty) {
      throw const ValidationException('Chief complaint cannot be empty.');
    }
    if (consultation.diagnosis.trim().isEmpty) {
      throw const ValidationException('Diagnosis cannot be empty.');
    }

    final cleanId = IdUtils.unprefix(consultation.id).trim();
    final effectiveId = UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4();
    final clientUuid = consultation.clientUuid?.trim();
    final effectiveClientUuid = (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
        ? clientUuid
        : effectiveId;

    try {
      final consultationPayload = consultation
          .copyWith(
            id: effectiveId,
            profileId: cleanProfileId,
            clientUuid: effectiveClientUuid,
          )
          .toSupabaseJson(includeId: true);

      consultationPayload['user_id'] = trimmedOwnerId;

      final res = await _client
          .from('consultations')
          .insert(consultationPayload)
          .select('*, consultation_attachments(*)')
          .single();

      final created = ConsultationModel.fromSupabaseJson(Map<String, dynamic>.from(res));

      // Persist any provided attachments
      if (consultation.attachments.isNotEmpty) {
        final List<ConsultationAttachment> savedAttachments = [];
        for (final att in consultation.attachments) {
          final attCleanId = IdUtils.unprefix(att.id).trim();
          final attEffectiveId = UuidUtils.isValidUuid(attCleanId)
              ? attCleanId
              : UuidUtils.generateV4();

          final attPayload = att
              .copyWith(id: attEffectiveId)
              .toSupabaseJson(
                consultationId: effectiveId,
                userId: trimmedOwnerId,
                includeId: true,
              );

          try {
            final attRes = await _client
                .from('consultation_attachments')
                .insert(attPayload)
                .select()
                .single();
            savedAttachments.add(
              ConsultationAttachment.fromSupabaseJson(Map<String, dynamic>.from(attRes)),
            );
          } on PostgrestException catch (e) {
            throw _handlePostgrestException(
              e,
              'createConsultation (attachment: ${att.name})',
            );
          } catch (e) {
            if (e is AppException) rethrow;
            throw ServerException(
              'Failed to persist consultation attachment "${att.name}": $e',
            );
          }
        }
        return created.copyWith(attachments: savedAttachments);
      }

      return created;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createConsultation');
    } on SocketException {
      throw const NetworkException('Internet connection required to create consultation.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create consultation: $e');
    }
  }

  /// C4: Updates an existing consultation record and synchronizes its attachment metadata.
  Future<ConsultationModel> updateConsultation({
    required ConsultationModel consultation,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(consultation.id).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update consultation without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Consultation ID must be a valid UUID when updating.');
    }
    if (consultation.doctorName.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }
    if (consultation.chiefComplaint.trim().isEmpty) {
      throw const ValidationException('Chief complaint cannot be empty.');
    }
    if (consultation.diagnosis.trim().isEmpty) {
      throw const ValidationException('Diagnosis cannot be empty.');
    }

    final effectiveProfileId = (profileId != null && profileId.trim().isNotEmpty)
        ? IdUtils.unprefix(profileId).trim()
        : IdUtils.unprefix(consultation.profileId).trim();

    if (effectiveProfileId.isNotEmpty && !UuidUtils.isValidUuid(effectiveProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID.');
    }

    try {
      final updatePayload = consultation
          .copyWith(profileId: effectiveProfileId.isNotEmpty ? effectiveProfileId : null)
          .toSupabaseJson(includeId: false);

      var query = _client
          .from('consultations')
          .update(updatePayload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (effectiveProfileId.isNotEmpty) {
        query = query.eq('profile_id', effectiveProfileId);
      }

      final res = await query.select('*, consultation_attachments(*)').single();
      final updated = ConsultationModel.fromSupabaseJson(Map<String, dynamic>.from(res));

      // Synchronize attachments
      if (consultation.attachments.isNotEmpty) {
        final List<ConsultationAttachment> currentAtts = [];
        for (final att in consultation.attachments) {
          final attCleanId = IdUtils.unprefix(att.id).trim();
          final attEffectiveId = UuidUtils.isValidUuid(attCleanId)
              ? attCleanId
              : UuidUtils.generateV4();

          final attPayload = att
              .copyWith(id: attEffectiveId)
              .toSupabaseJson(
                consultationId: cleanId,
                userId: trimmedOwnerId,
                includeId: true,
              );

          try {
            final upsertRes = await _client
                .from('consultation_attachments')
                .upsert(attPayload)
                .select()
                .single();
            currentAtts.add(
              ConsultationAttachment.fromSupabaseJson(Map<String, dynamic>.from(upsertRes)),
            );
          } on PostgrestException catch (e) {
            throw _handlePostgrestException(
              e,
              'updateConsultation (attachment: ${att.name})',
            );
          } catch (e) {
            if (e is AppException) rethrow;
            throw ServerException(
              'Failed to synchronize consultation attachment "${att.name}": $e',
            );
          }
        }
        return updated.copyWith(attachments: currentAtts);
      }

      return updated;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateConsultation');
    } on SocketException {
      throw const NetworkException('Internet connection required to update consultation.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update consultation: $e');
    }
  }

  /// C5: Deletes a consultation encounter from `public.consultations`.
  /// Cascade deletes attachments from `public.consultation_attachments`.
  Future<void> deleteConsultation({
    required String consultationId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(consultationId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete consultation without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Consultation ID must be a valid UUID.');
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }

    try {
      // 1. Clean up Storage files for this consultation first (before deleting the parent row)
      // because Storage RLS requires positive parent existence in public.consultations to delete objects!
      // If Storage deletion fails, parent row is NOT deleted, ensuring objects don't become orphans.
      await _storageService.deleteParentFolder(
        bucket: SupabaseStorageService.consultationsBucket,
        parentId: cleanId,
        userId: trimmedOwnerId,
      );

      var query = _client
          .from('consultations')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteConsultation');
    } on SocketException {
      throw const NetworkException('Internet connection required to delete consultation.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete consultation: $e');
    }
  }

  AppException _handlePostgrestException(PostgrestException e, String operation) {
    final code = e.code;
    final message = e.message;
    if (code == 'PGRST116') {
      return NotFoundException('$operation: Consultation record not found.');
    }
    if (code == '42501' || message.toLowerCase().contains('permission denied')) {
      return UnauthorizedException('Access denied during $operation: $message');
    }
    if (code == '23505') {
      return ConflictException('A consultation with this identifier already exists: $message');
    }
    if (code == '23503') {
      return ValidationException('Foreign key constraint violation during $operation: $message');
    }
    return ServerException('Database error during $operation: $message', code: code);
  }
}
