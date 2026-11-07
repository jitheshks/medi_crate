import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_semantic_colors.dart';

class VitalVisuals {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  VitalVisuals({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class StatusVisuals {
  final Color bgColor;
  final Color textColor;

  StatusVisuals({required this.bgColor, required this.textColor});
}

/// Vital type visual colors and icons matching reference
VitalVisuals getVitalVisuals(BuildContext context, String type) {
  final semantic = context.semanticColors;
  switch (type.toLowerCase()) {
    case 'blood_pressure':
      return VitalVisuals(
        icon: Icons.show_chart,
        bgColor: semantic.vitalBloodPressureContainer,
        iconColor: semantic.vitalBloodPressure,
      );
    case 'blood_glucose':
    case 'glucose':
      return VitalVisuals(
        icon: Icons.water_drop_outlined,
        bgColor: semantic.vitalBloodGlucoseContainer,
        iconColor: semantic.vitalBloodGlucose,
      );
    case 'heart_rate':
      return VitalVisuals(
        icon: Icons.favorite_outline,
        bgColor: semantic.vitalHeartRateContainer,
        iconColor: semantic.vitalHeartRate,
      );
    case 'spo2':
      return VitalVisuals(
        icon: Icons.air,
        bgColor: semantic.vitalSpo2Container,
        iconColor: semantic.vitalSpo2,
      );
    case 'temperature':
      return VitalVisuals(
        icon: Icons.thermostat_outlined,
        bgColor: semantic.vitalTemperatureContainer,
        iconColor: semantic.vitalTemperature,
      );
    case 'bmi':
      return VitalVisuals(
        icon: Icons.monitor_weight_outlined,
        bgColor: semantic.vitalBmiContainer,
        iconColor: semantic.vitalBmi,
      );
    case 'respiratory_rate':
      return VitalVisuals(
        icon: Icons.speed_outlined,
        bgColor: semantic.vitalRespiratoryContainer,
        iconColor: semantic.vitalRespiratory,
      );
    default:
      return VitalVisuals(
        icon: AppIcons.activity,
        bgColor: semantic.vitalBloodPressureContainer,
        iconColor: Theme.of(context).colorScheme.primary,
      );
  }
}

/// Status badge colors using MediVault semantic theme colors
StatusVisuals getStatusVisuals(BuildContext context, String status) {
  final semantic = context.semanticColors;
  final upper = status.toUpperCase();
  if (upper == 'HIGH' ||
      upper == 'CRITICAL' ||
      upper == 'HIGHER REFERENCE RANGE') {
    return StatusVisuals(
      bgColor: semantic.statusCriticalContainer,
      textColor: semantic.statusCritical,
    );
  } else if (upper == 'ELEVATED' ||
      upper == 'WARNING' ||
      upper == 'ABOVE REFERENCE' ||
      upper == 'ABOVE REFERENCE RANGE') {
    return StatusVisuals(
      bgColor: semantic.statusWarningContainer,
      textColor: semantic.statusWarning,
    );
  } else if (upper == 'LOW' ||
      upper == 'DECREASED' ||
      upper == 'BELOW REFERENCE' ||
      upper == 'BELOW REFERENCE RANGE') {
    return StatusVisuals(
      bgColor: semantic.statusInfoContainer,
      textColor: semantic.statusInfo,
    );
  } else if (upper == 'N/A' ||
      upper == 'NOT_APPLICABLE' ||
      upper == 'UNSUPPORTED') {
    return StatusVisuals(
      bgColor: semantic.statusNeutralContainer,
      textColor: semantic.statusNeutral,
    );
  }
  // NORMAL, OPTIMAL, STABLE, NORMAL RANGE
  return StatusVisuals(
    bgColor: semantic.successContainer,
    textColor: semantic.success,
  );
}
