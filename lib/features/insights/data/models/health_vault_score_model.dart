import 'package:flutter/foundation.dart';

/// HealthVaultCategoryScore represents the completeness score of one category in the Health Vault.
@immutable
class HealthVaultCategoryScore {
  final String name;
  final num score; // earned points
  final int maxScore; // 40 for vitals, 20 for profile/consultations/reports
  final bool isComplete;
  final String statusDetail;

  const HealthVaultCategoryScore({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.isComplete,
    required this.statusDetail,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'max_score': maxScore,
    'is_complete': isComplete,
    'status_detail': statusDetail,
  };

  factory HealthVaultCategoryScore.fromJson(Map<String, dynamic> json) {
    return HealthVaultCategoryScore(
      name: json['name'] as String? ?? '',
      score: (json['score'] as num?) ?? 0,
      maxScore: json['max_score'] as int? ?? 20,
      isComplete: json['is_complete'] as bool? ?? false,
      statusDetail: json['status_detail'] as String? ?? '',
    );
  }
}

/// HealthVaultScoreModel aggregates the 4 record completeness categories
/// (Vitals 40pts, Profile 20pts, Consultations 20pts, Reports 20pts)
/// into a 0-100 Health Record Completeness score.
@immutable
class HealthVaultScoreModel {
  static const int maxVaultScore = 100;
  static const int vitalRecencyDays = 365;

  final int totalScore; // 0 - 100
  final HealthVaultCategoryScore vitalsCategory;
  final HealthVaultCategoryScore profileCategory;
  final HealthVaultCategoryScore consultationsCategory;
  final HealthVaultCategoryScore reportsCategory;
  final HealthVaultCategoryScore? medicinesCategory;

  const HealthVaultScoreModel({
    required this.totalScore,
    required this.vitalsCategory,
    required this.profileCategory,
    required this.consultationsCategory,
    required this.reportsCategory,
    this.medicinesCategory,
  });

  List<HealthVaultCategoryScore> get categories => [
    vitalsCategory,
    profileCategory,
    consultationsCategory,
    reportsCategory,
  ];

  Map<String, dynamic> toJson() => {
    'total_score': totalScore,
    'vitals_category': vitalsCategory.toJson(),
    'profile_category': profileCategory.toJson(),
    'consultations_category': consultationsCategory.toJson(),
    'reports_category': reportsCategory.toJson(),
    if (medicinesCategory != null)
      'medicines_category': medicinesCategory!.toJson(),
  };

  factory HealthVaultScoreModel.fromJson(Map<String, dynamic> json) {
    final vitals = HealthVaultCategoryScore.fromJson(
      (json['vitals_category'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final profile = HealthVaultCategoryScore.fromJson(
      (json['profile_category'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final consultations = HealthVaultCategoryScore.fromJson(
      (json['consultations_category'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final reports = HealthVaultCategoryScore.fromJson(
      (json['reports_category'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    HealthVaultCategoryScore? medicines;
    if (json['medicines_category'] != null) {
      medicines = HealthVaultCategoryScore.fromJson(
        (json['medicines_category'] as Map).cast<String, dynamic>(),
      );
    }

    final total =
        json['total_score'] as int? ??
        (vitals.score + profile.score + consultations.score + reports.score)
            .round();

    return HealthVaultScoreModel(
      totalScore: total.clamp(0, 100),
      vitalsCategory: vitals,
      profileCategory: profile,
      consultationsCategory: consultations,
      reportsCategory: reports,
      medicinesCategory: medicines,
    );
  }
}
