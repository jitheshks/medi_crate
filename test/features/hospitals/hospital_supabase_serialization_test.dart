import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';

void main() {
  group('HospitalModel Supabase Serialization & Deserialization Tests', () {
    const ownerUserId = '11111111-2222-3333-4444-555555555555';
    const profileId = '22222222-3333-4444-5555-666666666666';
    const hospitalId = '33333333-4444-5555-6666-777777777777';
    const clientUuid = '44444444-5555-6666-7777-888888888888';

    test('toSupabaseJson maps fields matching public.hospitals PostgreSQL schema', () {
      final hospital = HospitalModel(
        id: hospitalId,
        profileId: 'prof_$profileId',
        name: '  Mayo Clinic  ',
        type: '  Clinic  ',
        address: ' 200 First St SW ',
        city: ' Rochester ',
        state: ' MN ',
        country: ' USA ',
        phone: ' +1-507-284-2511 ',
        email: ' info@mayo.edu ',
        website: ' https://mayoclinic.org ',
        notes: ' World class clinic ',
        clientUuid: clientUuid,
      );

      final json = hospital.toSupabaseJson(
        ownerUserId: ownerUserId,
        profileId: profileId,
      );

      expect(json['user_id'], equals(ownerUserId));
      expect(json['profile_id'], equals(profileId));
      expect(json['id'], equals(hospitalId));
      expect(json['client_uuid'], equals(clientUuid));
      expect(json['name'], equals('Mayo Clinic'));
      expect(json['type'], equals('Clinic'));
      expect(json['address'], equals('200 First St SW'));
      expect(json['city'], equals('Rochester'));
      expect(json['state'], equals('MN'));
      expect(json['country'], equals('USA'));
      expect(json['phone'], equals('+1-507-284-2511'));
      expect(json['email'], equals('info@mayo.edu'));
      expect(json['website'], equals('https://mayoclinic.org'));
      expect(json['notes'], equals('World class clinic'));
    });

    test('toSupabaseJson normalizes prefixes and excludes non-UUID temporary IDs', () {
      final hospital = HospitalModel(
        id: 'hospital_temp_12345',
        profileId: 'prof_$profileId',
        name: 'City Care Hospital',
        clientUuid: 'non-uuid-temp',
      );

      final json = hospital.toSupabaseJson(
        ownerUserId: ownerUserId,
        profileId: 'prof_$profileId',
      );

      expect(json['profile_id'], equals(profileId));
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('client_uuid'), isFalse);
    });

    test('fromSupabaseJson parses complete PostgREST row', () {
      final supabaseRow = {
        'id': hospitalId,
        'user_id': ownerUserId,
        'profile_id': profileId,
        'client_uuid': clientUuid,
        'name': 'Johns Hopkins Hospital',
        'type': 'Hospital',
        'address': '1800 Orleans St',
        'city': 'Baltimore',
        'state': 'MD',
        'country': 'USA',
        'phone': '+1-410-955-5000',
        'email': 'jh@jhmi.edu',
        'website': 'https://hopkinsmedicine.org',
        'notes': 'Teaching hospital',
        'created_at': '2026-11-10T10:00:00.000Z',
        'updated_at': '2026-11-10T12:00:00.000Z',
      };

      final hospital = HospitalModel.fromSupabaseJson(supabaseRow);

      expect(hospital.id, equals(hospitalId));
      expect(hospital.profileId, equals(profileId));
      expect(hospital.clientUuid, equals(clientUuid));
      expect(hospital.name, equals('Johns Hopkins Hospital'));
      expect(hospital.type, equals('Hospital'));
      expect(hospital.address, equals('1800 Orleans St'));
      expect(hospital.city, equals('Baltimore'));
      expect(hospital.state, equals('MD'));
      expect(hospital.country, equals('USA'));
      expect(hospital.phone, equals('+1-410-955-5000'));
      expect(hospital.email, equals('jh@jhmi.edu'));
      expect(hospital.website, equals('https://hopkinsmedicine.org'));
      expect(hospital.notes, equals('Teaching hospital'));
      expect(hospital.createdAt, equals(DateTime.parse('2026-11-10T10:00:00.000Z')));
    });

    test('fromSupabaseJson provides fallback default type Hospital when missing', () {
      final row = {
        'id': hospitalId,
        'profile_id': profileId,
        'name': 'Unknown Center',
      };
      final hospital = HospitalModel.fromSupabaseJson(row);
      expect(hospital.type, equals('Hospital'));
    });

    test('normalizeType accurately handles all valid MediVault and Supabase facility types', () {
      expect(HospitalModel.normalizeType(null), equals('Hospital'));
      expect(HospitalModel.normalizeType(''), equals('Hospital'));
      expect(HospitalModel.normalizeType('hospital'), equals('Hospital'));
      expect(HospitalModel.normalizeType('Clinic'), equals('Clinic'));
      expect(HospitalModel.normalizeType('lab'), equals('Lab'));
      expect(HospitalModel.normalizeType('laboratory'), equals('Lab'));
      expect(HospitalModel.normalizeType('diagnostic'), equals('Diagnostic Center'));
      expect(HospitalModel.normalizeType('Diagnostic Center'), equals('Diagnostic Center'));
      expect(HospitalModel.normalizeType('pharmacy'), equals('Pharmacy'));
      expect(HospitalModel.normalizeType('Specialty Center'), equals('Specialty Center'));
      expect(HospitalModel.normalizeType('other'), equals('Other'));
      expect(HospitalModel.normalizeType('Unknown Facility Kind'), equals('Other'));
    });
  });
}
