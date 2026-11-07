import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/doctor_summary/data/export/doctor_summary_pdf_builder.dart';
import '../storage/hive_service.dart';
import '../utils/date_formatter.dart';

/// ExportService builds client-side PDF documents from local Hive health records.
class ExportService {
  final HiveService hiveService;

  ExportService({required this.hiveService});

  Future<Uint8List> generateHealthRecordsPdf({
    required List<String> selectedTypes,
    required String userName,
    required String userEmail,
  }) async {
    final pdf = pw.Document();

    final userBox = hiveService.userBox;
    final userInfo = userBox.get('profile');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'MediCrate Health Records',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#123C61'),
                    ),
                  ),
                  pw.Text(
                    DateFormatter.formatIndianDate(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Patient: ${userInfo?['name'] ?? userName}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('Email: ${userInfo?['email'] ?? userEmail}'),
                  if (userInfo?['bloodGroup'] != null)
                    pw.Text('Blood Group: ${userInfo!['bloodGroup']}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Export Summary (${selectedTypes.join(", ")})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Paragraph(
              text:
                  'This document contains self-reported and locally stored personal health records generated directly from MediCrate. All records are confidential and stored client-side.',
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Records Found', 'Status'],
              data: selectedTypes.map((type) {
                return [type, 'Local Records', 'Verified Offline'];
              }).toList(),
            ),
            pw.SizedBox(height: 24),
            pw.Footer(
              trailing: pw.Text(
                'MediCrate Health Records Export',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> previewOrPrintPdf(Uint8List pdfBytes, String filename) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: filename,
    );
  }

  Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  Future<Uint8List> generateDoctorSummaryPdf(
    dynamic summaryModel, {
    String? dateRangeLabel,
  }) async {
    return Isolate.run(
      () => buildDoctorSummaryPdfBytes(
        summaryModel,
        dateRangeLabel: dateRangeLabel,
      ),
    );
  }
}

