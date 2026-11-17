import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/hospital_model.dart';

/// SupabaseHospitalRemoteDataSource handles direct authenticated PostgREST
/// operations on `public.hospitals` (H1 - H5).
class SupabaseHospitalRemoteDataSource {
  final SupabaseClient? customClient;

  SupabaseHospitalRemoteDataSource({this.customClient});

  SupabaseClient get _client {
    if (customClient != null) return customClient!;
    return SupabaseConfig.client;
  }

  /// H1: Lists hospitals for the authenticated user and specified profile.
  Future<List<HospitalModel>> fetchHospitals({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? type,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch hospitals without a valid authenticated user ID.',
      );
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException(
        'Cannot fetch hospitals without a valid profile ID.',
      );
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      var query = _client
          .from('hospitals')
          .select()
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.ilike('name', '%$term%');
      }

      if (type != null && type.trim().isNotEmpty) {
        query = query.ilike('type', type.trim());
      }

      var orderedQuery = query.order('name', ascending: true);

      if (limit != null && limit > 0) {
        final response = await orderedQuery.limit(limit);
        final list = (response as List)
            .map(
              (item) => HospitalModel.fromSupabaseJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        onTotal?.call(list.length);
        return list;
      }

      final response = await orderedQuery;
      final list = (response as List)
          .map(
            (item) => HospitalModel.fromSupabaseJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      onTotal?.call(list.length);
      return list;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchHospitals');
    } on SocketException {
      throw const NetworkException('Internet connection required to load hospitals.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch hospitals: $e');
    }
  }

  /// H3: Fetches a single hospital by ID with strict ownership validation.
  Future<HospitalModel?> getHospitalById({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(hospitalId).trim();
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
          .from('hospitals')
          .select()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;
      return HospitalModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getHospitalById');
    } on SocketException {
      throw const NetworkException('Internet connection required to load hospital.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get hospital: $e');
    }
  }

  /// H2: Creates a new hospital record in `public.hospitals`.
  Future<HospitalModel> createHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create hospital without an active authenticated session.',
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
    if (hospital.name.trim().isEmpty) {
      throw const ValidationException('Facility name cannot be empty.');
    }

    // Ensure hospital has a valid UUID for id if client-assigned or generate one
    final cleanDocId = IdUtils.unprefix(hospital.id).trim();
    final effectiveId = UuidUtils.isValidUuid(cleanDocId)
        ? cleanDocId
        : UuidUtils.generateV4();

    final clientUuid = hospital.clientUuid?.trim();
    final effectiveClientUuid = (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
        ? clientUuid
        : effectiveId;

    final preparedHospital = hospital.copyWith(
      id: effectiveId,
      profileId: cleanProfileId,
      clientUuid: effectiveClientUuid,
    );

    final payload = preparedHospital.toSupabaseJson(
      ownerUserId: trimmedOwnerId,
      profileId: cleanProfileId,
      includeId: true,
    );

    try {
      final response = await _client
          .from('hospitals')
          .insert(payload)
          .select()
          .single();

      return HospitalModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createHospital');
    } on SocketException {
      throw const NetworkException('Internet connection required to create hospital.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create hospital: $e');
    }
  }

  /// H4: Updates an existing hospital row with whitelisted mutable fields.
  Future<HospitalModel> updateHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    String? profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanId = IdUtils.unprefix(hospital.id).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update hospital without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Hospital ID must be a valid UUID when updating.');
    }
    if (hospital.name.trim().isEmpty) {
      throw const ValidationException('Facility name cannot be empty.');
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }

    final payload = <String, dynamic>{
      'name': hospital.name.trim(),
      'type': HospitalModel.normalizeType(hospital.type),
      'address': hospital.address?.trim(),
      'city': hospital.city?.trim(),
      'state': hospital.state?.trim(),
      'country': hospital.country?.trim(),
      'phone': hospital.phone?.trim(),
      'email': hospital.email?.trim(),
      'website': hospital.website?.trim(),
      'notes': hospital.notes?.trim(),
    };

    try {
      var query = _client
          .from('hospitals')
          .update(payload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.select().single();

      return HospitalModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateHospital');
    } on SocketException {
      throw const NetworkException('Internet connection required to update hospital.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update hospital: $e');
    }
  }

  /// H5: Deletes a hospital row with strict ownership verification.
  Future<void> deleteHospital({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanId = IdUtils.unprefix(hospitalId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete hospital without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Hospital ID must be a valid UUID.');
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
          .from('hospitals')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteHospital');
    } on SocketException {
      throw const NetworkException('Internet connection required to delete hospital.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete hospital: $e');
    }
  }

  AppException _handlePostgrestException(PostgrestException e, String operation) {
    final code = e.code;
    final message = e.message;
    if (code == 'PGRST116') {
      return NotFoundException('$operation: Hospital record not found.');
    }
    if (code == '42501' || message.toLowerCase().contains('permission denied')) {
      return UnauthorizedException('Access denied during $operation: $message');
    }
    if (code == '23505') {
      return ConflictException('A facility with this identifier already exists: $message');
    }
    if (code == '23503') {
      return ValidationException('Foreign key constraint violation during $operation: $message');
    }
    return ServerException('Database error during $operation: $message', code: code);
  }
}
