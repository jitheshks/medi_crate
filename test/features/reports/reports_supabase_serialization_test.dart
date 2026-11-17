import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';

void main() {
  group('ReportModel Supabase Serialization Tests (R1–R6)', () {
    const validReportUuid = '11111111-2222-3333-4444-555555555555';
    const validProfileUuid = '22222222-3333-4444-5555-666666666666';
    const validClientUuid = '33333333-4444-5555-6666-777777777777';
    const validDoctorUuid = '44444444-5555-6666-7777-888888888888';
    const validHospitalUuid = '55555555-6666-7777-8888-999999999999';
    const validConsultationUuid = '66666666-7777-8888-9999-000000000000';
    const validUserUuid = '77777777-8888-9999-0000-111111111111';

    test('1. Lab Test: correctly serializes report with UUID relations and normalized category', () {
      final report = ReportModel(
        id: 'report_$validReportUuid',
        profileId: 'prof_$validProfileUuid',
        title: 'Complete Blood Count',
        category: 'Lab Report',
        date: DateTime.utc(2026, 11, 10),
        doctorName: 'Dr. Jane Smith',
        doctorId: validDoctorUuid,
        hospitalName: 'Apollo Hospital',
        hospitalId: validHospitalUuid,
        consultationTitle: 'Cardio Follow-up',
        consultationId: validConsultationUuid,
        notes: 'Routine blood test results normal.',
        clientUuid: validClientUuid,
        createdAt: DateTime.utc(2026, 11, 10, 10, 0),
        updatedAt: DateTime.utc(2026, 11, 10, 11, 0),
      );

      final json = report.toSupabaseJson(includeId: true);

      expect(json['id'], equals(validReportUuid));
      expect(json['profile_id'], equals(validProfileUuid));
      expect(json['title'], equals('Complete Blood Count'));
      expect(json['category'], equals('LAB TEST'));
      expect(json['report_date'], equals('2026-11-10'));
      expect(json['doctor_id'], equals(validDoctorUuid));
      expect(json['doctor_name'], equals('Dr. Jane Smith'));
      expect(json['hospital_id'], equals(validHospitalUuid));
      expect(json['hospital_name'], equals('Apollo Hospital'));
      expect(json['consultation_id'], equals(validConsultationUuid));
      expect(json['consultation_title'], equals('Cardio Follow-up'));
      expect(json['notes'], equals('Routine blood test results normal.'));
      expect(json['client_uuid'], equals(validClientUuid));
      expect(json['created_at'], equals('2026-11-10T10:00:00.000Z'));
      expect(json['updated_at'], equals('2026-11-10T11:00:00.000Z'));
    });

    test('2. Foreign Keys Sanitization: non-UUID foreign keys are set to null while preserving names', () {
      final report = ReportModel(
        id: 'report_temp_12345',
        profileId: validProfileUuid,
        title: 'Chest X-Ray',
        category: 'IMAGING',
        date: DateTime.utc(2026, 11, 8),
        doctorId: 'legacy_doctor_42',
        doctorName: 'Dr. Gregory House',
        hospitalId: 'hosp_99',
        hospitalName: 'Princeton Plainsboro',
        consultationId: 'cons_123',
        consultationTitle: 'Emergency Consultation',
        clientUuid: validClientUuid,
      );

      final json = report.toSupabaseJson(includeId: false);

      expect(json.containsKey('id'), isFalse);
      expect(json['doctor_id'], isNull);
      expect(json['doctor_name'], equals('Dr. Gregory House'));
      expect(json['hospital_id'], isNull);
      expect(json['hospital_name'], equals('Princeton Plainsboro'));
      expect(json['consultation_id'], isNull);
      expect(json['consultation_title'], equals('Emergency Consultation'));
      expect(json['category'], equals('IMAGING'));
    });

    test('3. Category Normalization: check_reports_category constraint satisfaction across all variants', () {
      expect(ReportModel.normalizeCategoryToSupabase('lab test'), equals('LAB TEST'));
      expect(ReportModel.normalizeCategoryToSupabase('LABORATORY'), equals('LAB TEST'));
      expect(ReportModel.normalizeCategoryToSupabase('imaging'), equals('IMAGING'));
      expect(ReportModel.normalizeCategoryToSupabase('RADIOLOGY'), equals('IMAGING'));
      expect(ReportModel.normalizeCategoryToSupabase('X-RAY'), equals('IMAGING'));
      expect(ReportModel.normalizeCategoryToSupabase('prescription'), equals('PRESCRIPTION'));
      expect(ReportModel.normalizeCategoryToSupabase('Rx'), equals('PRESCRIPTION'));
      expect(ReportModel.normalizeCategoryToSupabase('discharge summary'), equals('DISCHARGE'));
      expect(ReportModel.normalizeCategoryToSupabase('medical certificate'), equals('CERTIFICATE'));
      expect(ReportModel.normalizeCategoryToSupabase('vaccine'), equals('VACCINATION'));
      expect(ReportModel.normalizeCategoryToSupabase('referral letter'), equals('REFERRAL'));
      expect(ReportModel.normalizeCategoryToSupabase('unknown custom'), equals('OTHER'));
    });

    test('4. ReportAttachmentModel: serializes storage path, MIME type, and bytes for report_attachments table', () {
      const validAttachmentUuid = '88888888-9999-0000-1111-222222222222';
      final att = ReportAttachmentModel(
        id: validAttachmentUuid,
        name: 'chest_scan.png',
        size: '1.5 MB',
        sizeBytes: 1572864,
        fileUrl: '$validUserUuid/$validReportUuid/att_chest_scan.png',
        fileType: 'image/png',
      );

      final json = att.toSupabaseJson(
        reportId: validReportUuid,
        userId: validUserUuid,
        includeId: true,
      );

      expect(json['id'], equals(validAttachmentUuid));
      expect(json['report_id'], equals(validReportUuid));
      expect(json['user_id'], equals(validUserUuid));
      expect(json['name'], equals('chest_scan.png'));
      expect(json['file_path'], equals('$validUserUuid/$validReportUuid/att_chest_scan.png'));
      expect(json['file_type'], equals('image/png'));
      expect(json['size_bytes'], equals(1572864));
    });

    test('5. ReportExpenseModel: serializes 1:1 expense with currency and amount', () {
      const validExpenseUuid = '99999999-0000-1111-2222-333333333333';
      final exp = ReportExpenseModel(
        id: validExpenseUuid,
        amount: 450.50,
        currency: 'INR',
        description: 'Copay paid via UPI',
      );

      final json = exp.toSupabaseJson(
        reportId: validReportUuid,
        userId: validUserUuid,
        includeId: true,
      );

      expect(json['id'], equals(validExpenseUuid));
      expect(json['report_id'], equals(validReportUuid));
      expect(json['user_id'], equals(validUserUuid));
      expect(json['amount'], equals(450.50));
      expect(json['currency'], equals('INR'));
      expect(json['description'], equals('Copay paid via UPI'));
    });

    test('6. Deserialization: ReportModel.fromSupabaseJson with joined attachments and expenses', () {
      final supabaseRow = {
        'id': validReportUuid,
        'profile_id': validProfileUuid,
        'title': 'Biochemistry Panel',
        'category': 'LAB TEST',
        'report_date': '2026-11-09',
        'doctor_id': validDoctorUuid,
        'doctor_name': 'Dr. Robert Chase',
        'hospital_id': validHospitalUuid,
        'hospital_name': 'Mayo Clinic',
        'consultation_id': null,
        'consultation_title': null,
        'notes': 'Lipid profile slightly elevated.',
        'client_uuid': validClientUuid,
        'created_at': '2026-11-09T08:00:00Z',
        'updated_at': '2026-11-09T08:30:00Z',
        'report_attachments': [
          {
            'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'name': 'biochem.pdf',
            'file_path': '$validUserUuid/$validReportUuid/biochem.pdf',
            'file_type': 'application/pdf',
            'size_bytes': 204800,
          }
        ],
        'report_expenses': [
          {
            'id': 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff',
            'amount': 1200.0,
            'currency': 'INR',
            'description': 'Lab diagnostic fee',
            'status': 'PAID',
          }
        ],
      };

      final model = ReportModel.fromSupabaseJson(supabaseRow);

      expect(model.id, equals(validReportUuid));
      expect(model.profileId, equals(validProfileUuid));
      expect(model.title, equals('Biochemistry Panel'));
      expect(model.category, equals('LAB TEST'));
      expect(model.date.year, equals(2026));
      expect(model.date.month, equals(11));
      expect(model.date.day, equals(9));
      expect(model.doctorName, equals('Dr. Robert Chase'));
      expect(model.doctorId, equals(validDoctorUuid));
      expect(model.hospitalName, equals('Mayo Clinic'));
      expect(model.hospitalId, equals(validHospitalUuid));
      expect(model.notes, equals('Lipid profile slightly elevated.'));
      expect(model.clientUuid, equals(validClientUuid));

      expect(model.attachments.length, equals(1));
      expect(model.attachments.first.name, equals('biochem.pdf'));
      expect(model.attachments.first.fileUrl, equals('$validUserUuid/$validReportUuid/biochem.pdf'));
      expect(model.attachments.first.isPdf, isTrue);
      expect(model.attachments.first.sizeBytes, equals(204800));

      expect(model.expense, isNotNull);
      expect(model.expense!.amount, equals(1200.0));
      expect(model.expense!.currency, equals('INR'));
      expect(model.expense!.description, equals('Lab diagnostic fee'));
    });
  });
}
