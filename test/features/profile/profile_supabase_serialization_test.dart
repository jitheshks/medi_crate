import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';

void main() {
  group('ProfileModel Supabase Serialization & Deserialization', () {
    test('toSupabaseJson converts model to exact Supabase columns', () {
      final profile = ProfileModel(
        profileId: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        ownerUserId: 'user-uuid-1234',
        clientUuid: 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e',
        fullName: 'Eleanor Vance',
        relationship: 'Mother',
        gender: 'female',
        dateOfBirth: '1965-04-12',
        bloodGroup: 'o+',
        height: 165.5,
        weight: 62.0,
        photo: 'user-uuid-1234/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d/avatar.jpg',
        isPrimary: false,
        notes: 'Mild hypertension',
        allergies: ['Penicillin', 'Sulfa'],
        allergiesConfirmedNone: false,
        chronicConditions: ['Hypertension'],
        chronicConditionsConfirmedNone: false,
      );

      final json = profile.toSupabaseJson();

      expect(json['id'], 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      expect(json['user_id'], 'user-uuid-1234');
      expect(json['client_uuid'], 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e');
      expect(json['full_name'], 'Eleanor Vance');
      expect(json['relationship'], 'Mother');
      expect(json['relationship_other'], isNull);
      expect(json['gender'], 'Female'); // Normalized to match check constraint
      expect(json['date_of_birth'], '1965-04-12');
      expect(json['blood_group'], 'O+'); // Normalized to uppercase
      expect(json['height_cm'], 165.5);
      expect(json['weight_kg'], 62.0);
      expect(json['photo_url'], 'user-uuid-1234/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d/avatar.jpg');
      expect(json['is_primary'], false);
      expect(json['is_archived'], false);
      expect(json.containsKey('archived_at'), isFalse); // Server-managed timestamp
      expect(json['notes'], 'Mild hypertension');
      expect(json['allergies'], ['Penicillin', 'Sulfa']);
      expect(json['allergies_confirmed_none'], false);
      expect(json['chronic_conditions'], ['Hypertension']);
      expect(json['chronic_conditions_confirmed_none'], false);
    });

    test('toSupabaseJson omits id when includeId=false or when profileId is non-UUID provisional key', () {
      final provisional = ProfileModel(
        profileId: 'prof_1731200000',
        ownerUserId: 'user-uuid-1234',
        fullName: 'Thomas Vance',
        relationship: 'Father',
      );

      final jsonWithInclude = provisional.toSupabaseJson(includeId: true);
      expect(jsonWithInclude.containsKey('id'), isFalse); // Non-UUID provisional omitted

      final validUuid = ProfileModel(
        profileId: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        ownerUserId: 'user-uuid-1234',
        fullName: 'Thomas Vance',
        relationship: 'Father',
      );
      final jsonOmitted = validUuid.toSupabaseJson(includeId: false);
      expect(jsonOmitted.containsKey('id'), isFalse);
    });

    test('toSupabaseJson handles custom relationship "Other"', () {
      final profile = ProfileModel(
        profileId: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        ownerUserId: 'user-uuid-1234',
        fullName: 'Arthur Dent',
        relationship: 'Other',
        relationshipOther: 'Cousin',
      );

      final json = profile.toSupabaseJson();
      expect(json['relationship'], 'Other');
      expect(json['relationship_other'], 'Cousin');
    });

    test('fromSupabaseJson correctly deserializes Postgres row', () {
      final postgresRow = {
        'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        'user_id': 'user-uuid-1234',
        'client_uuid': 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e',
        'full_name': 'Eleanor Vance',
        'relationship': 'Mother',
        'relationship_other': null,
        'gender': 'Female',
        'date_of_birth': '1965-04-12',
        'blood_group': 'O+',
        'height_cm': 165.5,
        'weight_kg': 62.0,
        'photo_url': 'avatars/user-uuid-1234/avatar.jpg',
        'is_primary': false,
        'notes': 'Checkup scheduled',
        'allergies': ['Penicillin'],
        'allergies_confirmed_none': false,
        'chronic_conditions': ['Hypertension'],
        'chronic_conditions_confirmed_none': false,
        'created_at': '2026-11-09T20:00:00.000Z',
        'updated_at': '2026-11-09T21:00:00.000Z',
      };

      final profile = ProfileModel.fromSupabaseJson(postgresRow);

      expect(profile.profileId, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      expect(profile.ownerUserId, 'user-uuid-1234');
      expect(profile.clientUuid, 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e');
      expect(profile.fullName, 'Eleanor Vance');
      expect(profile.relationship, 'Mother');
      expect(profile.relationshipOther, isNull);
      expect(profile.gender, 'Female');
      expect(profile.dateOfBirth, '1965-04-12');
      expect(profile.bloodGroup, 'O+');
      expect(profile.height, 165.5);
      expect(profile.weight, 62.0);
      expect(profile.photo, 'avatars/user-uuid-1234/avatar.jpg');
      expect(profile.isPrimary, false);
      expect(profile.isArchived, false);
      expect(profile.archivedAt, isNull);
      expect(profile.notes, 'Checkup scheduled');
      expect(profile.allergies, ['Penicillin']);
      expect(profile.allergiesConfirmedNone, false);
      expect(profile.chronicConditions, ['Hypertension']);
      expect(profile.chronicConditionsConfirmedNone, false);
    });

    test('fromMap and toMap preserve Hive backwards compatibility', () {
      final original = ProfileModel(
        profileId: 'prof_primary_user_1',
        ownerUserId: 'user_1',
        fullName: 'Jane Doe',
        relationship: 'Self',
        isPrimary: true,
        height: 170.0,
        weight: 65.0,
        allergies: const ['Dust'],
        allergiesConfirmedNone: false,
        chronicConditions: const [],
        chronicConditionsConfirmedNone: true,
      );

      final map = original.toMap();
      final restored = ProfileModel.fromMap(map);

      expect(restored.profileId, original.profileId);
      expect(restored.ownerUserId, original.ownerUserId);
      expect(restored.fullName, original.fullName);
      expect(restored.relationship, original.relationship);
      expect(restored.isPrimary, true);
      expect(restored.height, 170.0);
      expect(restored.weight, 65.0);
      expect(restored.allergies, ['Dust']);
      expect(restored.chronicConditionsConfirmedNone, true);
    });

    test('ProfileGenders and ProfileBloodGroups normalize string variations', () {
      expect(ProfileGenders.normalize('male'), 'Male');
      expect(ProfileGenders.normalize('female'), 'Female');
      expect(ProfileGenders.normalize('other'), 'Other');
      expect(ProfileGenders.normalize('prefer not to say'), 'Prefer not to say');

      expect(ProfileBloodGroups.normalize('o+'), 'O+');
      expect(ProfileBloodGroups.normalize('ab-'), 'AB-');
      expect(ProfileBloodGroups.normalize('b+'), 'B+');
    });

    test('Archival metadata serialization, deserialization, and copyWith', () {
      final archivedRow = {
        'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        'user_id': 'user-uuid-1234',
        'full_name': 'Eleanor Vance',
        'relationship': 'Mother',
        'is_primary': false,
        'is_archived': true,
        'archived_at': '2026-11-10T08:00:00.000Z',
      };

      final profile = ProfileModel.fromSupabaseJson(archivedRow);
      expect(profile.isArchived, isTrue);
      expect(profile.archivedAt, DateTime.parse('2026-11-10T08:00:00.000Z'));

      final hiveMap = profile.toMap();
      expect(hiveMap['is_archived'], isTrue);
      expect(hiveMap['archived_at'], '2026-11-10T08:00:00.000Z');

      final fromHive = ProfileModel.fromMap(hiveMap);
      expect(fromHive.isArchived, isTrue);
      expect(fromHive.archivedAt, profile.archivedAt);

      final restored = fromHive.copyWith(isArchived: false, clearArchivedAt: true);
      expect(restored.isArchived, isFalse);
      expect(restored.archivedAt, isNull);
    });

    test('toOrdinaryUpdateSupabaseJson strictly whitelists demographic fields and excludes server-managed/lifecycle keys', () {
      final profile = ProfileModel(
        profileId: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        ownerUserId: 'user-uuid-1234',
        clientUuid: 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e',
        fullName: 'Eleanor Vance',
        relationship: 'Mother',
        gender: 'Female',
        dateOfBirth: '1965-04-12',
        bloodGroup: 'O+',
        height: 165.5,
        weight: 62.0,
        photo: 'avatars/user-uuid-1234/avatar.jpg',
        isPrimary: false,
        isArchived: false,
        notes: 'Mild hypertension',
        allergies: const ['Penicillin'],
        allergiesConfirmedNone: false,
        chronicConditions: const ['Hypertension'],
        chronicConditionsConfirmedNone: false,
      );

      final updatePayload = profile.toOrdinaryUpdateSupabaseJson();

      // STRICT EXCLUSIONS: Server-managed, immutable, or lifecycle columns
      expect(updatePayload.containsKey('id'), isFalse);
      expect(updatePayload.containsKey('user_id'), isFalse);
      expect(updatePayload.containsKey('is_primary'), isFalse);
      expect(updatePayload.containsKey('is_archived'), isFalse);
      expect(updatePayload.containsKey('archived_at'), isFalse);
      expect(updatePayload.containsKey('created_at'), isFalse);
      expect(updatePayload.containsKey('updated_at'), isFalse);
      expect(updatePayload.containsKey('photo_url'), isFalse);
      expect(updatePayload.containsKey('client_uuid'), isFalse);

      // STRICT INCLUSIONS: Explicitly whitelisted demographic and medical fields
      expect(updatePayload['full_name'], 'Eleanor Vance');
      expect(updatePayload['relationship'], 'Mother');
      expect(updatePayload['relationship_other'], isNull);
      expect(updatePayload['gender'], 'Female');
      expect(updatePayload['date_of_birth'], '1965-04-12');
      expect(updatePayload['blood_group'], 'O+');
      expect(updatePayload['height_cm'], 165.5);
      expect(updatePayload['weight_kg'], 62.0);
      expect(updatePayload['notes'], 'Mild hypertension');
      expect(updatePayload['allergies'], ['Penicillin']);
      expect(updatePayload['allergies_confirmed_none'], isFalse);
      expect(updatePayload['chronic_conditions'], ['Hypertension']);
      expect(updatePayload['chronic_conditions_confirmed_none'], isFalse);
    });

    test('toOrdinaryUpdateSupabaseJson correctly clears nullable demographic fields to null', () {
      final profile = ProfileModel(
        profileId: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        ownerUserId: 'user-uuid-1234',
        fullName: 'Jane Doe',
        relationship: 'Self',
        gender: null,
        dateOfBirth: null,
        bloodGroup: null,
        height: null,
        weight: null,
        notes: null,
      );

      final updatePayload = profile.toOrdinaryUpdateSupabaseJson();

      expect(updatePayload['gender'], isNull);
      expect(updatePayload['date_of_birth'], isNull);
      expect(updatePayload['blood_group'], isNull);
      expect(updatePayload['height_cm'], isNull);
      expect(updatePayload['weight_kg'], isNull);
      expect(updatePayload['notes'], isNull);
      expect(updatePayload['relationship_other'], isNull);
    });
  });
}
