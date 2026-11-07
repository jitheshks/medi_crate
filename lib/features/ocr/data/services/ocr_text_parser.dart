import '../models/ocr_medicine_item_draft.dart';
import '../models/prescription_ocr_draft.dart';

/// Conservative heuristic parser that extracts medical fields from raw OCR text.
class OcrTextParser {
  const OcrTextParser();

  PrescriptionOcrDraft parse({
    required String rawText,
    required String profileId,
    required String imagePath,
  }) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? doctorName;
    String? hospitalName;
    DateTime? extractedDate;
    final medicines = <OcrMedicineItemDraft>[];

    final doctorRegExp = RegExp(
      r'^(Dr\.?|Doctor)\s+([A-Za-z\.\s]{2,40})$',
      caseSensitive: false,
    );
    final hospitalKeywords = [
      'hospital',
      'clinic',
      'medical center',
      'healthcare',
      'diagnostics',
      'lab',
    ];

    final dateRegExp = RegExp(
      r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b',
    );
    final textDateRegExp = RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4}\b',
      caseSensitive: false,
    );

    final dosageRegExp = RegExp(
      r'\b\d+(\.\d+)?\s*(mg|g|mcg|ml|tab|tabs|tablet|tablets|cap|capsule|capsules)\b',
      caseSensitive: false,
    );
    final frequencyRegExp = RegExp(
      r'\b(once daily|twice daily|thrice daily|daily|bd|tds|od|qds|1-0-1|0-0-1|1-1-1|1-0-0|every \d+ hours)\b',
      caseSensitive: false,
    );
    final durationRegExp = RegExp(
      r'\b\d+\s*(days|day|weeks|week|months|month)\b',
      caseSensitive: false,
    );

    int medicineCounter = 1;

    for (final line in lines) {
      // 1. Doctor Detection
      if (doctorName == null) {
        if (doctorRegExp.hasMatch(line)) {
          doctorName = line;
        } else if (line.toLowerCase().startsWith('dr.') ||
            line.toLowerCase().startsWith('dr ')) {
          doctorName = line;
        }
      }

      // 2. Hospital / Institution Detection
      if (hospitalName == null) {
        final lowerLine = line.toLowerCase();
        for (final kw in hospitalKeywords) {
          if (lowerLine.contains(kw)) {
            hospitalName = line;
            break;
          }
        }
      }

      // 3. Date Detection
      if (extractedDate == null) {
        final match = dateRegExp.firstMatch(line);
        if (match != null) {
          final p1 = int.tryParse(match.group(1) ?? '');
          final p2 = int.tryParse(match.group(2) ?? '');
          var p3 = int.tryParse(match.group(3) ?? '');
          if (p1 != null && p2 != null && p3 != null) {
            if (p3 < 100) p3 += 2000;
            // Basic date validation
            if (p1 <= 31 && p2 <= 12) {
              extractedDate = DateTime(p3, p2, p1);
            } else if (p1 <= 12 && p2 <= 31) {
              extractedDate = DateTime(p3, p1, p2);
            }
          }
        } else if (textDateRegExp.hasMatch(line)) {
          final textMatch = textDateRegExp.firstMatch(line)?.group(0);
          if (textMatch != null) {
            final parsed = DateTime.tryParse(textMatch);
            if (parsed != null) extractedDate = parsed;
          }
        }
      }

      // 4. Medication Line Parsing
      final dosageMatch = dosageRegExp.firstMatch(line);
      final freqMatch = frequencyRegExp.firstMatch(line);
      final durMatch = durationRegExp.firstMatch(line);

      if (dosageMatch != null || freqMatch != null) {
        final dosage = dosageMatch?.group(0) ?? '';
        final frequency = freqMatch?.group(0) ?? 'As prescribed';

        var durationDays = 30;
        if (durMatch != null) {
          final durText = durMatch.group(0)!.toLowerCase();
          final numVal =
              int.tryParse(durText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          if (durText.contains('day')) {
            durationDays = numVal;
          } else if (durText.contains('week')) {
            durationDays = numVal * 7;
          } else if (durText.contains('month')) {
            durationDays = numVal * 30;
          }
        }

        // Clean medicine name by stripping recognized dosage/freq strings
        var medName = line
            .replaceAll(dosageRegExp, '')
            .replaceAll(frequencyRegExp, '')
            .replaceAll(durationRegExp, '')
            .replaceAll(RegExp(r'[^\w\s\-]'), '')
            .trim();

        if (medName.isEmpty) {
          medName = 'Medication #$medicineCounter';
        }

        medicines.add(
          OcrMedicineItemDraft(
            id: 'draft_med_${DateTime.now().millisecondsSinceEpoch}_$medicineCounter',
            medicationName: medName,
            dosage: dosage,
            frequency: frequency,
            durationDays: durationDays,
          ),
        );
        medicineCounter++;
      }
    }

    final date = extractedDate ?? DateTime.now();

    String title = 'Prescription';
    if (doctorName != null) {
      title = 'Prescription — $doctorName';
    } else if (hospitalName != null) {
      title = 'Prescription — $hospitalName';
    }

    return PrescriptionOcrDraft(
      id: 'draft_rx_${DateTime.now().millisecondsSinceEpoch}',
      profileId: profileId,
      imagePath: imagePath,
      rawText: rawText,
      extractedTitle: title,
      extractedDoctorName: doctorName,
      extractedHospitalName: hospitalName,
      extractedDate: date,
      extractedMedicines: medicines,
      createdAt: DateTime.now(),
    );
  }
}
