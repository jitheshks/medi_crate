import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_attachment.dart';
import 'package:medi_crate/features/consultations/data/models/consultation_model.dart';

void main() {
  group('ConsultationModel Supabase Serialization Tests', () {
    const consultationId = '11111111-2222-3333-4444-555555555555';
    const profileId = '22222222-3333-4444-5555-666666666666';
    const doctorId = '33333333-4444-5555-6666-777777777777';
    const hospitalId = '44444444-5555-6666-7777-888888888888';
    final visitDate = DateTime(2026, 5, 20);
    final followUpDate = DateTime(2026, 5, 27);

    test('toSupabaseJson maps fields correctly matching public.consultations schema', () {
      final model = ConsultationModel(
        id: consultationId,
        profileId: profileId,
        doctorId: doctorId,
        doctorName: 'Dr. House',
        doctorSpecialty: 'Diagnostics',
        hospitalId: hospitalId,
        hospitalName: 'Princeton Plainsboro',
        departmentId: '15',
        department: 'Neurology',
        visitDate: visitDate,
        visitTime: '10:30 AM',
        chiefComplaint: 'Severe migraine and light sensitivity',
        diagnosis: 'Occipital neuralgia',
        clinicalNotes: 'Prescribed medication and scheduled follow-up MRI.',
        isFollowUpRequired: true,
        followUpDate: followUpDate,
        followUpTime: '11:00 AM',
        followUpReminder: true,
        followUpNotes: 'Review MRI results',
        isFollowUpDone: false,
        followUpStatus: 'Pending',
        tags: const ['migraine', 'neurology'],
        consultationFee: 750.0,
        currency: 'INR',
        clientUuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        createdAt: DateTime(2026, 5, 20, 10, 30),
      );

      final json = model.toSupabaseJson(includeId: true);

      expect(json['id'], equals(consultationId));
      expect(json['profile_id'], equals(profileId));
      expect(json['doctor_id'], equals(doctorId));
      expect(json['doctor_name'], equals('Dr. House'));
      expect(json['doctor_specialty'], equals('Diagnostics'));
      expect(json['hospital_id'], equals(hospitalId));
      expect(json['hospital_name'], equals('Princeton Plainsboro'));
      expect(json['department_id'], equals(15));
      expect(json['department'], equals('Neurology'));
      expect(json['visit_date'], equals('2026-05-20'));
      expect(json['visit_time'], equals('10:30 AM'));
      expect(json['chief_complaint'], equals('Severe migraine and light sensitivity'));
      expect(json['diagnosis'], equals('Occipital neuralgia'));
      expect(json['clinical_notes'], equals('Prescribed medication and scheduled follow-up MRI.'));
      expect(json['is_follow_up_required'], isTrue);
      expect(json['follow_up_date'], equals('2026-05-27'));
      expect(json['follow_up_time'], equals('11:00 AM'));
      expect(json['follow_up_reminder'], isTrue);
      expect(json['follow_up_notes'], equals('Review MRI results'));
      expect(json['is_follow_up_done'], isFalse);
      expect(json['follow_up_status'], equals('pending'));
      expect(json['tags'], equals(['migraine', 'neurology']));
      expect(json['consultation_fee'], equals(750.0));
      expect(json['currency'], equals('INR'));
      expect(json['client_uuid'], equals('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'));
    });

    test('toSupabaseJson strips prefixes and excludes non-UUID temporary IDs', () {
      final model = ConsultationModel(
        id: 'consultation_temporary_123',
        profileId: 'prof_$profileId',
        doctorId: 'doctor_$doctorId',
        doctorName: 'Dr. Cuddy',
        chiefComplaint: 'Checkup',
        diagnosis: 'Healthy',
        visitDate: visitDate,
        createdAt: DateTime.now(),
      );

      final json = model.toSupabaseJson(includeId: true);

      // Temporary non-UUID ID is omitted
      expect(json.containsKey('id'), isFalse);
      expect(json['profile_id'], equals(profileId));
      expect(json['doctor_id'], equals(doctorId));
    });

    test('fromSupabaseJson parses complete PostgREST row with embedded consultation_attachments', () {
      final postgrestRow = {
        'id': consultationId,
        'profile_id': profileId,
        'doctor_id': doctorId,
        'doctor_name': 'Dr. Robert Chase',
        'doctor_specialty': 'Intensive Care',
        'hospital_id': hospitalId,
        'hospital_name': 'City Hospital',
        'department_id': 12,
        'department': 'Critical Care',
        'visit_date': '2026-05-20',
        'visit_time': '02:15 PM',
        'chief_complaint': 'Chest discomfort',
        'diagnosis': 'Costochondritis',
        'clinical_notes': 'ECG normal.',
        'is_follow_up_required': false,
        'follow_up_date': null,
        'follow_up_time': null,
        'follow_up_reminder': false,
        'follow_up_notes': null,
        'is_follow_up_done': false,
        'follow_up_status': 'pending',
        'tags': ['chest', 'cardio'],
        'consultation_fee': 500.0,
        'currency': 'INR',
        'client_uuid': 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff',
        'created_at': '2026-05-20T14:15:00Z',
        'consultation_attachments': [
          {
            'id': 'att-uuid-1',
            'name': 'ecg_report.pdf',
            'file_path': 'user/consultation/ecg_report.pdf',
            'file_type': 'application/pdf',
            'size_bytes': 204800,
          }
        ],
      };

      final parsed = ConsultationModel.fromSupabaseJson(postgrestRow);

      expect(parsed.id, equals(consultationId));
      expect(parsed.profileId, equals(profileId));
      expect(parsed.doctorName, equals('Dr. Robert Chase'));
      expect(parsed.attachments.length, equals(1));
      expect(parsed.attachments.first.name, equals('ecg_report.pdf'));
      expect(parsed.attachments.first.isPdf, isTrue);
      expect(parsed.attachments.first.sizeKB, equals(200));
    });
  });

  group('ConsultationAttachment Supabase Serialization Tests', () {
    const attId = '99999999-8888-7777-6666-555555555555';
    const consultationId = '11111111-2222-3333-4444-555555555555';
    const userId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

    test('toSupabaseJson and fromSupabaseJson round-trip attachment metadata', () {
      const att = ConsultationAttachment(
        id: attId,
        name: 'blood_test_scan.jpg',
        sizeKB: 350,
        filePath: 'user_1/cons_1/blood_test_scan.jpg',
        fileType: 'image/jpeg',
      );

      final json = att.toSupabaseJson(
        consultationId: consultationId,
        userId: userId,
        includeId: true,
      );

      expect(json['id'], equals(attId));
      expect(json['consultation_id'], equals(consultationId));
      expect(json['user_id'], equals(userId));
      expect(json['name'], equals('blood_test_scan.jpg'));
      expect(json['size_bytes'], equals(350 * 1024));

      final fromJson = ConsultationAttachment.fromSupabaseJson(json);
      expect(fromJson.id, equals(attId));
      expect(fromJson.name, equals('blood_test_scan.jpg'));
      expect(fromJson.sizeKB, equals(350));
      expect(fromJson.isImage, isTrue);
    });
  });
}
