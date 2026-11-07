import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_colors_dark.dart';

/// AppSemanticColors provides design-system semantic color tokens
/// that adapt automatically to light and dark themes via Flutter's [ThemeExtension].
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.warningContainer,
    required this.warningBorder,
    required this.onWarningContainer,
    required this.success,
    required this.successContainer,
    required this.hospitalAccent,
    required this.hospitalAccentContainer,
    required this.medicineAccent,
    required this.medicineAccentContainer,
    required this.departmentAccent,
    required this.departmentAccentContainer,
    required this.vitalBloodPressure,
    required this.vitalBloodPressureContainer,
    required this.vitalBloodGlucose,
    required this.vitalBloodGlucoseContainer,
    required this.vitalHeartRate,
    required this.vitalHeartRateContainer,
    required this.vitalSpo2,
    required this.vitalSpo2Container,
    required this.vitalTemperature,
    required this.vitalTemperatureContainer,
    required this.vitalWeight,
    required this.vitalWeightContainer,
    required this.vitalBmi,
    required this.vitalBmiContainer,
    required this.vitalRespiratory,
    required this.vitalRespiratoryContainer,
    required this.statusCritical,
    required this.statusCriticalContainer,
    required this.statusWarning,
    required this.statusWarningContainer,
    required this.statusInfo,
    required this.statusInfoContainer,
    required this.statusNeutral,
    required this.statusNeutralContainer,
    required this.favoriteStar,
    required this.syncedDot,
    required this.inverseSurface,
    required this.relationshipMother,
    required this.relationshipSpouse,
    required this.relationshipChild,
    required this.relationshipGrandparent,
  });

  final Color warningContainer;
  final Color warningBorder;
  final Color onWarningContainer;
  final Color success;
  final Color successContainer;
  final Color hospitalAccent;
  final Color hospitalAccentContainer;
  final Color medicineAccent;
  final Color medicineAccentContainer;
  final Color departmentAccent;
  final Color departmentAccentContainer;
  final Color vitalBloodPressure;
  final Color vitalBloodPressureContainer;
  final Color vitalBloodGlucose;
  final Color vitalBloodGlucoseContainer;
  final Color vitalHeartRate;
  final Color vitalHeartRateContainer;
  final Color vitalSpo2;
  final Color vitalSpo2Container;
  final Color vitalTemperature;
  final Color vitalTemperatureContainer;
  final Color vitalWeight;
  final Color vitalWeightContainer;
  final Color vitalBmi;
  final Color vitalBmiContainer;
  final Color vitalRespiratory;
  final Color vitalRespiratoryContainer;
  final Color statusCritical;
  final Color statusCriticalContainer;
  final Color statusWarning;
  final Color statusWarningContainer;
  final Color statusInfo;
  final Color statusInfoContainer;
  final Color statusNeutral;
  final Color statusNeutralContainer;
  final Color favoriteStar;
  final Color syncedDot;
  final Color inverseSurface;
  final Color relationshipMother;
  final Color relationshipSpouse;
  final Color relationshipChild;
  final Color relationshipGrandparent;

  /// Light theme semantic color definition.
  static const AppSemanticColors light = AppSemanticColors(
    warningContainer: AppColors.warningContainer,
    warningBorder: AppColors.warningBorder,
    onWarningContainer: AppColors.onWarningContainer,
    success: AppColors.success,
    successContainer: AppColors.successContainer,
    hospitalAccent: AppColors.hospitalAccent,
    hospitalAccentContainer: AppColors.hospitalAccentContainer,
    medicineAccent: AppColors.medicineAccent,
    medicineAccentContainer: AppColors.medicineAccentContainer,
    departmentAccent: AppColors.departmentAccent,
    departmentAccentContainer: AppColors.departmentAccentContainer,
    vitalBloodPressure: Color(0xFF1E3A8A),
    vitalBloodPressureContainer: Color(0xFFEBF3FB),
    vitalBloodGlucose: Color(0xFFD97706),
    vitalBloodGlucoseContainer: Color(0xFFFFF4E5),
    vitalHeartRate: Color(0xFFDB2777),
    vitalHeartRateContainer: Color(0xFFFDF2F8),
    vitalSpo2: Color(0xFF059669),
    vitalSpo2Container: Color(0xFFECFDF5),
    vitalTemperature: AppColors.vitalTemperature,
    vitalTemperatureContainer: AppColors.vitalTemperatureContainer,
    vitalWeight: AppColors.vitalWeight,
    vitalWeightContainer: AppColors.vitalWeightContainer,
    vitalBmi: Color(0xFF475569),
    vitalBmiContainer: Color(0xFFF1F5F9),
    vitalRespiratory: Color(0xFF7B1FA2),
    vitalRespiratoryContainer: Color(0xFFF3E5F5),
    statusCritical: Color(0xFFB91C1C),
    statusCriticalContainer: Color(0xFFFEE2E2),
    statusWarning: Color(0xFFD97706),
    statusWarningContainer: Color(0xFFFEF3C7),
    statusInfo: Color(0xFF1D4ED8),
    statusInfoContainer: Color(0xFFEFF6FF),
    statusNeutral: Color(0xFF64748B),
    statusNeutralContainer: Color(0xFFF1F5F9),
    favoriteStar: AppColors.favoriteStar,
    syncedDot: AppColors.syncedDot,
    inverseSurface: AppColors.inverseSurface,
    relationshipMother: Color(0xFFD946EF),
    relationshipSpouse: Color(0xFFEC4899),
    relationshipChild: Color(0xFF0EA5E9),
    relationshipGrandparent: Color(0xFF8B5CF6),
  );

  /// Dark theme semantic color definition.
  static const AppSemanticColors dark = AppSemanticColors(
    warningContainer: AppColorsDark.offlineContainer,
    warningBorder: AppColorsDark.offlineBorder,
    onWarningContainer: AppColorsDark.onOfflineContainer,
    success: AppColorsDark.success,
    successContainer: AppColorsDark.successContainer,
    hospitalAccent: AppColorsDark.hospitalAccent,
    hospitalAccentContainer: AppColorsDark.hospitalAccentContainer,
    medicineAccent: AppColorsDark.medicineAccent,
    medicineAccentContainer: AppColorsDark.medicineAccentContainer,
    departmentAccent: AppColorsDark.departmentAccent,
    departmentAccentContainer: AppColorsDark.departmentAccentContainer,
    vitalBloodPressure: Color(0xFF7EB6E8),
    vitalBloodPressureContainer: Color(0xFF1E3A54),
    vitalBloodGlucose: Color(0xFFF59E0B),
    vitalBloodGlucoseContainer: Color(0xFF3A2E12),
    vitalHeartRate: Color(0xFFFF6B5E),
    vitalHeartRateContainer: Color(0xFF3D1815),
    vitalSpo2: Color(0xFF4ADE80),
    vitalSpo2Container: Color(0xFF0F2E1C),
    vitalTemperature: AppColorsDark.vitalTemperature,
    vitalTemperatureContainer: AppColorsDark.vitalTemperatureContainer,
    vitalWeight: AppColorsDark.vitalWeight,
    vitalWeightContainer: AppColorsDark.vitalWeightContainer,
    vitalBmi: Color(0xFF9AA7B5),
    vitalBmiContainer: Color(0xFF1C2733),
    vitalRespiratory: Color(0xFFA855F7),
    vitalRespiratoryContainer: Color(0xFF2E1065),
    statusCritical: Color(0xFFFF6B5E),
    statusCriticalContainer: Color(0xFF3D1815),
    statusWarning: Color(0xFFF3C989),
    statusWarningContainer: Color(0xFF3A2E12),
    statusInfo: Color(0xFF7EB6E8),
    statusInfoContainer: Color(0xFF1E3A54),
    statusNeutral: Color(0xFF9AA7B5),
    statusNeutralContainer: Color(0xFF1C2733),
    favoriteStar: AppColorsDark.favoriteStar,
    syncedDot: AppColorsDark.syncedDot,
    inverseSurface: AppColorsDark.inverseSurface,
    relationshipMother: Color(0xFFE879F9),
    relationshipSpouse: Color(0xFFF472B6),
    relationshipChild: Color(0xFF38BDF8),
    relationshipGrandparent: Color(0xFFA78BFA),
  );

  /// Retrieves the current [AppSemanticColors] from the given [BuildContext].
  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>() ?? light;
  }

  @override
  ThemeExtension<AppSemanticColors> copyWith({
    Color? warningContainer,
    Color? warningBorder,
    Color? onWarningContainer,
    Color? success,
    Color? successContainer,
    Color? hospitalAccent,
    Color? hospitalAccentContainer,
    Color? medicineAccent,
    Color? medicineAccentContainer,
    Color? departmentAccent,
    Color? departmentAccentContainer,
    Color? vitalBloodPressure,
    Color? vitalBloodPressureContainer,
    Color? vitalBloodGlucose,
    Color? vitalBloodGlucoseContainer,
    Color? vitalHeartRate,
    Color? vitalHeartRateContainer,
    Color? vitalSpo2,
    Color? vitalSpo2Container,
    Color? vitalTemperature,
    Color? vitalTemperatureContainer,
    Color? vitalWeight,
    Color? vitalWeightContainer,
    Color? vitalBmi,
    Color? vitalBmiContainer,
    Color? vitalRespiratory,
    Color? vitalRespiratoryContainer,
    Color? statusCritical,
    Color? statusCriticalContainer,
    Color? statusWarning,
    Color? statusWarningContainer,
    Color? statusInfo,
    Color? statusInfoContainer,
    Color? statusNeutral,
    Color? statusNeutralContainer,
    Color? favoriteStar,
    Color? syncedDot,
    Color? inverseSurface,
    Color? relationshipMother,
    Color? relationshipSpouse,
    Color? relationshipChild,
    Color? relationshipGrandparent,
  }) {
    return AppSemanticColors(
      warningContainer: warningContainer ?? this.warningContainer,
      warningBorder: warningBorder ?? this.warningBorder,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      hospitalAccent: hospitalAccent ?? this.hospitalAccent,
      hospitalAccentContainer:
          hospitalAccentContainer ?? this.hospitalAccentContainer,
      medicineAccent: medicineAccent ?? this.medicineAccent,
      medicineAccentContainer:
          medicineAccentContainer ?? this.medicineAccentContainer,
      departmentAccent: departmentAccent ?? this.departmentAccent,
      departmentAccentContainer:
          departmentAccentContainer ?? this.departmentAccentContainer,
      vitalBloodPressure: vitalBloodPressure ?? this.vitalBloodPressure,
      vitalBloodPressureContainer:
          vitalBloodPressureContainer ?? this.vitalBloodPressureContainer,
      vitalBloodGlucose: vitalBloodGlucose ?? this.vitalBloodGlucose,
      vitalBloodGlucoseContainer:
          vitalBloodGlucoseContainer ?? this.vitalBloodGlucoseContainer,
      vitalHeartRate: vitalHeartRate ?? this.vitalHeartRate,
      vitalHeartRateContainer:
          vitalHeartRateContainer ?? this.vitalHeartRateContainer,
      vitalSpo2: vitalSpo2 ?? this.vitalSpo2,
      vitalSpo2Container: vitalSpo2Container ?? this.vitalSpo2Container,
      vitalTemperature: vitalTemperature ?? this.vitalTemperature,
      vitalTemperatureContainer:
          vitalTemperatureContainer ?? this.vitalTemperatureContainer,
      vitalWeight: vitalWeight ?? this.vitalWeight,
      vitalWeightContainer: vitalWeightContainer ?? this.vitalWeightContainer,
      vitalBmi: vitalBmi ?? this.vitalBmi,
      vitalBmiContainer: vitalBmiContainer ?? this.vitalBmiContainer,
      vitalRespiratory: vitalRespiratory ?? this.vitalRespiratory,
      vitalRespiratoryContainer:
          vitalRespiratoryContainer ?? this.vitalRespiratoryContainer,
      statusCritical: statusCritical ?? this.statusCritical,
      statusCriticalContainer:
          statusCriticalContainer ?? this.statusCriticalContainer,
      statusWarning: statusWarning ?? this.statusWarning,
      statusWarningContainer:
          statusWarningContainer ?? this.statusWarningContainer,
      statusInfo: statusInfo ?? this.statusInfo,
      statusInfoContainer: statusInfoContainer ?? this.statusInfoContainer,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      statusNeutralContainer:
          statusNeutralContainer ?? this.statusNeutralContainer,
      favoriteStar: favoriteStar ?? this.favoriteStar,
      syncedDot: syncedDot ?? this.syncedDot,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      relationshipMother: relationshipMother ?? this.relationshipMother,
      relationshipSpouse: relationshipSpouse ?? this.relationshipSpouse,
      relationshipChild: relationshipChild ?? this.relationshipChild,
      relationshipGrandparent:
          relationshipGrandparent ?? this.relationshipGrandparent,
    );
  }

  @override
  ThemeExtension<AppSemanticColors> lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }

    return AppSemanticColors(
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      hospitalAccent: Color.lerp(hospitalAccent, other.hospitalAccent, t)!,
      hospitalAccentContainer: Color.lerp(
        hospitalAccentContainer,
        other.hospitalAccentContainer,
        t,
      )!,
      medicineAccent: Color.lerp(medicineAccent, other.medicineAccent, t)!,
      medicineAccentContainer: Color.lerp(
        medicineAccentContainer,
        other.medicineAccentContainer,
        t,
      )!,
      departmentAccent: Color.lerp(
        departmentAccent,
        other.departmentAccent,
        t,
      )!,
      departmentAccentContainer: Color.lerp(
        departmentAccentContainer,
        other.departmentAccentContainer,
        t,
      )!,
      vitalBloodPressure: Color.lerp(
        vitalBloodPressure,
        other.vitalBloodPressure,
        t,
      )!,
      vitalBloodPressureContainer: Color.lerp(
        vitalBloodPressureContainer,
        other.vitalBloodPressureContainer,
        t,
      )!,
      vitalBloodGlucose: Color.lerp(
        vitalBloodGlucose,
        other.vitalBloodGlucose,
        t,
      )!,
      vitalBloodGlucoseContainer: Color.lerp(
        vitalBloodGlucoseContainer,
        other.vitalBloodGlucoseContainer,
        t,
      )!,
      vitalHeartRate: Color.lerp(vitalHeartRate, other.vitalHeartRate, t)!,
      vitalHeartRateContainer: Color.lerp(
        vitalHeartRateContainer,
        other.vitalHeartRateContainer,
        t,
      )!,
      vitalSpo2: Color.lerp(vitalSpo2, other.vitalSpo2, t)!,
      vitalSpo2Container: Color.lerp(
        vitalSpo2Container,
        other.vitalSpo2Container,
        t,
      )!,
      vitalTemperature: Color.lerp(
        vitalTemperature,
        other.vitalTemperature,
        t,
      )!,
      vitalTemperatureContainer: Color.lerp(
        vitalTemperatureContainer,
        other.vitalTemperatureContainer,
        t,
      )!,
      vitalWeight: Color.lerp(vitalWeight, other.vitalWeight, t)!,
      vitalWeightContainer: Color.lerp(
        vitalWeightContainer,
        other.vitalWeightContainer,
        t,
      )!,
      vitalBmi: Color.lerp(vitalBmi, other.vitalBmi, t)!,
      vitalBmiContainer: Color.lerp(
        vitalBmiContainer,
        other.vitalBmiContainer,
        t,
      )!,
      vitalRespiratory: Color.lerp(
        vitalRespiratory,
        other.vitalRespiratory,
        t,
      )!,
      vitalRespiratoryContainer: Color.lerp(
        vitalRespiratoryContainer,
        other.vitalRespiratoryContainer,
        t,
      )!,
      statusCritical: Color.lerp(statusCritical, other.statusCritical, t)!,
      statusCriticalContainer: Color.lerp(
        statusCriticalContainer,
        other.statusCriticalContainer,
        t,
      )!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusWarningContainer: Color.lerp(
        statusWarningContainer,
        other.statusWarningContainer,
        t,
      )!,
      statusInfo: Color.lerp(statusInfo, other.statusInfo, t)!,
      statusInfoContainer: Color.lerp(
        statusInfoContainer,
        other.statusInfoContainer,
        t,
      )!,
      statusNeutral: Color.lerp(statusNeutral, other.statusNeutral, t)!,
      statusNeutralContainer: Color.lerp(
        statusNeutralContainer,
        other.statusNeutralContainer,
        t,
      )!,
      favoriteStar: Color.lerp(favoriteStar, other.favoriteStar, t)!,
      syncedDot: Color.lerp(syncedDot, other.syncedDot, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      relationshipMother: Color.lerp(
        relationshipMother,
        other.relationshipMother,
        t,
      )!,
      relationshipSpouse: Color.lerp(
        relationshipSpouse,
        other.relationshipSpouse,
        t,
      )!,
      relationshipChild: Color.lerp(
        relationshipChild,
        other.relationshipChild,
        t,
      )!,
      relationshipGrandparent: Color.lerp(
        relationshipGrandparent,
        other.relationshipGrandparent,
        t,
      )!,
    );
  }
}

/// Convenience extension on [BuildContext] to access [AppSemanticColors].
extension SemanticColorsBuildContext on BuildContext {
  AppSemanticColors get semanticColors => AppSemanticColors.of(this);
}
