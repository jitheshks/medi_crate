import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';

void main() {
  group('AppointmentModel Supabase Serialization Tests', () {
    const validAppointmentUuid = '11111111-2222-3333-4444-555555555555';
    const validProfileUuid = '22222222-3333-4444-5555-666666666666';
    const validDoctorUuid = '33333333-4444-5555-6666-777777777777';
    const validHospitalUuid = '44444444-5555-6666-7777-888888888888';
    const validClientUuid = '55555555-6666-7777-8888-999999999999';

    test('toSupabaseJson maps canonical database schema with UUID foreign keys', () {
      final appointment = AppointmentModel(
        id: 'appointment_$validAppointmentUuid',
        profileId: 'prof_$validProfileUuid',
        title: 'Cardiology Review',
        doctorName: 'Dr. John Watson',
        doctorId: 'doc_$validDoctorUuid',
        doctorSpecialty: 'Cardiology',
        hospitalName: 'St. Mary Hospital',
        hospitalId: 'hosp_$validHospitalUuid',
        departmentId: '12',
        department: 'CARDIOLOGY',
        date: DateTime.utc(2026, 11, 20, 14, 30),
        reminderEnabled: true,
        notes: 'Bring previous ECG records',
        cost: 750.0,
        currency: 'INR',
        status: 'Upcoming',
        clientUuid: validClientUuid,
        createdAt: DateTime.utc(2026, 11, 10, 10, 0),
        updatedAt: DateTime.utc(2026, 11, 10, 10, 0),
      );

      final json = appointment.toSupabaseJson(includeId: true);

      expect(json['id'], equals(validAppointmentUuid));
      expect(json['profile_id'], equals(validProfileUuid));
      expect(json['title'], equals('Cardiology Review'));
      expect(json['doctor_name'], equals('Dr. John Watson'));
      expect(json['doctor_id'], equals(validDoctorUuid));
      expect(json['doctor_specialty'], equals('Cardiology'));
      expect(json['hospital_id'], equals(validHospitalUuid));
      expect(json['hospital_name'], equals('St. Mary Hospital'));
      expect(json['department_id'], equals(12));
      expect(json['department'], equals('CARDIOLOGY'));
      expect(json['appointment_date'], equals('2026-11-20T14:30:00.000Z'));
      expect(json['reminder_enabled'], isTrue);
      expect(json['notes'], equals('Bring previous ECG records'));
      expect(json['cost'], equals(750.0));
      expect(json['currency'], equals('INR'));
      expect(json['status'], equals('upcoming'));
      expect(json['client_uuid'], equals(validClientUuid));
    });

    test('toSupabaseJson sanitizes invalid non-UUID foreign keys to null', () {
      final appointment = AppointmentModel(
        id: 'temp_local_123',
        profileId: 'prof_$validProfileUuid',
        title: 'General Follow-up',
        doctorName: 'Dr. House',
        doctorId: 'doc_non_uuid_legacy',
        hospitalId: 'legacy_hosp_999',
        departmentId: 'not_a_number',
        date: DateTime.utc(2026, 11, 22, 10, 0),
        createdAt: DateTime.utc(2026, 11, 10),
        updatedAt: DateTime.utc(2026, 11, 10),
      );

      final json = appointment.toSupabaseJson(includeId: false);

      expect(json.containsKey('id'), isFalse);
      expect(json['profile_id'], equals(validProfileUuid));
      expect(json['doctor_id'], isNull);
      expect(json['hospital_id'], isNull);
      expect(json['department_id'], isNull);
    });

    test('fromSupabaseJson parses database row into canonical AppointmentModel', () {
      final dbRow = {
        'id': validAppointmentUuid,
        'profile_id': validProfileUuid,
        'title': 'Dermatology Consultation',
        'doctor_name': 'Dr. Lisa Cuddy',
        'doctor_id': validDoctorUuid,
        'doctor_specialty': 'Dermatology',
        'hospital_id': validHospitalUuid,
        'hospital_name': 'Princeton Hospital',
        'department_id': 5,
        'department': 'DERMATOLOGY',
        'appointment_date': '2026-11-25T11:00:00.000Z',
        'reminder_enabled': false,
        'notes': 'Skin lesion assessment',
        'cost': '1200.50',
        'currency': 'INR',
        'status': 'confirmed',
        'client_uuid': validClientUuid,
        'created_at': '2026-11-10T08:00:00.000Z',
        'updated_at': '2026-11-10T08:30:00.000Z',
      };

      final model = AppointmentModel.fromSupabaseJson(dbRow);

      expect(model.id, equals('appointment_$validAppointmentUuid'));
      expect(model.profileId, equals(validProfileUuid));
      expect(model.title, equals('Dermatology Consultation'));
      expect(model.doctorName, equals('Dr. Lisa Cuddy'));
      expect(model.doctorId, equals(validDoctorUuid));
      expect(model.doctorSpecialty, equals('Dermatology'));
      expect(model.hospitalId, equals(validHospitalUuid));
      expect(model.hospitalName, equals('Princeton Hospital'));
      expect(model.departmentId, equals('5'));
      expect(model.department, equals('DERMATOLOGY'));
      expect(model.date.toUtc(), equals(DateTime.utc(2026, 11, 25, 11, 0)));
      expect(model.reminderEnabled, isFalse);
      expect(model.notes, equals('Skin lesion assessment'));
      expect(model.cost, equals(1200.50));
      expect(model.currency, equals('INR'));
      expect(model.status, equals('confirmed'));
      expect(model.clientUuid, equals(validClientUuid));
    });
  });
}
