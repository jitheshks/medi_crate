import 'package:flutter/material.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/theme/app_semantic_colors.dart';

class VitalTrendStyleHelper {
  static double parseNumericValue(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  static Color getStatusColor(String status, BuildContext context) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    switch (status.toUpperCase()) {
      case 'ELEVATED':
      case 'HIGH':
      case 'WARNING':
        return semantic.vitalTemperature;
      case 'CRITICAL':
        return colorScheme.error;
      case 'OPTIMAL':
      case 'NORMAL':
      case 'STABLE':
      default:
        return semantic.success;
    }
  }

  static Color getVitalIconColor(String type, BuildContext context) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    switch (type.toLowerCase()) {
      case 'blood_pressure':
        return semantic.vitalBloodPressure;
      case 'blood_glucose':
      case 'glucose':
        return semantic.vitalBloodGlucose;
      case 'heart_rate':
        return semantic.vitalHeartRate;
      case 'spo2':
        return semantic.vitalSpo2;
      case 'temperature':
        return semantic.vitalTemperature;
      case 'bmi':
        return semantic.vitalBmi;
      case 'respiratory_rate':
        return semantic.vitalRespiratory;
      default:
        return colorScheme.primary;
    }
  }

  static IconData getVitalIcon(String type) {
    switch (type.toLowerCase()) {
      case 'blood_pressure':
        return AppIcons.activity;
      case 'blood_glucose':
      case 'glucose':
        return Icons.water_drop_outlined;
      case 'heart_rate':
        return AppIcons.heart;
      case 'spo2':
        return AppIcons.shield;
      case 'temperature':
        return Icons.thermostat_outlined;
      case 'bmi':
        return Icons.scale_outlined;
      case 'respiratory_rate':
        return Icons.air_outlined;
      default:
        return AppIcons.activity;
    }
  }
}
