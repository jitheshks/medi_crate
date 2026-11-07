import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/date_formatter.dart';

String _formatDate(dynamic rawDate) {
  return DateFormatter.formatIndianDate(rawDate, fallback: '');
}

/// Builds PDF document bytes for a doctor summary in a background isolate or synchronously.
Future<Uint8List> buildDoctorSummaryPdfBytes(
  dynamic summaryModel, {
  String? dateRangeLabel,
}) async {
  final pdf = pw.Document();

  final profile = summaryModel.profile;
  final consultations =
      (summaryModel.consultations as List?)?.cast<Map<String, dynamic>>() ??
      const [];
  final medicines =
      (summaryModel.medicines as List?)?.cast<Map<String, dynamic>>() ??
      const [];
  final vitals =
      (summaryModel.vitals as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final reports =
      (summaryModel.reports as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final appointments =
      (summaryModel.appointments as List?)?.cast<Map<String, dynamic>>() ??
      const [];
  final doctors =
      (summaryModel.doctors as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final hospitals =
      (summaryModel.hospitals as List?)?.cast<Map<String, dynamic>>() ??
      const [];
  final effectiveDateRangeLabel =
      dateRangeLabel ?? summaryModel.dateRangeLabel?.toString();

  // Format age/dob/height/weight/bmi safely
  String? ageStr;
  String? dobStr;
  String? heightStr;
  String? weightStr;
  String? bmiStr;
  String allergiesStr = 'Not recorded';
  String conditionsStr = 'Not recorded';

  try {
    ageStr = summaryModel.formattedAge;
    dobStr = summaryModel.formattedDob;
    heightStr = summaryModel.formattedHeight;
    weightStr = summaryModel.formattedWeight;
    bmiStr = summaryModel.formattedBmi(forPdf: true);
    allergiesStr = summaryModel.formattedAllergies;
    conditionsStr = summaryModel.formattedChronicConditions;
  } catch (_) {}

  // Deduplicate Care Team: Omit doctors/hospitals already listed in consultations or appointments
  final mentionedDoctorNames = <String>{};
  final mentionedHospitalNames = <String>{};

  for (final c in consultations) {
    final dName = (c['doctor_name'] ?? c['doctorName'] ?? c['doctor'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (dName != null && dName.isNotEmpty) mentionedDoctorNames.add(dName);
    final hName = (c['hospital_name'] ?? c['hospitalName'] ?? c['hospital'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (hName != null && hName.isNotEmpty) {
      mentionedHospitalNames.add(hName);
    }
  }

  for (final a in appointments) {
    final dName = (a['doctor_name'] ?? a['doctorName'] ?? a['doctor'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (dName != null && dName.isNotEmpty) mentionedDoctorNames.add(dName);
    final hName = (a['hospital_name'] ?? a['hospitalName'] ?? a['hospital'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (hName != null && hName.isNotEmpty) {
      mentionedHospitalNames.add(hName);
    }
  }

  final distinctDoctors = doctors.where((d) {
    final name = (d['name'] ?? d['doctor_name'])
        ?.toString()
        .trim()
        .toLowerCase();
    return name != null &&
        name.isNotEmpty &&
        !mentionedDoctorNames.contains(name);
  }).toList();

  final distinctHospitals = hospitals.where((h) {
    final name = (h['name'] ?? h['hospital_name'])
        ?.toString()
        .trim()
        .toLowerCase();
    return name != null &&
        name.isNotEmpty &&
        !mentionedHospitalNames.contains(name);
  }).toList();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MediCrate Confidential Medical Summary',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        );
      },
      build: (pw.Context context) {
        final demoParts = <String>[
          'Relationship: ${profile.relationship.toUpperCase()}',
          'Gender: ${profile.gender ?? 'Unspecified'}',
          if (ageStr != null) 'Age: $ageStr',
          if (dobStr != null && ageStr == null) 'DOB: $dobStr',
          'Blood Group: ${profile.bloodGroup ?? 'N/A'}',
        ];

        final bioParts = <String>[
          if (heightStr != null) 'Height: $heightStr',
          if (weightStr != null) 'Weight: $weightStr',
          if (bmiStr != null) 'BMI: $bmiStr',
        ];

        return [
          // Top Header
          pw.Header(
            level: 0,
            decoration: const pw.BoxDecoration(),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MediCrate - Doctor Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#123C61'),
                  ),
                ),
                pw.Text(
                  _formatDate(DateTime.now()),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),

          // Patient Demographic Block
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              border: pw.Border.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.8,
              ),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Patient: ${profile.fullName}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                    if (effectiveDateRangeLabel != null &&
                        effectiveDateRangeLabel.isNotEmpty)
                      pw.Text(
                        'Period: $effectiveDateRangeLabel',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#123C61'),
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  demoParts.join(' | '),
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey800,
                  ),
                ),
                if (bioParts.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    bioParts.join(' | '),
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
                pw.SizedBox(height: 4),
                pw.Divider(
                  height: 1,
                  thickness: 0.5,
                  color: PdfColor.fromHex('#CBD5E1'),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Allergies: $allergiesStr',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: profile.allergies.isNotEmpty
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                          color: profile.allergies.isNotEmpty
                              ? PdfColors.red800
                              : PdfColors.grey700,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        'Chronic Conditions: $conditionsStr',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: profile.chronicConditions.isNotEmpty
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                          color: profile.chronicConditions.isNotEmpty
                              ? PdfColor.fromHex('#123C61')
                              : PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // 1. Medications
          if (medicines.isNotEmpty) ...[
            pw.Text(
              'Medications',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              headers: ['Medication', 'Dosage', 'Frequency'],
              data: medicines.map((m) {
                return [
                  m['medication_name']?.toString() ?? '',
                  m['dosage']?.toString() ?? '',
                  m['frequency']?.toString() ?? '',
                ];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerHeight: 20,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.0),
                1: pw.FlexColumnWidth(1.8),
                2: pw.FlexColumnWidth(2.2),
              },
            ),
            pw.SizedBox(height: 10),
          ],

          // 2. Vital Signs
          if (vitals.isNotEmpty) ...[
            pw.Text(
              'Vital Signs',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              headers: ['Measurement', 'Value', 'Status', 'Date'],
              data: vitals.map((v) {
                final title =
                    v['title']
                        ?.toString()
                        .replaceAll('SpO\u2082', 'SpO2')
                        .replaceAll('SpO2', 'SpO2') ??
                    '';
                final unit =
                    v['unit']
                        ?.toString()
                        .replaceAll('\u00B0C', 'C')
                        .replaceAll('kg/m\u00B2', 'kg/m2') ??
                    '';
                final rawDate =
                    v['recorded_at'] ?? v['date'] ?? v['created_at'];
                final dateStr = _formatDate(rawDate);
                return [
                  title,
                  '${v['value']} $unit'.trim(),
                  v['status']?.toString() ?? 'NORMAL',
                  dateStr,
                ];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerHeight: 20,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.8),
                1: pw.FlexColumnWidth(1.8),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(1.8),
              },
            ),
            pw.SizedBox(height: 10),
          ],

          // 3. Consultations
          if (consultations.isNotEmpty) ...[
            pw.Text(
              'Consultations',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              headers: ['Diagnosis', 'Doctor', 'Hospital', 'Notes'],
              data: consultations.map((c) {
                return [
                  c['diagnosis']?.toString() ?? 'General Visit',
                  c['doctor_name']?.toString() ?? 'N/A',
                  c['hospital_name']?.toString() ?? 'N/A',
                  c['clinical_notes']?.toString() ?? '',
                ];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerHeight: 20,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.6),
                1: pw.FlexColumnWidth(2.0),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(3.6),
              },
            ),
            pw.SizedBox(height: 10),
          ],

          // 4. Lab Reports
          if (reports.isNotEmpty) ...[
            pw.Text(
              'Lab Reports',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              headers: ['Report Title', 'Category', 'Date', 'Notes'],
              data: reports.map((r) {
                final noteStr =
                    r['notes']?.toString() ??
                    r['patient_notes']?.toString() ??
                    '';
                final rawDate =
                    r['date'] ?? r['report_date'] ?? r['created_at'];
                final dateStr = _formatDate(rawDate);
                return [
                  r['title']?.toString() ?? '',
                  r['category']?.toString() ?? 'General',
                  dateStr,
                  noteStr.isNotEmpty ? 'Patient-entered note: $noteStr' : '',
                ];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerHeight: 20,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.0),
                1: pw.FlexColumnWidth(1.8),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(3.6),
              },
            ),
            pw.SizedBox(height: 10),
          ],

          // 5. Appointments & Follow-ups
          if (appointments.isNotEmpty) ...[
            pw.Text(
              'Appointments & Follow-ups',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              headers: ['Title', 'Doctor', 'Hospital', 'Date', 'Status'],
              data: appointments.map((a) {
                final rawDate = a['date'] ?? a['appointment_date'];
                final dateStr = rawDate != null ? _formatDate(rawDate) : 'N/A';
                return [
                  a['title']?.toString() ?? 'Appointment',
                  a['doctor_name']?.toString() ?? 'N/A',
                  a['hospital_name']?.toString() ?? 'N/A',
                  dateStr,
                  a['status']?.toString() ?? 'Scheduled',
                ];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerHeight: 20,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.6),
                1: pw.FlexColumnWidth(2.0),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(1.4),
              },
            ),
            pw.SizedBox(height: 10),
          ],

          // 6. Care Team (Only rendered if distinct standalone providers exist)
          if (distinctDoctors.isNotEmpty || distinctHospitals.isNotEmpty) ...[
            pw.Text(
              'Care Team',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              headers: ['Type', 'Name', 'Specialty / Details'],
              data: [
                ...distinctDoctors.map(
                  (d) => [
                    'Doctor',
                    d['name']?.toString() ?? 'Doctor',
                    d['specialty']?.toString() ?? 'General',
                  ],
                ),
                ...distinctHospitals.map(
                  (h) => [
                    'Hospital',
                    h['name']?.toString() ?? 'Hospital',
                    h['location']?.toString() ?? h['address']?.toString() ?? '',
                  ],
                ),
              ],
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#123C61'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerHeight: 20,
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(3.0),
                2: pw.FlexColumnWidth(4.5),
              },
            ),
            pw.SizedBox(height: 10),
          ],

          // Medical Disclaimer
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
            ),
            child: pw.Text(
              'Disclaimer: For patient reference only. Not an official medical diagnosis. Confidentially generated client-side from MediCrate.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}
