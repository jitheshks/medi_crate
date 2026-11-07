import 'package:flutter/material.dart';
import '../../../profile/data/models/profile_model.dart';

/// DoctorSummaryModel aggregates profile-scoped clinical history for rapid physician review.
class DoctorSummaryModel {
  final ProfileModel profile;
  final List<Map<String, dynamic>> consultations;
  final List<Map<String, dynamic>> medicines;
  final List<Map<String, dynamic>> vitals;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> hospitals;
  final DateTimeRange? dateRange;
  final String? dateRangeLabel;

  const DoctorSummaryModel({
    required this.profile,
    required this.consultations,
    required this.medicines,
    required this.vitals,
    required this.reports,
    this.appointments = const [],
    this.doctors = const [],
    this.hospitals = const [],
    this.dateRange,
    this.dateRangeLabel,
  });

  int get totalClinicalItems =>
      consultations.length +
      medicines.length +
      vitals.length +
      reports.length +
      appointments.length;

  int get totalAllItems =>
      totalClinicalItems + doctors.length + hospitals.length;

  /// Formatted age string in years (e.g. '28 yrs'), or null if missing/invalid.
  String? get formattedAge {
    if (profile.dateOfBirth != null && profile.dateOfBirth!.trim().isNotEmpty) {
      final dob = DateTime.tryParse(profile.dateOfBirth!.trim());
      if (dob != null) {
        final now = DateTime.now();
        var age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
        if (age >= 0 && age < 130) {
          return '$age yrs';
        }
      }
    }
    return null;
  }

  /// Formatted date of birth string (e.g. '15/08/1995'), or null if missing.
  String? get formattedDob {
    if (profile.dateOfBirth != null && profile.dateOfBirth!.trim().isNotEmpty) {
      final dob = DateTime.tryParse(profile.dateOfBirth!.trim());
      if (dob != null) {
        final d = dob.day.toString().padLeft(2, '0');
        final m = dob.month.toString().padLeft(2, '0');
        final y = dob.year.toString();
        return '$d/$m/$y';
      }
      return profile.dateOfBirth!.trim();
    }
    return null;
  }

  /// Formatted height string (e.g. '175 cm'), or null if missing/invalid.
  String? get formattedHeight {
    final h = profile.height;
    if (h != null && h > 0 && h < 300) {
      final str = (h % 1 == 0) ? h.toInt().toString() : h.toStringAsFixed(1);
      return '$str cm';
    }
    return null;
  }

  /// Formatted weight string (e.g. '70 kg'), or null if missing/invalid.
  String? get formattedWeight {
    final w = profile.weight;
    if (w != null && w > 0 && w < 500) {
      final str = (w % 1 == 0) ? w.toInt().toString() : w.toStringAsFixed(1);
      return '$str kg';
    }
    return null;
  }

  /// Formatted BMI string (e.g. '22.9 kg/m²' or '22.9 kg/m2' for PDF).
  ///
  /// Precedence Rule:
  /// 1. Calculated dynamically from profile height (cm) and weight (kg) if both are valid.
  /// 2. Fallback to most recent recorded BMI in [vitals] if available.
  /// 3. Returns null if neither source is available or valid.
  String? formattedBmi({bool forPdf = false}) {
    final h = profile.height;
    final w = profile.weight;
    if (h != null && h > 30 && h < 300 && w != null && w > 1 && w < 500) {
      final heightM = h / 100.0;
      final bmi = w / (heightM * heightM);
      if (bmi >= 5 && bmi <= 150 && !bmi.isNaN && !bmi.isInfinite) {
        final unit = forPdf ? 'kg/m2' : 'kg/m²';
        return '${bmi.toStringAsFixed(1)} $unit';
      }
    }

    for (final v in vitals) {
      final type = v['type']?.toString().toLowerCase();
      final title = v['title']?.toString().toLowerCase();
      if (type == 'bmi' || title == 'bmi') {
        final val = v['value']?.toString();
        if (val != null &&
            val.isNotEmpty &&
            val != '--' &&
            val != 'NO DATA' &&
            val != 'NOT RECORDED') {
          final unit = forPdf ? 'kg/m2' : (v['unit']?.toString() ?? 'kg/m²');
          return '$val $unit';
        }
      }
    }
    return null;
  }

  /// Formatted allergies summary respecting explicit confirmation flags.
  String get formattedAllergies {
    if (profile.allergies.isNotEmpty) {
      return profile.allergies.join(', ');
    }
    if (profile.allergiesConfirmedNone) {
      return 'No known allergies';
    }
    return 'Not recorded';
  }

  /// Formatted chronic conditions summary respecting explicit confirmation flags.
  String get formattedChronicConditions {
    if (profile.chronicConditions.isNotEmpty) {
      return profile.chronicConditions.join(', ');
    }
    if (profile.chronicConditionsConfirmedNone) {
      return 'None';
    }
    return 'Not recorded';
  }

  /// Returns selected vital measurements grouped by vital type (e.g. Blood Pressure, Heart Rate)
  /// and sorted chronologically (oldest to newest for trend visualization).
  Map<String, List<Map<String, dynamic>>> get groupedVitals {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final v in vitals) {
      final typeKey = (v['type'] ?? v['title'] ?? 'Other').toString();
      grouped.putIfAbsent(typeKey, () => []).add(v);
    }

    // Sort each group chronologically by date
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        DateTime? dateA;
        DateTime? dateB;

        final rawA = a['recorded_at'] ?? a['date'] ?? a['created_at'];
        if (rawA is DateTime) {
          dateA = rawA;
        } else if (rawA is String) {
          dateA = DateTime.tryParse(rawA);
        }

        final rawB = b['recorded_at'] ?? b['date'] ?? b['created_at'];
        if (rawB is DateTime) {
          dateB = rawB;
        } else if (rawB is String) {
          dateB = DateTime.tryParse(rawB);
        }

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return -1;
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });
    }

    return grouped;
  }

  DoctorSummaryModel copyWith({
    ProfileModel? profile,
    List<Map<String, dynamic>>? consultations,
    List<Map<String, dynamic>>? medicines,
    List<Map<String, dynamic>>? vitals,
    List<Map<String, dynamic>>? reports,
    List<Map<String, dynamic>>? appointments,
    List<Map<String, dynamic>>? doctors,
    List<Map<String, dynamic>>? hospitals,
    DateTimeRange? dateRange,
    String? dateRangeLabel,
  }) {
    return DoctorSummaryModel(
      profile: profile ?? this.profile,
      consultations: consultations ?? this.consultations,
      medicines: medicines ?? this.medicines,
      vitals: vitals ?? this.vitals,
      reports: reports ?? this.reports,
      appointments: appointments ?? this.appointments,
      doctors: doctors ?? this.doctors,
      hospitals: hospitals ?? this.hospitals,
      dateRange: dateRange ?? this.dateRange,
      dateRangeLabel: dateRangeLabel ?? this.dateRangeLabel,
    );
  }
}
