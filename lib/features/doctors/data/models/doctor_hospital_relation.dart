import 'package:flutter/foundation.dart';
import 'package:medivalut/features/hospitals/data/models/hospital_model.dart';

/// Represents a practicing hospital associated with a doctor, distinguishing
/// direct configuration vs consultation-derived relationship.
@immutable
class PracticingHospitalInfo {
  final HospitalModel hospital;
  final bool isDirect;
  final bool isFromConsultation;
  final int consultationCount;

  const PracticingHospitalInfo({
    required this.hospital,
    required this.isDirect,
    required this.isFromConsultation,
    this.consultationCount = 0,
  });

  /// Name of the hospital
  String get name => hospital.name;

  /// User-facing relationship source label.
  String get relationshipLabel {
    if (isDirect && isFromConsultation) {
      return 'Direct relationship';
    } else if (isDirect) {
      return 'Direct relationship';
    } else {
      return 'From consultation';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PracticingHospitalInfo &&
          runtimeType == other.runtimeType &&
          hospital.id == other.hospital.id &&
          isDirect == other.isDirect &&
          isFromConsultation == other.isFromConsultation &&
          consultationCount == other.consultationCount;

  @override
  int get hashCode =>
      hospital.id.hashCode ^
      isDirect.hashCode ^
      isFromConsultation.hashCode ^
      consultationCount.hashCode;
}

/// Represents a breakdown item of dependent linked records.
@immutable
class EntityDependencyItem {
  final String label;
  final int count;
  final String iconEmoji;

  const EntityDependencyItem({
    required this.label,
    required this.count,
    required this.iconEmoji,
  });
}

/// Aggregates all linked entity dependencies for deletion safety checks.
@immutable
class EntityDependencies {
  final int doctors;
  final int hospitals;
  final int consultations;
  final int reports;
  final int medicines;
  final int appointments;

  const EntityDependencies({
    this.doctors = 0,
    this.hospitals = 0,
    this.consultations = 0,
    this.reports = 0,
    this.medicines = 0,
    this.appointments = 0,
  });

  int get totalCount =>
      doctors + hospitals + consultations + reports + medicines + appointments;

  bool get hasDependencies => totalCount > 0;

  List<EntityDependencyItem> get activeItems {
    final items = <EntityDependencyItem>[];
    if (doctors > 0) {
      items.add(
        EntityDependencyItem(
          count: doctors,
          label: doctors == 1 ? 'doctor' : 'doctors',
          iconEmoji: '👨‍⚕️',
        ),
      );
    }
    if (hospitals > 0) {
      items.add(
        EntityDependencyItem(
          count: hospitals,
          label: hospitals == 1 ? 'hospital' : 'hospitals',
          iconEmoji: '🏥',
        ),
      );
    }
    if (consultations > 0) {
      items.add(
        EntityDependencyItem(
          count: consultations,
          label: consultations == 1 ? 'consultation' : 'consultations',
          iconEmoji: '🩺',
        ),
      );
    }
    if (appointments > 0) {
      items.add(
        EntityDependencyItem(
          count: appointments,
          label: appointments == 1 ? 'appointment' : 'appointments',
          iconEmoji: '📅',
        ),
      );
    }
    if (reports > 0) {
      items.add(
        EntityDependencyItem(
          count: reports,
          label: reports == 1 ? 'report' : 'reports',
          iconEmoji: '📄',
        ),
      );
    }
    if (medicines > 0) {
      items.add(
        EntityDependencyItem(
          count: medicines,
          label: medicines == 1 ? 'medicine' : 'medicines',
          iconEmoji: '💊',
        ),
      );
    }
    return items;
  }
}
