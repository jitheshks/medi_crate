import 'package:flutter/foundation.dart';

/// Represents a single draft medicine item extracted during OCR text parsing.
@immutable
class OcrMedicineItemDraft {
  final String id;
  final String medicationName;
  final String dosage;
  final String frequency;
  final int durationDays;
  final String timing;

  const OcrMedicineItemDraft({
    required this.id,
    required this.medicationName,
    this.dosage = '',
    this.frequency = '',
    this.durationDays = 30,
    this.timing = 'As prescribed',
  });

  OcrMedicineItemDraft copyWith({
    String? id,
    String? medicationName,
    String? dosage,
    String? frequency,
    int? durationDays,
    String? timing,
  }) {
    return OcrMedicineItemDraft(
      id: id ?? this.id,
      medicationName: medicationName ?? this.medicationName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      durationDays: durationDays ?? this.durationDays,
      timing: timing ?? this.timing,
    );
  }
}
