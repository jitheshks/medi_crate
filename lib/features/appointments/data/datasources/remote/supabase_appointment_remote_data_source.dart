import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/appointment_model.dart';

/// SupabaseAppointmentRemoteDataSource handles authenticated PostgREST operations
/// on `public.appointments` (AP1–AP5) with PostgreSQL RLS and tenant isolation.
class SupabaseAppointmentRemoteDataSource {
  final SupabaseClient? customClient;

  SupabaseAppointmentRemoteDataSource({SupabaseClient? client})
      : customClient = client;

  SupabaseClient get _client => customClient ?? SupabaseConfig.client;

  /// AP1: Fetches appointments for [profileId] with optional filters and sorting.
  Future<List<AppointmentModel>> fetchAppointments({
    required String ownerUserId,
    required String profileId,
    String? status,
    String? doctorId,
    String? hospitalId,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch appointments without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      var query = _client
          .from('appointments')
          .select()
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

      if (status != null && status.trim().isNotEmpty) {
        query = query.eq('status', status.trim().toLowerCase());
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

      if (from != null && from.trim().isNotEmpty) {
        query = query.gte('appointment_date', from.trim());
      }
      if (to != null && to.trim().isNotEmpty) {
        query = query.lte('appointment_date', to.trim());
      }

      var orderedQuery = query.order('appointment_date', ascending: true);

      final response = limit != null && limit > 0
          ? await orderedQuery.limit(limit)
          : await orderedQuery;

      final appointments = (response as List)
          .map((row) => AppointmentModel.fromSupabaseJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      onTotal?.call(appointments.length);
      return appointments;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchAppointments');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load appointments.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch appointments: $e');
    }
  }

  /// AP3: Retrieves a single appointment encounter by [appointmentId].
  Future<AppointmentModel?> getAppointmentById({
    required String appointmentId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(appointmentId).trim();
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
          .from('appointments')
          .select()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;

      return AppointmentModel.fromSupabaseJson(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getAppointmentById');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to load appointment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get appointment: $e');
    }
  }

  /// AP2: Creates a new appointment record in `public.appointments`.
  Future<AppointmentModel> createAppointment({
    required AppointmentModel appointment,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create appointment without an active authenticated session.',
      );
    }
    if (cleanProfileId.isEmpty || !UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }
    if (appointment.title.trim().isEmpty) {
      throw const ValidationException('Appointment title cannot be empty.');
    }
    if (appointment.doctorName.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }

    final cleanId = IdUtils.unprefix(appointment.id).trim();
    final effectiveId =
        UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4();
    final clientUuid = appointment.clientUuid?.trim();
    final effectiveClientUuid =
        (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
            ? clientUuid
            : effectiveId;

    try {
      final payload = appointment
          .copyWith(
            id: effectiveId,
            profileId: cleanProfileId,
            clientUuid: effectiveClientUuid,
          )
          .toSupabaseJson(includeId: true);

      payload['user_id'] = trimmedOwnerId;
      payload['profile_id'] = cleanProfileId;

      final res =
          await _client.from('appointments').insert(payload).select().single();

      return AppointmentModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createAppointment');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to create appointment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create appointment: $e');
    }
  }

  /// AP4: Updates an existing appointment in `public.appointments`.
  Future<AppointmentModel> updateAppointment({
    required AppointmentModel appointment,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(appointment.id).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update appointment without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException(
        'Appointment ID must be a valid UUID when updating.',
      );
    }
    if (appointment.title.trim().isEmpty) {
      throw const ValidationException('Appointment title cannot be empty.');
    }
    if (appointment.doctorName.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }

    final effectiveProfileId = (profileId != null && profileId.trim().isNotEmpty)
        ? IdUtils.unprefix(profileId).trim()
        : IdUtils.unprefix(appointment.profileId).trim();

    if (effectiveProfileId.isNotEmpty &&
        !UuidUtils.isValidUuid(effectiveProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID.');
    }

    try {
      final updatePayload = appointment
          .copyWith(
            profileId:
                effectiveProfileId.isNotEmpty ? effectiveProfileId : null,
          )
          .toSupabaseJson(includeId: false);

      var query = _client
          .from('appointments')
          .update(updatePayload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (effectiveProfileId.isNotEmpty) {
        query = query.eq('profile_id', effectiveProfileId);
      }

      final res = await query.select().single();
      return AppointmentModel.fromSupabaseJson(
        Map<String, dynamic>.from(res),
      );
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateAppointment');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to update appointment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update appointment: $e');
    }
  }

  /// AP5: Deletes an appointment from `public.appointments`.
  Future<void> deleteAppointment({
    required String appointmentId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(appointmentId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete appointment without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Appointment ID must be a valid UUID.');
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
          .from('appointments')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteAppointment');
    } on SocketException {
      throw const NetworkException(
        'Internet connection required to delete appointment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete appointment: $e');
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
        'You do not have permission to perform this appointment operation: $msg',
      );
    }
    if (code == '23503') {
      return ValidationException(
        'Related entity (profile, doctor, or hospital) not found or invalid: $msg',
      );
    }
    if (code == '23505') {
      return ConflictException(
        'An appointment with this identifier already exists: $msg',
      );
    }
    if (code == '23514') {
      return ValidationException('Validation constraint violation: $msg');
    }
    if (code == 'PGRST116') {
      return NotFoundException('Appointment record not found.');
    }

    return ServerException(
      'Supabase appointment operation failed ($operation): $msg (code: $code)',
    );
  }
}
