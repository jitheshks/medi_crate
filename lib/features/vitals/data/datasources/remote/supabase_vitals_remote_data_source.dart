import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/measurement_model.dart';

/// SupabaseVitalsRemoteDataSource handles authenticated PostgREST operations
/// on `public.measurements` (V0–V5) with PostgreSQL RLS and tenant isolation.
class SupabaseVitalsRemoteDataSource {
  final SupabaseClient? customClient;

  SupabaseVitalsRemoteDataSource({SupabaseClient? client})
      : customClient = client;

  SupabaseClient get _client => customClient ?? SupabaseConfig.client;

  /// V2: Fetches vital measurements for [profileId] with optional filters.
  Future<List<MeasurementModel>> fetchMeasurements({
    required String ownerUserId,
    required String profileId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch measurements without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      var query = _client
          .from('measurements')
          .select()
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

      if (type != null && type.trim().isNotEmpty) {
        final lowerType = type.trim().toLowerCase();
        if (lowerType == 'blood_pressure' || lowerType == 'bp') {
          query = query.inFilter('type', ['blood_pressure', 'bp']);
        } else if (lowerType == 'blood_glucose' || lowerType == 'glucose') {
          query = query.inFilter('type', ['blood_glucose', 'glucose']);
        } else {
          query = query.eq('type', lowerType);
        }
      }

      if (fromDate != null) {
        query = query.gte('recorded_at', fromDate.toUtc().toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('recorded_at', toDate.toUtc().toIso8601String());
      }

      var orderedQuery = query.order('recorded_at', ascending: false);

      final response = limit != null && limit > 0
          ? await orderedQuery.limit(limit)
          : await orderedQuery;

      final measurements = (response as List)
          .map((row) => MeasurementModel.fromSupabaseJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      onTotal?.call(measurements.length);
      return measurements;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchMeasurements');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load measurements.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch measurements: $e');
    }
  }

  /// V3: Retrieves a single vital measurement by [measurementId].
  Future<MeasurementModel?> getMeasurementById({
    required String measurementId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(measurementId).trim();
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
          .from('measurements')
          .select()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;

      return MeasurementModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getMeasurementById');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load measurement.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get measurement: $e');
    }
  }

  /// V1: Creates a new vital measurement record in `public.measurements`.
  Future<MeasurementModel> createMeasurement({
    required MeasurementModel measurement,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create measurement without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    final cleanId = IdUtils.unprefix(measurement.id).trim();
    final effectiveId =
        UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4();
    final clientUuid = measurement.clientUuid?.trim();
    final effectiveClientUuid =
        (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
            ? clientUuid
            : effectiveId;

    try {
      final payload = measurement
          .copyWith(
            id: effectiveId,
            profileId: cleanProfileId,
            clientUuid: effectiveClientUuid,
          )
          .toSupabaseJson(includeId: true);

      payload['user_id'] = trimmedOwnerId;
      payload['profile_id'] = cleanProfileId;

      final res = await _client
          .from('measurements')
          .insert(payload)
          .select()
          .single();

      return MeasurementModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createMeasurement');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to create measurement.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create measurement: $e');
    }
  }

  /// V4: Updates an existing vital measurement in `public.measurements`.
  Future<MeasurementModel> updateMeasurement({
    required MeasurementModel measurement,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(measurement.id).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update measurement without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException(
        'Measurement ID must be a valid UUID when updating.',
      );
    }

    final effectiveProfileId =
        (profileId != null && profileId.trim().isNotEmpty)
            ? IdUtils.unprefix(profileId).trim()
            : IdUtils.unprefix(measurement.profileId).trim();

    if (effectiveProfileId.isNotEmpty &&
        !UuidUtils.isValidUuid(effectiveProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID.');
    }

    try {
      final updatePayload = measurement
          .copyWith(
            profileId:
                effectiveProfileId.isNotEmpty ? effectiveProfileId : null,
          )
          .toSupabaseJson(includeId: false);

      var query = _client
          .from('measurements')
          .update(updatePayload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (effectiveProfileId.isNotEmpty) {
        query = query.eq('profile_id', effectiveProfileId);
      }

      final res = await query.select().single();
      return MeasurementModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateMeasurement');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to update measurement.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update measurement: $e');
    }
  }

  /// V5: Deletes a vital measurement from `public.measurements`.
  Future<void> deleteMeasurement({
    required String measurementId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(measurementId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete measurement without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Measurement ID must be a valid UUID.');
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
          .from('measurements')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteMeasurement');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to delete measurement.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete measurement: $e');
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
        'You do not have permission to perform this measurement operation: $msg',
      );
    }
    if (code == '23503') {
      return ValidationException(
        'Related profile not found or invalid: $msg',
      );
    }
    if (code == '23505') {
      return ConflictException(
        'A measurement with this identifier already exists: $msg',
      );
    }
    if (code == '23514') {
      return ValidationException('Validation constraint violation: $msg');
    }
    if (code == 'PGRST116') {
      return const NotFoundException('Measurement record not found.');
    }

    return ServerException(
      'Supabase measurement operation failed ($operation): $msg (code: $code)',
    );
  }
}
