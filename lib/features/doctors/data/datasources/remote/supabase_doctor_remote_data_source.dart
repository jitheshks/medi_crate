import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/doctor_model.dart';

/// SupabaseDoctorRemoteDataSource handles direct authenticated PostgREST
/// operations on `public.doctors` and `public.doctor_hospitals` (D1 - D5).
class SupabaseDoctorRemoteDataSource {
  final SupabaseClient? customClient;

  SupabaseDoctorRemoteDataSource({this.customClient});

  SupabaseClient get _client {
    if (customClient != null) return customClient!;
    return SupabaseConfig.client;
  }

  /// D1: Lists doctors for the authenticated user and specified profile.
  Future<List<DoctorModel>> fetchDoctors({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? specialty,
    String? hospitalId,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch doctors without a valid authenticated user ID.',
      );
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException(
        'Cannot fetch doctors without a valid profile ID.',
      );
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException(
        'Profile ID must be a valid UUID for Supabase operations.',
      );
    }

    try {
      final cleanFilterHospitalId = hospitalId != null
          ? IdUtils.unprefix(hospitalId).trim()
          : null;

      List<String>? matchingDocIds;
      if (cleanFilterHospitalId != null && cleanFilterHospitalId.isNotEmpty) {
        if (!UuidUtils.isValidUuid(cleanFilterHospitalId)) {
          throw const ValidationException(
            'Hospital filter ID must be a valid UUID.',
          );
        }

        final affiliationsRes = await _client
            .from('doctor_hospitals')
            .select('doctor_id')
            .eq('user_id', trimmedOwnerId)
            .eq('hospital_id', cleanFilterHospitalId);

        matchingDocIds = (affiliationsRes as List)
            .map((r) => (r as Map)['doctor_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        if (matchingDocIds.isEmpty) {
          onTotal?.call(0);
          return [];
        }
      }

      var query = _client
          .from('doctors')
          .select()
          .eq('user_id', trimmedOwnerId)
          .eq('profile_id', cleanProfileId);

      if (matchingDocIds != null) {
        query = query.inFilter('id', matchingDocIds);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or(
          'name.ilike.%$term%,specialty.ilike.%$term%,hospital_name.ilike.%$term%',
        );
      }

      if (specialty != null && specialty.trim().isNotEmpty) {
        query = query.ilike('specialty', specialty.trim());
      }

      var orderedQuery = query.order('name', ascending: true);

      final response = limit != null && limit > 0
          ? await orderedQuery.limit(limit)
          : await orderedQuery;

      final rawDoctors = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final docIds = rawDoctors
          .map((d) => d['id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      // Query affiliations for retrieved doctors to populate hospitalIds
      Map<String, List<String>> affiliationsMap = {};
      if (docIds.isNotEmpty) {
        try {
          final affiliationsRes = await _client
              .from('doctor_hospitals')
              .select('doctor_id, hospital_id')
              .eq('user_id', trimmedOwnerId)
              .inFilter('doctor_id', docIds);

          for (final row in affiliationsRes as List) {
            if (row is Map && row['doctor_id'] != null && row['hospital_id'] != null) {
              final docId = row['doctor_id'].toString();
              final hospId = row['hospital_id'].toString();
              affiliationsMap.putIfAbsent(docId, () => []).add(hospId);
            }
          }
        } catch (_) {}
      }

      final List<DoctorModel> doctors = [];
      for (final raw in rawDoctors) {
        final docId = raw['id']?.toString() ?? '';
        final affiliatedHospIds = affiliationsMap[docId] ?? [];
        raw['hospital_ids'] = affiliatedHospIds;
        doctors.add(DoctorModel.fromSupabaseJson(raw));
      }

      onTotal?.call(doctors.length);
      return doctors;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'fetchDoctors');
    } on SocketException {
      throw const NetworkException('Internet connection required to load doctors.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch doctors: $e');
    }
  }

  /// D3: Fetches a single doctor by ID with strict ownership validation.
  Future<DoctorModel?> getDoctorById({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(doctorId).trim();
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
          .from('doctors')
          .select()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.maybeSingle();
      if (response == null) return null;

      final doctorMap = Map<String, dynamic>.from(response);

      // Query affiliations for this doctor
      try {
        final affiliationsRes = await _client
            .from('doctor_hospitals')
            .select('hospital_id')
            .eq('doctor_id', cleanId)
            .eq('user_id', trimmedOwnerId);

        final List<String> hospitalIds = [];
        for (final row in affiliationsRes as List) {
          if (row is Map && row['hospital_id'] != null) {
            hospitalIds.add(row['hospital_id'].toString());
          }
        }
        doctorMap['hospital_ids'] = hospitalIds;
      } catch (_) {}

      return DoctorModel.fromSupabaseJson(doctorMap);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'getDoctorById');
    } on SocketException {
      throw const NetworkException('Internet connection required to load doctor.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to get doctor: $e');
    }
  }

  /// D2: Creates a new doctor record in `public.doctors` and links hospital affiliations.
  Future<DoctorModel> createDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    required String profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanProfileId = IdUtils.unprefix(profileId).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create doctor without an active authenticated session.',
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
    if (doctor.name.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }
    if (doctor.specialty.trim().isEmpty) {
      throw const ValidationException('Doctor specialty cannot be empty.');
    }

    final cleanDocId = IdUtils.unprefix(doctor.id).trim();
    final effectiveId = UuidUtils.isValidUuid(cleanDocId)
        ? cleanDocId
        : UuidUtils.generateV4();

    final clientUuid = doctor.clientUuid?.trim();
    final effectiveClientUuid = (clientUuid != null && UuidUtils.isValidUuid(clientUuid))
        ? clientUuid
        : effectiveId;

    final validHospIds = doctor.hospitalIds
        .map((hId) => IdUtils.unprefix(hId).trim())
        .where((hId) => UuidUtils.isValidUuid(hId))
        .toSet()
        .toList();

    // 1. Attempt atomic RPC save (single transaction)
    try {
      final rpcRes = await _client.rpc(
        'save_doctor_with_affiliations',
        params: {
          'p_profile_id': cleanProfileId,
          'p_name': doctor.name.trim(),
          'p_specialty': doctor.specialty.trim(),
          'p_doctor_id': effectiveId,
          'p_client_uuid': effectiveClientUuid,
          'p_hospital_name': doctor.hospitalName?.trim(),
          'p_phone': doctor.phone?.trim(),
          'p_email': doctor.email?.trim(),
          'p_notes': doctor.notes?.trim(),
          'p_is_favorite': doctor.isFavorite,
          'p_hospital_ids': validHospIds,
        },
      );

      if (rpcRes != null) {
        return DoctorModel.fromSupabaseJson(
          Map<String, dynamic>.from(rpcRes as Map),
        );
      }
    } on PostgrestException catch (e) {
      // If RPC is missing in non-migrated environment (PGRST202 / 42883), fallback to direct calls
      if (e.code != 'PGRST202' && e.code != '42883') {
        throw _handlePostgrestException(e, 'createDoctor');
      }
    } catch (_) {}

    final preparedDoctor = doctor.copyWith(
      id: effectiveId,
      profileId: cleanProfileId,
      clientUuid: effectiveClientUuid,
    );

    final payload = preparedDoctor.toSupabaseJson(
      ownerUserId: trimmedOwnerId,
      profileId: cleanProfileId,
      includeId: true,
    );

    try {
      final response = await _client
          .from('doctors')
          .insert(payload)
          .select()
          .single();

      final createdMap = Map<String, dynamic>.from(response);

      // Insert hospital affiliations into `public.doctor_hospitals`
      if (validHospIds.isNotEmpty) {
        final junctionRows = validHospIds
            .map(
              (hId) => {
                'doctor_id': effectiveId,
                'hospital_id': hId,
                'user_id': trimmedOwnerId,
              },
            )
            .toList();

        try {
          await _client.from('doctor_hospitals').insert(junctionRows);
        } catch (e) {
          // Rollback created doctor if junction fails
          try {
            await _client
                .from('doctors')
                .delete()
                .eq('id', effectiveId)
                .eq('user_id', trimmedOwnerId);
          } catch (_) {}
          if (e is PostgrestException) {
            throw _handlePostgrestException(e, 'createDoctor.affiliations');
          }
          throw ServerException('Failed to link hospital affiliations: $e');
        }
      }

      createdMap['hospital_ids'] = validHospIds;
      return DoctorModel.fromSupabaseJson(createdMap);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'createDoctor');
    } on SocketException {
      throw const NetworkException('Internet connection required to create doctor.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create doctor: $e');
    }
  }

  /// D4: Updates an existing doctor row with whitelisted mutable fields.
  Future<DoctorModel> updateDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    String? profileId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final cleanId = IdUtils.unprefix(doctor.id).trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update doctor without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Doctor ID must be a valid UUID when updating.');
    }
    if (doctor.name.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }
    if (doctor.specialty.trim().isEmpty) {
      throw const ValidationException('Doctor specialty cannot be empty.');
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }

    final validHospIds = doctor.hospitalIds
        .map((hId) => IdUtils.unprefix(hId).trim())
        .where((hId) => UuidUtils.isValidUuid(hId))
        .toSet()
        .toList();

    // 1. Attempt atomic RPC save (single transaction)
    if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
      try {
        final rpcRes = await _client.rpc(
          'save_doctor_with_affiliations',
          params: {
            'p_profile_id': cleanProfileId,
            'p_name': doctor.name.trim(),
            'p_specialty': doctor.specialty.trim(),
            'p_doctor_id': cleanId,
            'p_client_uuid': doctor.clientUuid?.trim(),
            'p_hospital_name': doctor.hospitalName?.trim(),
            'p_phone': doctor.phone?.trim(),
            'p_email': doctor.email?.trim(),
            'p_notes': doctor.notes?.trim(),
            'p_is_favorite': doctor.isFavorite,
            'p_hospital_ids': validHospIds,
          },
        );

        if (rpcRes != null) {
          return DoctorModel.fromSupabaseJson(
            Map<String, dynamic>.from(rpcRes as Map),
          );
        }
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST202' && e.code != '42883') {
          throw _handlePostgrestException(e, 'updateDoctor');
        }
      } catch (_) {}
    }

    final payload = <String, dynamic>{
      'name': doctor.name.trim(),
      'specialty': doctor.specialty.trim(),
      if (doctor.hospitalName != null) 'hospital_name': doctor.hospitalName!.trim(),
      'phone': doctor.phone?.trim(),
      'email': doctor.email?.trim(),
      'notes': doctor.notes?.trim(),
      'is_favorite': doctor.isFavorite,
    };

    try {
      var query = _client
          .from('doctors')
          .update(payload)
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        query = query.eq('profile_id', cleanProfileId);
      }

      final response = await query.select().single();
      final updatedMap = Map<String, dynamic>.from(response);

      // Sync doctor-hospital affiliations
      try {
        await _client
            .from('doctor_hospitals')
            .delete()
            .eq('doctor_id', cleanId)
            .eq('user_id', trimmedOwnerId);

        if (validHospIds.isNotEmpty) {
          final junctionRows = validHospIds
              .map(
                (hId) => {
                  'doctor_id': cleanId,
                  'hospital_id': hId,
                  'user_id': trimmedOwnerId,
                },
              )
              .toList();

          await _client.from('doctor_hospitals').insert(junctionRows);
        }
      } catch (e) {
        if (e is PostgrestException) {
          throw _handlePostgrestException(e, 'updateDoctor.affiliations');
        }
        throw ServerException('Failed to update hospital affiliations: $e');
      }

      updatedMap['hospital_ids'] = validHospIds;
      return DoctorModel.fromSupabaseJson(updatedMap);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'updateDoctor');
    } on SocketException {
      throw const NetworkException('Internet connection required to update doctor.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update doctor: $e');
    }
  }

  /// D5: Deletes a doctor from `public.doctors`.
  Future<void> deleteDoctor({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(doctorId).trim();
    final trimmedOwnerId = ownerUserId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot delete doctor without an active authenticated session.',
      );
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Doctor ID must be a valid UUID.');
    }

    String? cleanProfileId;
    if (profileId != null && profileId.trim().isNotEmpty) {
      cleanProfileId = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProfileId)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }

    try {
      // Junction rows cascade delete via fk_doctor_hospitals_doctor
      var query = _client
          .from('doctors')
          .delete()
          .eq('id', cleanId)
          .eq('user_id', trimmedOwnerId);

      if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
        query = query.eq('profile_id', cleanProfileId);
      }

      await query;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e, 'deleteDoctor');
    } on SocketException {
      throw const NetworkException('Internet connection required to delete doctor.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete doctor: $e');
    }
  }

  AppException _handlePostgrestException(PostgrestException e, String operation) {
    final code = e.code;
    final message = e.message;
    if (code == 'PGRST116') {
      return NotFoundException('$operation: Doctor record not found.');
    }
    if (code == '42501' || message.toLowerCase().contains('permission denied')) {
      return UnauthorizedException('Access denied during $operation: $message');
    }
    if (code == '23505') {
      return ConflictException('A clinician with this identifier already exists: $message');
    }
    if (code == '23503') {
      return ValidationException('Foreign key constraint violation during $operation: $message');
    }
    return ServerException('Database error during $operation: $message', code: code);
  }
}
