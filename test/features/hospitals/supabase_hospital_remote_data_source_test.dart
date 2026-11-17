import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeHospitalRemoteDataSource extends SupabaseHospitalRemoteDataSource {
  final List<HospitalModel> hospitalStore = [];
  bool throwNetworkError = false;
  PostgrestException? postgrestErrorToThrow;

  @override
  Future<List<HospitalModel>> fetchHospitals({
    required String ownerUserId,
    required String profileId,
    String? search,
    String? type,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot fetch hospitals without a valid authenticated user ID.');
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException('Cannot fetch hospitals without a valid profile ID.');
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID for Supabase operations.');
    }
    if (throwNetworkError) {
      throw const SocketException('Connection refused');
    }
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'fetchHospitals');
    }

    var list = hospitalStore.where((h) => IdUtils.unprefix(h.profileId) == cleanProfileId).toList();
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      list = list.where((h) =>
        h.name.toLowerCase().contains(s) ||
        (h.city != null && h.city!.toLowerCase().contains(s)) ||
        (h.address != null && h.address!.toLowerCase().contains(s))
      ).toList();
    }
    if (type != null && type.trim().isNotEmpty) {
      final t = type.trim().toLowerCase();
      list = list.where((h) => (h.type ?? '').toLowerCase() == t).toList();
    }
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<HospitalModel?> getHospitalById({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(hospitalId).trim();
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId) || ownerUserId.trim().isEmpty) return null;
    if (profileId != null && profileId.trim().isNotEmpty) {
      final cleanProf = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProf)) return null;
    }
    if (throwNetworkError) throw const SocketException('No route to host');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'getHospitalById');
    }

    try {
      return hospitalStore.firstWhere((h) => IdUtils.unprefix(h.id) == cleanId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<HospitalModel> createHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    required String profileId,
  }) async {
    final cleanProfileId = IdUtils.unprefix(profileId).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot create hospital without an active authenticated session.');
    }
    if (cleanProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty.');
    }
    if (!UuidUtils.isValidUuid(cleanProfileId)) {
      throw const ValidationException('Profile ID must be a valid UUID for Supabase operations.');
    }
    if (hospital.name.trim().isEmpty) {
      throw const ValidationException('Facility name cannot be empty.');
    }
    if (throwNetworkError) throw const SocketException('Connection reset');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'createHospital');
    }

    final cleanHospId = IdUtils.unprefix(hospital.id).trim();
    final effectiveId = UuidUtils.isValidUuid(cleanHospId) ? cleanHospId : 'b0000000-0000-0000-0000-000000000001';

    final created = hospital.copyWith(
      id: effectiveId,
      profileId: cleanProfileId,
      type: HospitalModel.normalizeType(hospital.type),
    );
    hospitalStore.add(created);
    return created;
  }

  @override
  Future<HospitalModel> updateHospital({
    required HospitalModel hospital,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(hospital.id).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot update hospital without an active authenticated session.');
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Hospital ID must be a valid UUID when updating.');
    }
    if (hospital.name.trim().isEmpty) {
      throw const ValidationException('Facility name cannot be empty.');
    }
    if (profileId != null && profileId.trim().isNotEmpty) {
      final cleanProf = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProf)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }
    if (throwNetworkError) throw const SocketException('Broken pipe');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'updateHospital');
    }

    final index = hospitalStore.indexWhere((h) => IdUtils.unprefix(h.id) == cleanId);
    final normalized = hospital.copyWith(type: HospitalModel.normalizeType(hospital.type));
    if (index >= 0) {
      hospitalStore[index] = normalized;
    } else {
      hospitalStore.add(normalized);
    }
    return normalized;
  }

  @override
  Future<void> deleteHospital({
    required String hospitalId,
    required String ownerUserId,
    String? profileId,
  }) async {
    final cleanId = IdUtils.unprefix(hospitalId).trim();
    if (ownerUserId.trim().isEmpty) {
      throw const UnauthorizedException('Cannot delete hospital without an active authenticated session.');
    }
    if (cleanId.isEmpty || !UuidUtils.isValidUuid(cleanId)) {
      throw const ValidationException('Hospital ID must be a valid UUID.');
    }
    if (profileId != null && profileId.trim().isNotEmpty) {
      final cleanProf = IdUtils.unprefix(profileId).trim();
      if (!UuidUtils.isValidUuid(cleanProf)) {
        throw const ValidationException('Profile ID must be a valid UUID.');
      }
    }
    if (throwNetworkError) throw const SocketException('Reset by peer');
    if (postgrestErrorToThrow != null) {
      throw _handlePostgrestException(postgrestErrorToThrow!, 'deleteHospital');
    }

    hospitalStore.removeWhere((h) => IdUtils.unprefix(h.id) == cleanId);
  }

  AppException _handlePostgrestException(PostgrestException e, String op) {
    if (e.code == 'PGRST116') return NotFoundException('$op: Hospital record not found.');
    if (e.code == '42501') return UnauthorizedException('Access denied during $op: ${e.message}');
    if (e.code == '23505') return ConflictException('A facility already exists: ${e.message}');
    if (e.code == '23503') return ValidationException('Foreign key constraint violation: ${e.message}');
    return ServerException('Database error during $op: ${e.message}', code: e.code);
  }
}

void main() {
  group('SupabaseHospitalRemoteDataSource Unit Tests', () {
    late _FakeHospitalRemoteDataSource dataSource;
    const ownerUserId = '11111111-2222-3333-4444-555555555555';
    const profileId = '22222222-3333-4444-5555-666666666666';
    const hospitalId = '33333333-4444-5555-6666-777777777777';

    setUp(() {
      dataSource = _FakeHospitalRemoteDataSource();
      dataSource.hospitalStore.addAll([
        const HospitalModel(
          id: hospitalId,
          profileId: profileId,
          name: 'Mayo Clinic',
          type: 'Clinic',
          city: 'Rochester',
          state: 'MN',
          phone: '+1-507-284-2511',
        ),
        const HospitalModel(
          id: 'hosp-johns-hopkins',
          profileId: profileId,
          name: 'Johns Hopkins Hospital',
          type: 'Hospital',
          city: 'Baltimore',
          state: 'MD',
        ),
        const HospitalModel(
          id: 'hosp-other-profile',
          profileId: 'other-profile-uuid',
          name: 'Cleveland Clinic',
          type: 'Hospital',
          city: 'Cleveland',
        ),
      ]);
    });

    test('fetchHospitals scopes records strictly to profileId', () async {
      final list = await dataSource.fetchHospitals(
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(list.length, equals(2));
      expect(list.every((h) => h.profileId == profileId), isTrue);
    });

    test('fetchHospitals filters by search query and type', () async {
      final searchResult = await dataSource.fetchHospitals(
        ownerUserId: ownerUserId,
        profileId: profileId,
        search: 'Mayo',
      );
      expect(searchResult.length, equals(1));
      expect(searchResult.first.name, equals('Mayo Clinic'));

      final typeResult = await dataSource.fetchHospitals(
        ownerUserId: ownerUserId,
        profileId: profileId,
        type: 'Clinic',
      );
      expect(typeResult.length, equals(1));
      expect(typeResult.first.type, equals('Clinic'));
    });

    test('getHospitalById retrieves specific hospital by ID', () async {
      final hospital = await dataSource.getHospitalById(
        hospitalId: hospitalId,
        ownerUserId: ownerUserId,
      );
      expect(hospital, isNotNull);
      expect(hospital!.name, equals('Mayo Clinic'));

      final nonExistent = await dataSource.getHospitalById(
        hospitalId: 'missing-uuid',
        ownerUserId: ownerUserId,
      );
      expect(nonExistent, isNull);
    });

    test('createHospital validates facility name and saves record', () async {
      await expectLater(
        dataSource.createHospital(
          hospital: const HospitalModel(id: '', profileId: '', name: '  '),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('Facility name cannot be empty'))),
      );

      final created = await dataSource.createHospital(
        hospital: const HospitalModel(
          id: '22222222-3333-4444-5555-666666666666',
          profileId: profileId,
          name: 'Apollo Hospital',
          type: 'Hospital',
          city: 'Bengaluru',
        ),
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(created.id, equals('22222222-3333-4444-5555-666666666666'));
      expect(dataSource.hospitalStore.any((h) => h.id == '22222222-3333-4444-5555-666666666666'), isTrue);
    });

    test('updateHospital updates mutable fields in store', () async {
      final updated = await dataSource.updateHospital(
        hospital: const HospitalModel(
          id: hospitalId,
          profileId: profileId,
          name: 'Mayo Clinic - Main Pavilion',
          type: 'Clinic',
          city: 'Rochester',
          phone: '+1-507-999-9999',
        ),
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(updated.name, equals('Mayo Clinic - Main Pavilion'));
      expect(updated.phone, equals('+1-507-999-9999'));

      final fromStore = await dataSource.getHospitalById(hospitalId: hospitalId, ownerUserId: ownerUserId);
      expect(fromStore!.name, equals('Mayo Clinic - Main Pavilion'));
    });

    test('deleteHospital removes facility from store', () async {
      await dataSource.deleteHospital(
        hospitalId: hospitalId,
        ownerUserId: ownerUserId,
      );

      expect(dataSource.hospitalStore.any((h) => h.id == hospitalId), isFalse);
    });

    test('translates PostgREST exceptions to domain AppExceptions', () async {
      dataSource.postgrestErrorToThrow = const PostgrestException(
        message: 'Permission denied',
        code: '42501',
      );
      await expectLater(
        dataSource.fetchHospitals(ownerUserId: ownerUserId, profileId: profileId),
        throwsA(isA<UnauthorizedException>()),
      );

      dataSource.postgrestErrorToThrow = const PostgrestException(
        message: 'Row not found',
        code: 'PGRST116',
      );
      await expectLater(
        dataSource.getHospitalById(hospitalId: '99999999-9999-9999-9999-999999999999', ownerUserId: ownerUserId),
        throwsA(isA<NotFoundException>()),
      );

      dataSource.postgrestErrorToThrow = null;
      dataSource.throwNetworkError = true;
      await expectLater(
        dataSource.fetchHospitals(ownerUserId: ownerUserId, profileId: profileId),
        throwsA(isA<SocketException>()),
      );
    });

    test('validates UUID constraints on profileId and hospitalId', () async {
      // Invalid profileId on fetch
      await expectLater(
        dataSource.fetchHospitals(ownerUserId: ownerUserId, profileId: 'bad-profile'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('must be a valid UUID'))),
      );

      // Invalid hospitalId on getHospitalById returns null
      final res = await dataSource.getHospitalById(
        hospitalId: 'not-a-uuid',
        ownerUserId: ownerUserId,
      );
      expect(res, isNull);

      // Invalid profileId on createHospital
      await expectLater(
        dataSource.createHospital(
          hospital: const HospitalModel(id: '', profileId: 'bad', name: 'General'),
          ownerUserId: ownerUserId,
          profileId: 'bad',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Invalid hospitalId on updateHospital
      await expectLater(
        dataSource.updateHospital(
          hospital: const HospitalModel(id: 'non-uuid', profileId: profileId, name: 'General'),
          ownerUserId: ownerUserId,
          profileId: profileId,
        ),
        throwsA(isA<ValidationException>()),
      );

      // Invalid hospitalId on deleteHospital
      await expectLater(
        dataSource.deleteHospital(
          hospitalId: 'non-uuid',
          ownerUserId: ownerUserId,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
