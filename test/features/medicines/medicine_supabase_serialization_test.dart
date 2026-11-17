import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/medicines/data/models/medicine_model.dart';

void main() {
  group('MedicineModel Supabase Serialization Tests', () {
    const validMedicineUuid = '11111111-2222-3333-4444-555555555555';
    const validProfileUuid = '22222222-3333-4444-5555-666666666666';
    const validConsultationUuid = '33333333-4444-5555-6666-777777777777';
    const validClientUuid = '44444444-5555-6666-7777-888888888888';

    test('toSupabaseJson maps canonical prescription schema with UUID relationships and normalized form', () {
      final medicine = MedicineModel(
        id: 'medicine_$validMedicineUuid',
        profileId: 'prof_$validProfileUuid',
        medicineName: 'Amoxicillin',
        dosage: '500mg',
        form: 'capsule', // Lowercase test
        frequency: 'TDS (3 times a day)',
        startDate: DateTime.utc(2026, 11, 10),
        endDate: DateTime.utc(2026, 11, 17),
        reminder: true,
        reminderTimes: const ['08:00', '14:00', '20:00'],
        linkedConsultationId: 'con_$validConsultationUuid',
        linkedConsultationTitle: 'General Physician Follow-up',
        notes: 'Take after meals with water',
        clientUuid: validClientUuid,
        createdAt: DateTime.utc(2026, 11, 10, 8, 0),
        updatedAt: DateTime.utc(2026, 11, 10, 8, 0),
      );

      final json = medicine.toSupabaseJson(includeId: true);

      expect(json['id'], equals(validMedicineUuid));
      expect(json['profile_id'], equals(validProfileUuid));
      expect(json['medicine_name'], equals('Amoxicillin'));
      expect(json['dosage'], equals('500mg'));
      expect(json['form'], equals('Capsule')); // Normalized to title case
      expect(json['frequency'], equals('TDS (3 times a day)'));
      expect(json['start_date'], equals('2026-11-10'));
      expect(json['end_date'], equals('2026-11-17'));
      expect(json['reminder'], isTrue);
      expect(json['reminder_times'], equals(['08:00', '14:00', '20:00']));
      expect(json['is_active'], isTrue);
      expect(json['consultation_id'], equals(validConsultationUuid));
      expect(json['consultation_title'], equals('General Physician Follow-up'));
      expect(json['notes'], equals('Take after meals with water'));
      expect(json['client_uuid'], equals(validClientUuid));
    });

    test('toSupabaseJson sanitizes invalid non-UUID consultation foreign key to null', () {
      final medicine = MedicineModel(
        id: 'temp_med_123',
        profileId: 'prof_$validProfileUuid',
        medicineName: 'Paracetamol',
        dosage: '650mg',
        form: 'CustomSuspension', // Unknown form -> 'Other'
        frequency: 'SOS',
        startDate: DateTime.utc(2026, 11, 10),
        endDate: DateTime.utc(2026, 11, 12),
        linkedConsultationId: 'legacy_consultation_456', // non-UUID
        linkedConsultationTitle: 'Fever Clinic',
      );

      final json = medicine.toSupabaseJson(includeId: false);

      expect(json.containsKey('id'), isFalse);
      expect(json['profile_id'], equals(validProfileUuid));
      expect(json['form'], equals('Other'));
      expect(json['consultation_id'], isNull); // Sanitized to avoid FK violation
      expect(json['consultation_title'], equals('Fever Clinic')); // Preserved
    });

    test('toSupabaseJson omits end_date if before start_date to respect check constraint', () {
      final medicine = MedicineModel(
        id: 'med_101',
        profileId: validProfileUuid,
        medicineName: 'Ibuprofen',
        dosage: '400mg',
        startDate: DateTime.utc(2026, 11, 15),
        endDate: DateTime.utc(2026, 11, 10), // Invalid: before start
      );

      final json = medicine.toSupabaseJson();

      expect(json['start_date'], equals('2026-11-15'));
      expect(json['end_date'], isNull);
    });

    test('fromSupabaseJson correctly reconstitutes MedicineModel from database row', () {
      final dbRow = {
        'id': validMedicineUuid,
        'profile_id': validProfileUuid,
        'medicine_name': 'Metformin',
        'dosage': '500mg',
        'form': 'Tablet',
        'frequency': 'BD (Twice a day)',
        'start_date': '2026-11-01',
        'end_date': '2026-12-01',
        'reminder': true,
        'reminder_times': ['09:00', '21:00'],
        'is_active': true,
        'consultation_id': validConsultationUuid,
        'consultation_title': 'Endocrinology Review',
        'notes': 'Take with breakfast and dinner',
        'client_uuid': validClientUuid,
        'created_at': '2026-11-01T08:00:00.000Z',
        'updated_at': '2026-11-01T08:00:00.000Z',
      };

      final model = MedicineModel.fromSupabaseJson(dbRow);

      expect(model.id, equals('medicine_$validMedicineUuid'));
      expect(model.profileId, equals(validProfileUuid));
      expect(model.medicineName, equals('Metformin'));
      expect(model.dosage, equals('500mg'));
      expect(model.form, equals('Tablet'));
      expect(model.frequency, equals('BD (Twice a day)'));
      expect(model.startDate, equals(DateTime.parse('2026-11-01')));
      expect(model.endDate, equals(DateTime.parse('2026-12-01')));
      expect(model.reminder, isTrue);
      expect(model.reminderTimes, equals(['09:00', '21:00']));
      expect(model.linkedConsultationId, equals(validConsultationUuid));
      expect(model.linkedConsultationTitle, equals('Endocrinology Review'));
      expect(model.notes, equals('Take with breakfast and dinner'));
      expect(model.clientUuid, equals(validClientUuid));
    });
  });
}
