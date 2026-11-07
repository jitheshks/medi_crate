import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';

/// Supported entity categories for global local search.
enum SearchEntityType {
  consultation,
  doctor,
  hospital,
  medicine,
  report,
  appointment,
  vital,
}

extension SearchEntityTypeX on SearchEntityType {
  String get displayName {
    switch (this) {
      case SearchEntityType.consultation:
        return 'Consultation';
      case SearchEntityType.doctor:
        return 'Doctor';
      case SearchEntityType.hospital:
        return 'Hospital';
      case SearchEntityType.medicine:
        return 'Medicine';
      case SearchEntityType.report:
        return 'Medical Report';
      case SearchEntityType.appointment:
        return 'Appointment';
      case SearchEntityType.vital:
        return 'Vital Reading';
    }
  }

  String get filterChipLabel {
    switch (this) {
      case SearchEntityType.consultation:
        return 'Consultations';
      case SearchEntityType.doctor:
        return 'Doctors';
      case SearchEntityType.hospital:
        return 'Hospitals';
      case SearchEntityType.medicine:
        return 'Medicines';
      case SearchEntityType.report:
        return 'Reports';
      case SearchEntityType.appointment:
        return 'Appointments';
      case SearchEntityType.vital:
        return 'Vitals';
    }
  }

  IconData get icon {
    switch (this) {
      case SearchEntityType.consultation:
        return AppIcons.stethoscope;
      case SearchEntityType.doctor:
        return Icons.person_outline;
      case SearchEntityType.hospital:
        return AppIcons.hospital;
      case SearchEntityType.medicine:
        return AppIcons.pill;
      case SearchEntityType.report:
        return AppIcons.fileText;
      case SearchEntityType.appointment:
        return AppIcons.calendar;
      case SearchEntityType.vital:
        return AppIcons.activity;
    }
  }

  Color get color {
    switch (this) {
      case SearchEntityType.consultation:
        return AppColors.primary;
      case SearchEntityType.doctor:
        return AppColors.primary;
      case SearchEntityType.hospital:
        return AppColors.hospitalAccent;
      case SearchEntityType.medicine:
        return AppColors.medicineAccent;
      case SearchEntityType.report:
        return AppColors.hospitalAccent;
      case SearchEntityType.appointment:
        return AppColors.primary;
      case SearchEntityType.vital:
        return AppColors.link;
    }
  }
}

/// Lightweight, presentation-focused search result item for global local search.
@immutable
class GlobalSearchResult {
  final String id;
  final String profileId;
  final SearchEntityType type;
  final String title;
  final String subtitle;
  final String? supportingText;
  final String targetRoute;
  final DateTime? date;
  final int relevanceScore;

  const GlobalSearchResult({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.subtitle,
    this.supportingText,
    required this.targetRoute,
    this.date,
    this.relevanceScore = 0,
  });

  IconData get icon => type.icon;
  Color get color => type.color;
  String get badgeText => type.displayName.toUpperCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalSearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          profileId == other.profileId &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ profileId.hashCode ^ type.hashCode;
}
