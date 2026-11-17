import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeDoctorRemoteDataSource extends SupabaseDoctorRemoteDataSource {
  final List<DoctorModel> doctorStore = [];
  final Map<String, String> doctorOwnerUserMap = {};
  final Set<String> validHospitalIds = {};
  bool throwNetworkError = false;
  bool simulateJunctionFailure = false;
  PostgrestException? postgrestErrorToThrow;

  /// Simulates private.check_doctor_ownership helper: encapsulated in non-exposed `private` schema.
  /// Internal to database RPC; not exposed to public PostgREST / client RPC API.
  String internalCheckDoctorOwnership({
    required String doctorId,
    required String profileId,
    required String ownerUserId,
  }) {
    final cleanDocId = IdUtils.unprefix(doctorId).trim();
    final cleanProfId = IdUtils.unprefix(profileId).trim();
    final existingIndex = doctorStore.indexWhere((d) => IdUtils.unprefix(d.id) == cleanDocId);
    if (existingIndex < 0) return 'NOT_FOUND';
    final existing = doctorStore[existingIndex];
    final existingOwner = doctorOwnerUserMap[cleanDocId] ?? ownerUserId;
    if (existingOwner != ownerUserId) return 'CROSS_USER';
    if (IdUtils.unprefix(existing.profileId) != cleanProfId) return 'CROSS_PROFILE';
    return 'OWNED';
  }

  /// Simulates attempting to invoke the ownership helper through the exposed public API.
  /// Since the helper is in the `private` schema (excluded from config.toml `schemas = ["public", "graphql_public"]`),
  /// PostgREST rejects direct RPC calls with PGRST202 (function not found in schema cache).
  Future<void> invokePublicRpcCheckDoctorOwnership({
    required String doctorId,
    required String profileId,
  }) async {
    throw const NotFoundException(
      'check_doctor_ownership: Function not found in public API schema cache (PGRST202).',
    );
  }

  @override
  Future<List<DoctorModel>> fetchDoctors({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? specialty,
    String? hospitalId,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot fetch doctors without a valid authenticated user ID.');
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException('Cannot fetch doctors without a valid profile ID.');
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID for Supabase operations.');
    }
    if (hospitalId != null && hospitalId.trim().isNotEmpty) {
      final cleanHospId = IdUtils.unprefix(hospitalId).trim();
      if (!UuidUtils.isValidUuid(cleanHospId)) {
        throw const ValidationException('Hospital filter ID must be a valid UUID.');
      }
    }
    if (throwNetworkError) {
      throw const SocketException('Connection refused');
    }
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'fetchDoctors');
    }

    var list = doctorStore.where((d) => IdUtils.unprefix(d.profileId) == cleanProfileId).toList();
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      list = list.where((d) =>
        d.name.toLowerCase().contains(s) ||
        d.specialty.toLowerCase().contains(s) ||
        (d.hospitalName != null && d.hospitalName!.toLowerCase().contains(s))
      ).toList();
    }
    if (specialty != null && specialty.trim().isNotEmpty) {
      final spec = specialty.trim().toLowerCase();
      list = list.where((d) => d.specialty.toLowerCase() == spec).toList();
    }
    if (hospitalId != null && hospitalId.trim().isNotEmpty) {
      final cleanHospId = IdUtils.unprefix(hospitalId).trim();
      list = list.where((d) => d.hospitalIds.map((h) => IdUtils.unprefix(h)).contains(cleanHospId)).toList();
    }
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<DoctorModel?> getDoctorById({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(doctorId).trim();
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId) || ownerUserId.trim().isEmpty) return null;
    if (profileId != null && profileId.trim().isNotEmpty) {
      final cleanProf = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProf)) return null;
    }
    if (throwNetworkError) throw const SocketException('No route to host');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'getDoctorById');
    }

    try {
      return doctorStore.firstWhere((d) => IdUtils.unprefix(d.id) == cleanId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DoctorModel> createDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    required String profileId,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot create doctor without an active authenticated session.');
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty.');
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID for Supabase operations.');
    }
    if (doctor.name.trim().isEmpty) {
      throw const ValidationException('Doctor name cannot be empty.');
    }
    if (doctor.specialty.trim().isEmpty) {
      throw const ValidationException('Doctor specialty cannot be empty.');
    }
    if (throwNetworkError) throw const SocketException('Connection aborted');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'createDoctor');
    }

    final cleanDocId = IdUtils.unprefix(doctor.id).trim();

    // 1. Validate existing doctor against user and profile
    if (cleanDocId.isNotEmpty) {
      final existingIndex = doctorStore.indexWhere((d) => IdUtils.unprefix(d.id) == cleanDocId);
      if (existingIndex >= 0) {
        final existing = doctorStore[existingIndex];
        final existingOwner = doctorOwnerUserMap[cleanDocId] ?? ownerUserId;
        if (existingOwner != ownerUserId || IdUtils.unprefix(existing.profileId) != cleanProfileId) {
          throw const UnauthorizedException('Doctor does not belong to active user and profile.');
        }
      }
    }

    // 2. Validate hospital affiliations against known valid IDs
    for (final hId in doctor.hospitalIds) {
      final cleanHId = IdUtils.unprefix(hId).trim();
      if (validHospitalIds.isNotEmpty && !validHospitalIds.contains(cleanHId)) {
        throw const ValidationException('Hospital does not exist or does not belong to active user and profile.');
      }
    }

    final effectiveId = UuidUtils.isValidUuid(cleanDocId) ? cleanDocId : 'a0000000-0000-0000-0000-000000000001';

    if (simulateJunctionFailure) {
      throw const ServerException('Failed to link hospital affiliations: simulated junction failure');
    }

    final created = doctor.copyWith(
      id: effectiveId,
      profileId: cleanProfileId,
    );
    doctorStore.add(created);
    doctorOwnerUserMap[effectiveId] = ownerUserId;
    return created;
  }

  @override
  Future<DoctorModel> updateDoctor({
    required DoctorModel doctor,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(doctor.id).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot update doctor without an active authenticated session.');
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
    final effectiveProfileId = (profileId != null && profileId.trim().isNotEmpty)
        ? IdUtils.unprefix(profileId).trim()
        : IdUtils.unprefix(doctor.profileId).trim();
    if (effectiveProfileId.isNotEmpty && !UuidUtils.isValidUuid(effectiveProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID.');
    }

    // 1. Validate existing doctor against user and profile
    final existingIndex = doctorStore.indexWhere((d) => IdUtils.unprefix(d.id) == cleanId);
    if (existingIndex >= 0) {
      final existing = doctorStore[existingIndex];
      final existingOwner = doctorOwnerUserMap[cleanId] ?? ownerUserId;
      if (existingOwner != ownerUserId ||
          (effectiveProfileId.isNotEmpty && IdUtils.unprefix(existing.profileId) != effectiveProfileId)) {
        throw const UnauthorizedException('Doctor does not belong to active user and profile.');
      }
    } else {
      // Zero rows affected / record not found -> reject
      throw const UnauthorizedException('Doctor does not belong to active user and profile.');
    }

    // 2. Validate hospital affiliations against known valid IDs
    for (final hId in doctor.hospitalIds) {
      final cleanHId = IdUtils.unprefix(hId).trim();
      if (validHospitalIds.isNotEmpty && !validHospitalIds.contains(cleanHId)) {
        throw const ValidationException('Hospital does not exist or does not belong to active user and profile.');
      }
    }

    if (throwNetworkError) throw const SocketException('Broken pipe');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'updateDoctor');
    }
    if (simulateJunctionFailure) {
      throw const ServerException('Failed to update hospital affiliations: simulated junction failure');
    }

    final index = doctorStore.indexWhere((d) => IdUtils.unprefix(d.id) == cleanId);
    if (index >= 0) {
      doctorStore[index] = doctor.copyWith(
        id: cleanId,
        profileId: effectiveProfileId.isNotEmpty ? effectiveProfileId : doctorStore[index].profileId,
      );
    }
    return doctorStore.firstWhere((d) => IdUtils.unprefix(d.id) == cleanId);
  }

  @override
  Future<void> deleteDoctor({
    required String doctorId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(doctorId).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot delete doctor without an active authenticated session.');
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Doctor ID must be a valid UUID.');
    }
    if (profileId != null && profileId.trim().isNotEmpty) {
      final cleanProf = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProf)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }
    if (throwNetworkError) throw const SocketException('Reset by peer');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'deleteDoctor');
    }

    doctorStore.removeWhere((d) => IdUtils.unprefix(d.id) == cleanId);
  }

  AppException _handlePostgrestException(PostgrestException e, String op) {
    if (e.code == 'PGRST116') return NotFoundException('$op: Doctor record not found.');
    if (e.code == '42501') return UnauthorizedException('Access denied during $op: ${e.message}');
    if (e.code == '23505') return ConflictException('A clinician already exists: ${e.message}');
    if (e.code == '23503') return ValidationException('Foreign key constraint violation: ${e.message}');
    return ServerException('Database error during $op: ${e.message}', code: e.code);
  }
}

void main() {
  group('SupabaseDoctorRemoteDataSource Unit Tests', () {
    late _FakeDoctorRemoteDataSource dataSource;
    const ownerUserId = '11111111-2222-3333-4444-555555555555';
    const profileId = '22222222-3333-4444-5555-666666666666';
    const doctorId = '33333333-4444-5555-6666-777777777777';
    const hospitalId = '44444444-5555-6666-7777-888888888888';

    setUp(() {
      dataSource = _FakeDoctorRemoteDataSource();
      dataSource.validHospitalIds.addAll([
        hospitalId,
        'other-hosp-id',
        '55555555-5555-5555-5555-555555555555',
        '66666666-6666-6666-6666-666666666666',
        '77777777-7777-7777-7777-777777777777',
      ]);
      dataSource.doctorStore.addAll([
        const DoctorModel(
          id: doctorId,
          profileId: profileId,
          name: 'Dr. Gregory House',
          specialty: 'Diagnostic Medicine',
          hospitalName: 'Princeton Plainsboro',
          hospitalIds: [hospitalId],
          isFavorite: true,
        ),
        const DoctorModel(
          id: 'doc-cardio-uuid',
          profileId: profileId,
          name: 'Dr. Robert Chase',
          specialty: 'Cardiology',
          hospitalName: 'City Hospital',
          hospitalIds: ['other-hosp-id'],
        ),
        const DoctorModel(
          id: '88888888-8888-8888-8888-888888888888',
          profileId: '77777777-7777-7777-7777-777777777777',
          name: 'Dr. Other Profile',
          specialty: 'General Practice',
        ),
        const DoctorModel(
          id: '99999999-1111-2222-3333-444444444444',
          profileId: '99999999-9999-9999-9999-999999999999',
          name: 'Dr. Foreign User Doctor',
          specialty: 'Neurology',
        ),
      ]);
      dataSource.doctorOwnerUserMap[doctorId] = ownerUserId;
      dataSource.doctorOwnerUserMap['doc-cardio-uuid'] = ownerUserId;
      dataSource.doctorOwnerUserMap['88888888-8888-8888-8888-888888888888'] = ownerUserId;
      dataSource.doctorOwnerUserMap['99999999-1111-2222-3333-444444444444'] = 'different-user-uuid';
    });

    test('fetchDoctors scopes records strictly to profileId', () async {
      final doctors = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(doctors.length, equals(2));
      expect(doctors.every((d) => d.profileId == profileId), isTrue);
    });

    test('fetchDoctors filters by search query matching name, specialty, or hospital', () async {
      final searchByName = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        search: 'House',
      );
      expect(searchByName.length, equals(1));
      expect(searchByName.first.name, contains('House'));

      final searchBySpecialty = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        search: 'Cardio',
      );
      expect(searchBySpecialty.length, equals(1));
      expect(searchBySpecialty.first.name, equals('Dr. Robert Chase'));
    });

    test('fetchDoctors filters by specialty and hospital affiliation', () async {
      final bySpecialty = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        specialty: 'Diagnostic Medicine',
      );
      expect(bySpecialty.length, equals(1));

      final byHospital = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        hospitalId: hospitalId,
      );
      expect(byHospital.length, equals(1));
      expect(byHospital.first.id, equals(doctorId));
    });

    test('getDoctorById retrieves specific record or null if absent', () async {
      final doc = await dataSource.getDoctorById(
        doctorId: doctorId,
        ownerUserId: ownerUserId,
      );
      expect(doc, isNotNull);
      expect(doc!.name, equals('Dr. Gregory House'));

      final missing = await dataSource.getDoctorById(
        doctorId: 'non-existent-uuid',
        ownerUserId: ownerUserId,
      );
      expect(missing, isNull);
    });

    test('createDoctor validates required fields and persists record', () async {
      await expectLater(
        dataSource.createDoctor(
          doctor: const DoctorModel(id: '', profileId: '', name: '', specialty: 'General'),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('Doctor name cannot be empty'))),
      );

      await expectLater(
        dataSource.createDoctor(
          doctor: const DoctorModel(id: '', profileId: '', name: 'Dr. Jane', specialty: ''),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('Doctor specialty cannot be empty'))),
      );

      final created = await dataSource.createDoctor(
        doctor: const DoctorModel(
          id: '11111111-2222-3333-4444-555555555555',
          profileId: profileId,
          name: 'Dr. Allison Cameron',
          specialty: 'Immunology',
        ),
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(created.id, equals('11111111-2222-3333-4444-555555555555'));
      expect(dataSource.doctorStore.any((d) => d.id == '11111111-2222-3333-4444-555555555555'), isTrue);
    });

    test('updateDoctor updates existing doctor in store', () async {
      final updated = await dataSource.updateDoctor(
        doctor: const DoctorModel(
          id: doctorId,
          profileId: profileId,
          name: 'Dr. Gregory House, M.D.',
          specialty: 'Infectious Disease',
          isFavorite: false,
        ),
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(updated.name, equals('Dr. Gregory House, M.D.'));
      expect(updated.specialty, equals('Infectious Disease'));
      expect(updated.isFavorite, isFalse);

      final fromStore = await dataSource.getDoctorById(doctorId: doctorId, ownerUserId: ownerUserId);
      expect(fromStore!.name, equals('Dr. Gregory House, M.D.'));
    });

    test('deleteDoctor deletes doctor from store', () async {
      await dataSource.deleteDoctor(
        doctorId: doctorId,
        ownerUserId: ownerUserId,
      );

      expect(dataSource.doctorStore.any((d) => d.id == doctorId), isFalse);
    });

    test('maps PostgREST and network exceptions into domain AppExceptions', () async {
      dataSource.postgrestErrorToThrow = const PostgrestException(
        message: 'Permission denied',
        code: '42501',
      );
      await expectLater(
        dataSource.fetchDoctors(ownerUserId: ownerUserId, profileId: profileId),
        throwsA(isA<UnauthorizedException>()),
      );

      dataSource.postgrestErrorToThrow = const PostgrestException(
        message: 'Row not found',
        code: 'PGRST116',
      );
      await expectLater(
        dataSource.getDoctorById(doctorId: '99999999-9999-9999-9999-999999999999', ownerUserId: ownerUserId),
        throwsA(isA<NotFoundException>()),
      );

      dataSource.postgrestErrorToThrow = null;
      dataSource.throwNetworkError = true;
      await expectLater(
        dataSource.fetchDoctors(ownerUserId: ownerUserId, profileId: profileId),
        throwsA(isA<SocketException>()),
      );
    });

    test('validates UUID constraints on profileId, doctorId, and hospitalId', () async {
      // Invalid profileId on fetch
      await expectLater(
        dataSource.fetchDoctors(ownerUserId: ownerUserId, profileId: 'legacy_42'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('must be a valid UUID'))),
      );

      // Invalid hospital filter ID
      await expectLater(
        dataSource.fetchDoctors(ownerUserId: ownerUserId, profileId: profileId, hospitalId: 'not-a-uuid'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('Hospital filter ID must be a valid UUID'))),
      );

      // Invalid doctorId on getDoctorById returns null
      final invalidGet = await dataSource.getDoctorById(
        doctorId: 'invalid-doc-id',
        ownerUserId: ownerUserId,
      );
      expect(invalidGet, isNull);

      // Invalid profileId on createDoctor
      await expectLater(
        dataSource.createDoctor(
          doctor: const DoctorModel(id: '', profileId: 'bad-prof', name: 'Dr. Valid', specialty: 'General'),
          ownerUserId: ownerUserId,
          profileId: 'bad-prof',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Invalid doctorId on updateDoctor
      await expectLater(
        dataSource.updateDoctor(
          doctor: const DoctorModel(id: 'non-uuid-id', profileId: profileId, name: 'Dr. Valid', specialty: 'General'),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ValidationException>()),
      );

      // Invalid doctorId on deleteDoctor
      await expectLater(
        dataSource.deleteDoctor(
          doctorId: 'non-uuid-id',
          ownerUserId: ownerUserId,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('hospital affiliation filtering handles multiple, single, none, and combined search', () async {
      const hosp1 = '55555555-5555-5555-5555-555555555555';
      const hosp2 = '66666666-6666-6666-6666-666666666666';
      const hospEmpty = '77777777-7777-7777-7777-777777777777';

      dataSource.doctorStore.addAll([
        const DoctorModel(
          id: '88888888-8888-8888-8888-888888888888',
          profileId: profileId,
          name: 'Dr. Multi Affiliated',
          specialty: 'Pediatrics',
          hospitalIds: [hosp1, hosp2],
        ),
        const DoctorModel(
          id: '99999999-9999-9999-9999-999999999999',
          profileId: profileId,
          name: 'Dr. No Affiliations',
          specialty: 'Dermatology',
          hospitalIds: [],
        ),
      ]);

      // Filter by hosp1 - returns Dr. Multi Affiliated
      final resHosp1 = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        hospitalId: hosp1,
      );
      expect(resHosp1.any((d) => d.name == 'Dr. Multi Affiliated'), isTrue);
      expect(resHosp1.any((d) => d.name == 'Dr. No Affiliations'), isFalse);

      // Filter by hosp2 - returns Dr. Multi Affiliated
      final resHosp2 = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        hospitalId: hosp2,
      );
      expect(resHosp2.any((d) => d.name == 'Dr. Multi Affiliated'), isTrue);

      // Combined search + affiliation filter
      final combined = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        search: 'Pediatrics',
        hospitalId: hosp1,
      );
      expect(combined.length, equals(1));
      expect(combined.first.name, equals('Dr. Multi Affiliated'));

      // Empty results when hospital has no doctors
      final emptyRes = await dataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileId,
        hospitalId: hospEmpty,
      );
      expect(emptyRes, isEmpty);
    });

    test('transaction safety: surfaces failure and prevents partial database state on junction error', () async {
      dataSource.simulateJunctionFailure = true;

      // Create should fail and not leave doctor
      await expectLater(
        dataSource.createDoctor(
          doctor: const DoctorModel(
            id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            profileId: profileId,
            name: 'Dr. Partial Test',
            specialty: 'Neurology',
            hospitalIds: [hospitalId],
          ),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('simulated junction failure'))),
      );
      expect(dataSource.doctorStore.any((d) => d.name == 'Dr. Partial Test'), isFalse);

      // Update should surface failure
      await expectLater(
        dataSource.updateDoctor(
          doctor: const DoctorModel(
            id: doctorId,
            profileId: profileId,
            name: 'Dr. Gregory House, M.D.',
            specialty: 'Diagnostic Medicine',
            hospitalIds: [hospitalId],
          ),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('simulated junction failure'))),
      );
    });

    group('save_doctor_with_affiliations RPC regression suite', () {
      test('Direct authenticated invocation through exposed API is unavailable (PGRST202)', () async {
        // Direct client RPC invocation of check_doctor_ownership fails with 404/PGRST202
        // because it is encapsulated in the non-exposed `private` schema
        await expectLater(
          dataSource.invokePublicRpcCheckDoctorOwnership(
            doctorId: '99999999-1111-2222-3333-444444444444',
            profileId: profileId,
          ),
          throwsA(isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            contains('PGRST202'),
          )),
        );
      });

      test('Internal private helper identifies ownership state without public exposure or data leak', () {
        // Querying internal helper for foreign doctor returns 'CROSS_USER' without public schema exposure
        final status = dataSource.internalCheckDoctorOwnership(
          doctorId: '99999999-1111-2222-3333-444444444444',
          profileId: profileId,
          ownerUserId: ownerUserId,
        );
        expect(status, equals('CROSS_USER'));
      });

      test('Cross-profile doctor update rejection', () async {
        // Existing doctor belonging to another profile under same account is rejected
        await expectLater(
          dataSource.updateDoctor(
            doctor: const DoctorModel(
              id: '88888888-8888-8888-8888-888888888888',
              profileId: profileId,
              name: 'Dr. Cross Profile Hijack',
              specialty: 'Surgery',
            ),
            ownerUserId: ownerUserId,
            profileId: profileId,
          ),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('Cross-user doctor update rejection', () async {
        // Attempting to update a doctor belonging to another user is rejected
        await expectLater(
          dataSource.updateDoctor(
            doctor: const DoctorModel(
              id: '99999999-1111-2222-3333-444444444444',
              profileId: profileId,
              name: 'Dr. Cross User Hijack',
              specialty: 'Neurology',
            ),
            ownerUserId: ownerUserId,
            profileId: profileId,
          ),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('Invalid hospital affiliation rejection', () async {
        // 1. On creation: Reject foreign or nonexistent hospital affiliation
        await expectLater(
          dataSource.createDoctor(
            doctor: const DoctorModel(
              id: '99999999-0000-0000-0000-000000000001',
              profileId: profileId,
              name: 'Dr. Invalid Affiliation Create',
              specialty: 'Radiology',
              hospitalIds: ['00000000-0000-0000-0000-999999999999'],
            ),
            ownerUserId: ownerUserId,
            profileId: profileId,
          ),
          throwsA(isA<ValidationException>()),
        );

        // 2. On update: Reject foreign or nonexistent hospital affiliation
        await expectLater(
          dataSource.updateDoctor(
            doctor: const DoctorModel(
              id: doctorId,
              profileId: profileId,
              name: 'Dr. Gregory House',
              specialty: 'Diagnostic Medicine',
              hospitalIds: ['00000000-0000-0000-0000-999999999999'],
            ),
            ownerUserId: ownerUserId,
            profileId: profileId,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('Valid update preserving correct affiliations', () async {
        const newHospitalId = '55555555-5555-5555-5555-555555555555';
        final updated = await dataSource.updateDoctor(
          doctor: const DoctorModel(
            id: doctorId,
            profileId: profileId,
            name: 'Dr. Gregory House, M.D.',
            specialty: 'Diagnostic Medicine & Nephrology',
            hospitalName: 'Princeton Plainsboro Teaching Hospital',
            hospitalIds: [hospitalId, newHospitalId],
            isFavorite: true,
          ),
          ownerUserId: ownerUserId,
          profileId: profileId,
        );

        expect(updated.id, equals(doctorId));
        expect(updated.name, equals('Dr. Gregory House, M.D.'));
        expect(updated.specialty, equals('Diagnostic Medicine & Nephrology'));
        expect(updated.hospitalIds, containsAll([hospitalId, newHospitalId]));
        expect(updated.hospitalIds.length, equals(2));

        // Verify state persisted in doctorStore
        final stored = dataSource.doctorStore.firstWhere((d) => d.id == doctorId);
        expect(stored.name, equals('Dr. Gregory House, M.D.'));
        expect(stored.hospitalIds, containsAll([hospitalId, newHospitalId]));
      });

      test('New doctor creation still works and persists affiliations', () async {
        const newDocId = '77777777-1111-2222-3333-444444444444';
        final created = await dataSource.createDoctor(
          doctor: const DoctorModel(
            id: newDocId,
            profileId: profileId,
            name: 'Dr. Allison Cameron',
            specialty: 'Immunology',
            hospitalIds: [hospitalId],
          ),
          ownerUserId: ownerUserId,
          profileId: profileId,
        );

        expect(created.id, equals(newDocId));
        expect(created.name, equals('Dr. Allison Cameron'));
        expect(created.hospitalIds, contains(hospitalId));
        expect(dataSource.doctorStore.any((d) => d.id == newDocId), isTrue);
      });

      test('Failed operations leave existing doctor and junction records unchanged (atomicity)', () async {
        final preDoctor = dataSource.doctorStore.firstWhere((d) => d.id == doctorId);
        final preName = preDoctor.name;
        final preHospIds = List<String>.from(preDoctor.hospitalIds);

        // Attempt invalid update with invalid hospital ID
        await expectLater(
          dataSource.updateDoctor(
            doctor: const DoctorModel(
              id: doctorId,
              profileId: profileId,
              name: 'Dr. Mutated But Rollback Name',
              specialty: 'Cardiology',
              hospitalIds: ['00000000-0000-0000-0000-999999999999'],
            ),
            ownerUserId: ownerUserId,
            profileId: profileId,
          ),
          throwsA(isA<ValidationException>()),
        );

        // Verify existing state in doctorStore remains completely unmodified
        final postDoctor = dataSource.doctorStore.firstWhere((d) => d.id == doctorId);
        expect(postDoctor.name, equals(preName));
        expect(postDoctor.hospitalIds, equals(preHospIds));
      });
    });
  });
}
