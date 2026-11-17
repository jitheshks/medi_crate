import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/medicine_model.dart';

/// SupabaseMedicineRemoteDataSource handles authenticated PostgREST operations
/// on `public.prescriptions` (M1–M5) with PostgreSQL RLS and tenant isolation.
class SupabaseMedicineRemoteDataSource {
  final SupabaseClient? customClient;

  SupabaseMedicineRemoteDataSource({SupabaseClient? client})
      : customClient = client;

  SupabaseClient get _client => customClient ?? SupabaseConfig.client;

  /// M1: Fetches prescriptions for [profileId] with optional filters.
  Future<List<MedicineModel>> fetchMedicines({
    required String ownerUserId,
    required String profileId,
    String? consultationId,
    String? search,
    String? status, // 'active' | 'completed'
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch medicines without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      var query = _client
          .from('prescriptions')
          .select()
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

      if (consultationId != null && consultationId.trim().isNotEmpty) {
        final cleanConsultationId = IdUtils.unprefix(consultationId).trim();
        if (UuidUtils.isValidUuid(cleanConsultationId)) {
          query = query.eq('consultation_id', cleanConsultationId);
        }
      }

      if (status != null && status.trim().isNotEmpty) {
        final lower = status.trim().toLowerCase();
        if (lower == 'active') {
          query = query.eq('is_active', true);
        } else if (lower == 'completed') {
          query = query.eq('is_active', false);
        }
      }

      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim();
        query = query.or(
          'medicine_name.ilike.%$s%,dosage.ilike.%$s%,instructions.ilike.%$s%',
        );
      }

      var orderedQuery = query.order('created_at', ascending: false);

      final response = limit != null && limit > 0
          ? await orderedQuery.limit(limit)
          : await orderedQuery;

      final medicines = (response as List)
          .map((row) => MedicineModel.fromSupabaseJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      onTotal?.call(medicines.length);
      return medicines;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchMedicines');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load medicines.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch medicines: $e');
    }
  }

  /// M3: Retrieves a single prescription by [medicineId].
  Future<MedicineModel?> getMedicineById({
    required String medicineId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(medicineId).trim();
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
          .from('prescriptions')
          .select()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;

      return MedicineModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getMedicineById');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load medicine.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get medicine: $e');
    }
  }

  /// M2: Creates a new prescription record in `public.prescriptions`.
  Future<MedicineModel> createMedicine({
    required MedicineModel medicine,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create medicine without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }
    if (medicine.medicineName.trim().isEmpty) {
      throw const ValidationException('Medicine name cannot be empty.');
    }
    if (medicine.dosage.trim().isEmpty) {
      throw const ValidationException('Dosage cannot be empty.');
    }

    final cleanId = IdUtils.unprefix(medicine.id).trim();
    final effectiveId =
        UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4();
    final clientUuid = medicine.clientUuid?.trim();
    final effectiveClientUuid =
        (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
            ? clientUuid
            : effectiveId;

    try {
      final payload = medicine
          .copyWith(
            id: effectiveId,
            profileId: cleanProfileId,
            clientUuid: effectiveClientUuid,
          )
          .toSupabaseJson(includeId: true);

      payload['user_id'] = trimmedOwnerId;
      payload['profile_id'] = cleanProfileId;

      final res =
          await _client.from('prescriptions').insert(payload).select().single();

      return MedicineModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createMedicine');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to create medicine.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create medicine: $e');
    }
  }

  /// M4: Updates an existing prescription in `public.prescriptions`.
  Future<MedicineModel> updateMedicine({
    required MedicineModel medicine,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(medicine.id).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update medicine without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException(
        'Medicine ID must be a valid UUID when updating.',
      );
    }
    if (medicine.medicineName.trim().isEmpty) {
      throw const ValidationException('Medicine name cannot be empty.');
    }
    if (medicine.dosage.trim().isEmpty) {
      throw const ValidationException('Dosage cannot be empty.');
    }

    final effectiveProfileId = (profileId != null && profileId.trim().isNotEmpty)
        ? IdUtils.unprefix(profileId).trim()
        : IdUtils.unprefix(medicine.profileId).trim();

    if (effectiveProfileId.isNotEmpty &&
        !UuidUtils.isValidUuid(effectiveProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID.');
    }

    try {
      final updatePayload = medicine
          .copyWith(
            profileId:
                effectiveProfileId.isNotEmpty ? effectiveProfileId : null,
          )
          .toSupabaseJson(includeId: false);

      var query = _client
          .from('prescriptions')
          .update(updatePayload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (effectiveProfileId.isNotEmpty) {
        query = query.eq('profile_id', effectiveProfileId);
      }

      final res = await query.select().single();
      return MedicineModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateMedicine');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to update medicine.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update medicine: $e');
    }
  }

  /// M5: Deletes a prescription from `public.prescriptions`.
  Future<void> deleteMedicine({
    required String medicineId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(medicineId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete medicine without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Medicine ID must be a valid UUID.');
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }

    try {
      var query = _client
          .from('prescriptions')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteMedicine');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to delete medicine.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete medicine: $e');
    }
  }

  AppException _handlePostgrestException(
    PostgrestException e,
    String operation,
  ) {
    final code = e.code ?? '';
    final msg = e.message;

    if (code == '42501') {
      return UnauthorizedException(
        'You do not have permission to perform this prescription operation: $msg',
      );
    }
    if (code == '23503') {
      return ValidationException(
        'Related entity (profile or consultation) not found or invalid: $msg',
      );
    }
    if (code == '23505') {
      return ConflictException(
        'A prescription with this identifier already exists: $msg',
      );
    }
    if (code == '23514') {
      return ValidationException('Validation constraint violation: $msg');
    }
    if (code == 'PGRST116') {
      return NotFoundException('Prescription record not found.');
    }

    return ServerException(
      'Supabase prescription operation failed ($operation): $msg (code: $code)',
    );
  }
}
