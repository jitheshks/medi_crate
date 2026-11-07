import '../../../../core/constants/app_icons.dart';
import '../../../profile/data/models/profile_model.dart';
import '../models/health_insight_recommendation.dart';
import '../models/health_vault_score_model.dart';

/// Pure calculator for Health Vault Score and Actionable Recommendations.
class HealthVaultScoreCalculator {
  static HealthVaultScoreModel computeHealthVaultScore({
    required ProfileModel profile,
    required List<Map<String, dynamic>> measurements,
    required List<Map<String, dynamic>> medicines,
    required List<Map<String, dynamic>> consultations,
    required List<Map<String, dynamic>> reports,
  }) {
    final now = DateTime.now();

    // --------------------------------------------------
    // VITALS — 40 POINTS
    // --------------------------------------------------
    final vitalCategories = [
      'blood_pressure',
      'blood_glucose',
      'heart_rate',
      'spo2',
      'temperature',
      'bmi',
      'respiratory_rate',
    ];

    int freshVitalTypeCount = 0;

    for (final vCat in vitalCategories) {
      final matches = measurements.where((m) {
        final type = m['type']?.toString().toLowerCase() ?? '';
        final matchesType =
            (type == vCat) ||
            (vCat == 'blood_glucose' && type == 'glucose') ||
            (vCat == 'spo2' && type == 'oximeter') ||
            (vCat == 'respiratory_rate' && type == 'respiration');
        if (!matchesType) return false;

        final rawDate = m['recorded_at'] ?? m['created_at'] ?? m['date'];
        if (rawDate == null) return true;
        final parsed = DateTime.tryParse(rawDate.toString());
        if (parsed == null) return true;

        return now.difference(parsed).inDays <= 365;
      });

      if (matches.isNotEmpty) {
        freshVitalTypeCount++;
      }
    }

    final double vitalsPoints = (freshVitalTypeCount / 7.0) * 40.0;
    final vitalsCat = HealthVaultCategoryScore(
      name: 'Vitals',
      score: vitalsPoints,
      maxScore: 40,
      isComplete: freshVitalTypeCount == 7,
      statusDetail:
          '$freshVitalTypeCount of 7 vital categories recorded in the last 365 days',
    );

    // --------------------------------------------------
    // PROFILE — 20 POINTS
    // --------------------------------------------------
    int completedProfileFields = 0;

    if (profile.bloodGroup != null && profile.bloodGroup!.trim().isNotEmpty) {
      completedProfileFields++;
    }

    final hasHeightMeasurement = measurements.any(
      (m) =>
          m['type']?.toString().toLowerCase() == 'height' ||
          m['type']?.toString().toLowerCase() == 'height_cm',
    );
    if ((profile.height != null && profile.height! > 0) ||
        hasHeightMeasurement) {
      completedProfileFields++;
    }

    final hasWeightMeasurement = measurements.any(
      (m) => m['type']?.toString().toLowerCase() == 'weight',
    );
    if ((profile.weight != null && profile.weight! > 0) ||
        hasWeightMeasurement) {
      completedProfileFields++;
    }

    final hasAllergiesData =
        profile.allergies.isNotEmpty || profile.allergiesConfirmedNone;
    if (hasAllergiesData) {
      completedProfileFields++;
    }

    final hasConditionsData =
        profile.chronicConditions.isNotEmpty ||
        profile.chronicConditionsConfirmedNone;
    if (hasConditionsData) {
      completedProfileFields++;
    }

    final double profilePoints = (completedProfileFields / 5.0) * 20.0;
    final profileCat = HealthVaultCategoryScore(
      name: 'Profile',
      score: profilePoints,
      maxScore: 20,
      isComplete: completedProfileFields == 5,
      statusDetail: '$completedProfileFields of 5 profile categories completed',
    );

    // --------------------------------------------------
    // CONSULTATION — 20 POINTS
    // --------------------------------------------------
    bool hasFreshConsultation = false;
    for (final c in consultations) {
      final rawDate =
          c['visit_date'] ?? c['visitDate'] ?? c['created_at'] ?? c['date'];
      if (rawDate == null) {
        hasFreshConsultation = true;
        break;
      }
      final parsed = DateTime.tryParse(rawDate.toString());
      if (parsed == null || now.difference(parsed).inDays <= 365) {
        hasFreshConsultation = true;
        break;
      }
    }

    final double consultationPoints = hasFreshConsultation ? 20.0 : 0.0;
    final consultationsCat = HealthVaultCategoryScore(
      name: 'Consultations',
      score: consultationPoints,
      maxScore: 20,
      isComplete: hasFreshConsultation,
      statusDetail: hasFreshConsultation
          ? 'Recent consultation recorded'
          : 'No consultation recorded within the last 365 days',
    );

    // --------------------------------------------------
    // REPORT — 20 POINTS
    // --------------------------------------------------
    bool hasFreshReport = false;
    for (final r in reports) {
      final rawDate = r['date'] ?? r['created_at'] ?? r['uploaded_at'];
      if (rawDate == null) {
        hasFreshReport = true;
        break;
      }
      final parsed = DateTime.tryParse(rawDate.toString());
      if (parsed == null || now.difference(parsed).inDays <= 365) {
        hasFreshReport = true;
        break;
      }
    }

    final double reportPoints = hasFreshReport ? 20.0 : 0.0;
    final reportsCat = HealthVaultCategoryScore(
      name: 'Reports',
      score: reportPoints,
      maxScore: 20,
      isComplete: hasFreshReport,
      statusDetail: hasFreshReport
          ? 'Recent report recorded'
          : 'No report recorded within the last 365 days',
    );

    final int totalScore =
        (vitalsPoints + profilePoints + consultationPoints + reportPoints)
            .round()
            .clamp(0, 100);

    return HealthVaultScoreModel(
      totalScore: totalScore,
      vitalsCategory: vitalsCat,
      profileCategory: profileCat,
      consultationsCategory: consultationsCat,
      reportsCategory: reportsCat,
    );
  }

  static List<HealthInsightRecommendation> generateRecommendations({
    required String profileId,
    required String profileName,
    required HealthVaultScoreModel vaultScore,
    required List<Map<String, dynamic>> measurements,
    required List<Map<String, dynamic>> consultations,
  }) {
    final recommendations = <HealthInsightRecommendation>[];

    if (!vaultScore.profileCategory.isComplete) {
      recommendations.add(
        HealthInsightRecommendation(
          id: 'rec_vault_profile_$profileId',
          title: 'Complete your personal health profile',
          description:
              'Fill in blood group, height, weight, and allergy or condition status to complete your profile.',
          actionLabel: 'Complete Profile',
          targetRoute: '/profiles',
          icon: AppIcons.userCheck,
        ),
      );
    }

    if (!vaultScore.vitalsCategory.isComplete) {
      recommendations.add(
        HealthInsightRecommendation(
          id: 'rec_vault_vitals_$profileId',
          title: 'Add recent vital measurements',
          description: 'Record missing vital categories.',
          actionLabel: 'Log Vitals',
          targetRoute: '/measurements',
          icon: AppIcons.activity,
        ),
      );
    }

    if (!vaultScore.consultationsCategory.isComplete) {
      recommendations.add(
        HealthInsightRecommendation(
          id: 'rec_vault_consultations_$profileId',
          title: 'Add a recent consultation',
          description:
              "No consultation has been recorded within the score's freshness window.",
          actionLabel: 'Add Consultation',
          targetRoute: '/consultations',
          icon: AppIcons.calendar,
        ),
      );
    }

    if (!vaultScore.reportsCategory.isComplete) {
      recommendations.add(
        HealthInsightRecommendation(
          id: 'rec_vault_reports_$profileId',
          title: 'Add a recent report',
          description:
              "No report has been recorded within the score's freshness window.",
          actionLabel: 'Add Report',
          targetRoute: '/reports',
          icon: AppIcons.fileText,
        ),
      );
    }

    return recommendations;
  }
}
