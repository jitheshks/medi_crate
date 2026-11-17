import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';

void main() {
  group('DoctorModel Supabase Serialization & Deserialization Tests', () {
    const ownerUserId = '11111111-2222-3333-4444-555555555555';
    const profileId = '22222222-3333-4444-5555-666666666666';
    const doctorId = '33333333-4444-5555-6666-777777777777';
    const clientUuid = '44444444-5555-6666-7777-888888888888';
    const hospitalId = '55555555-6666-7777-8888-999999999999';

    test('toSupabaseJson maps fields matching public.doctors PostgreSQL schema', () {
      final doctor = DoctorModel(
        id: doctorId,
        profileId: 'prof_$profileId',
        name: '  Dr. Gregory House  ',
        specialty: '  Diagnostic Medicine  ',
        hospitalIds: [hospitalId],
        hospitalName: ' Princeton-Plainsboro ',
        phone: ' +1-555-0199 ',
        email: ' house@ppth.org ',
        notes: ' Brilliant diagnostician ',
        isFavorite: true,
        clientUuid: clientUuid,
      );

      final json = doctor.toSupabaseJson(
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(json['user_id'], equals(ownerUserId));
      expect(json['profile_id'], equals(profileId));
      expect(json['id'], equals(doctorId));
      expect(json['client_uuid'], equals(clientUuid));
      expect(json['name'], equals('Dr. Gregory House'));
      expect(json['specialty'], equals('Diagnostic Medicine'));
      expect(json['hospital_name'], equals('Princeton-Plainsboro'));
      expect(json['phone'], equals('+1-555-0199'));
      expect(json['email'], equals('house@ppth.org'));
      expect(json['notes'], equals('Brilliant diagnostician'));
      expect(json['is_favorite'], isTrue);
      // hospital_ids is stored in junction table doctor_hospitals, not in doctors table
      expect(json.containsKey('hospital_ids'), isFalse);
    });

    test('toSupabaseJson strips doctor_ and prof_ prefixes when serializing IDs', () {
      final doctor = DoctorModel(
        id: 'doctor_$doctorId',
        profileId: 'prof_$profileId',
        name: 'Dr. James Wilson',
        specialty: 'Oncology',
      );

      final json = doctor.toSupabaseJson(
        ownerUserId: ownerUserId,
        profileId: 'prof_$profileId',
      );

      expect(json['id'], equals(doctorId));
      expect(json['profile_id'], equals(profileId));
    });

    test('toSupabaseJson excludes non-UUID temporary IDs when includeId is false or non-UUID', () {
      final doctor = DoctorModel(
        id: 'doctor_1731300000000',
        profileId: profileId,
        name: 'Dr. Lisa Cuddy',
        specialty: 'Endocrinology',
        clientUuid: 'non-uuid-temp',
      );

      final json = doctor.toSupabaseJson(
        ownerUserId: ownerUserId,
        profileId: profileId,
        includeId: false,
      );

      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('client_uuid'), isFalse);
    });

    test('fromSupabaseJson parses complete PostgREST row including doctor_hospitals relation', () {
      final supabaseRow = {
        'id': doctorId,
        'user_id': ownerUserId,
        'profile_id': profileId,
        'client_uuid': clientUuid,
        'name': 'Dr. Robert Chase',
        'specialty': 'Surgeon / Intensive Care',
        'hospital_name': 'Princeton Plainsboro',
        'phone': '+1-555-0123',
        'email': 'chase@ppth.org',
        'notes': 'Fellow',
        'is_favorite': true,
        'created_at': '2026-11-10T10:00:00.000Z',
        'updated_at': '2026-11-10T12:00:00.000Z',
        'doctor_hospitals': [
          {'hospital_id': hospitalId},
          {'hospital_id': '66666666-7777-8888-9999-000000000000'},
        ],
      };

      final doctor = DoctorModel.fromSupabaseJson(supabaseRow);

      expect(doctor.id, equals(doctorId));
      expect(doctor.profileId, equals(profileId));
      expect(doctor.clientUuid, equals(clientUuid));
      expect(doctor.name, equals('Dr. Robert Chase'));
      expect(doctor.specialty, equals('Surgeon / Intensive Care'));
      expect(doctor.hospitalName, equals('Princeton Plainsboro'));
      expect(doctor.phone, equals('+1-555-0123'));
      expect(doctor.email, equals('chase@ppth.org'));
      expect(doctor.notes, equals('Fellow'));
      expect(doctor.isFavorite, isTrue);
      expect(doctor.hospitalIds, containsAll([
        hospitalId,
        '66666666-7777-8888-9999-000000000000',
      ]));
      expect(doctor.createdAt, equals(DateTime.parse('2026-11-10T10:00:00.000Z')));
    });

    test('fromSupabaseJson handles is_favorite truthy variations safely', () {
      expect(DoctorModel.fromSupabaseJson({'name': 'D', 'is_favorite': true}).isFavorite, isTrue);
      expect(DoctorModel.fromSupabaseJson({'name': 'D', 'is_favorite': 1}).isFavorite, isTrue);
      expect(DoctorModel.fromSupabaseJson({'name': 'D', 'is_favorite': 'true'}).isFavorite, isTrue);
      expect(DoctorModel.fromSupabaseJson({'name': 'D', 'is_favorite': false}).isFavorite, isFalse);
      expect(DoctorModel.fromSupabaseJson({'name': 'D', 'is_favorite': 0}).isFavorite, isFalse);
      expect(DoctorModel.fromSupabaseJson({'name': 'D', 'is_favorite': null}).isFavorite, isFalse);
    });

    test('fromJson handles both legacy array hospital_ids and Supabase doctor_hospitals objects', () {
      final legacyJson = {
        'id': '10',
        'profile_id': '1',
        'name': 'Dr. Legacy',
        'specialty': 'Pediatrics',
        'hospital_ids': ['101', '102'],
      };
      final legacyDoc = DoctorModel.fromJson(legacyJson);
      expect(legacyDoc.hospitalIds, equals(['101', '102']));

      final supabaseJson = {
        'id': doctorId,
        'profile_id': profileId,
        'name': 'Dr. Supa',
        'specialty': 'Pediatrics',
        'doctor_hospitals': [
          {'hospital_id': hospitalId},
        ],
      };
      final supaDoc = DoctorModel.fromJson(supabaseJson);
      expect(supaDoc.hospitalIds, equals([hospitalId]));
    });
  });
}
