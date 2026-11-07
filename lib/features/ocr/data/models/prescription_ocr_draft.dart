import 'package:flutter/foundation.dart';

import 'ocr_medicine_item_draft.dart';

/// Temporary in-memory draft representing raw and parsed OCR extraction result.
@immutable
class PrescriptionOcrDraft {
  final String id;
  final String profileId;
  final String imagePath;
  final String rawText;
  final String extractedTitle;
  final String? extractedDoctorName;
  final String? extractedHospitalName;
  final DateTime extractedDate;
  final String? notes;
  final List<OcrMedicineItemDraft> extractedMedicines;
  final DateTime createdAt;

  const PrescriptionOcrDraft({
    required this.id,
    required this.profileId,
    required this.imagePath,
    required this.rawText,
    required this.extractedTitle,
    this.extractedDoctorName,
    this.extractedHospitalName,
    required this.extractedDate,
    this.notes,
    this.extractedMedicines = const [],
    required this.createdAt,
  });

  PrescriptionOcrDraft copyWith({
    String? id,
    String? profileId,
    String? imagePath,
    String? rawText,
    String? extractedTitle,
    String? extractedDoctorName,
    String? extractedHospitalName,
    DateTime? extractedDate,
    String? notes,
    List<OcrMedicineItemDraft>? extractedMedicines,
    DateTime? createdAt,
  }) {
    return PrescriptionOcrDraft(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      imagePath: imagePath ?? this.imagePath,
      rawText: rawText ?? this.rawText,
      extractedTitle: extractedTitle ?? this.extractedTitle,
      extractedDoctorName: extractedDoctorName ?? this.extractedDoctorName,
      extractedHospitalName:
          extractedHospitalName ?? this.extractedHospitalName,
      extractedDate: extractedDate ?? this.extractedDate,
      notes: notes ?? this.notes,
      extractedMedicines: extractedMedicines ?? this.extractedMedicines,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
