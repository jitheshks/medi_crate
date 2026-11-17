import 'package:material_ui/material_ui.dart';

/// AppColors encapsulates all tokenized and inline hex colors defined in
/// Theme_Design_System.md (v1.0).
abstract class AppColors {
  // Tokenized Variables (Light Theme)
  static const Color ink = Color(0xFF12151A);
  static const Color mutedForeground = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);
  static const Color background = Color(0xFFF7F8FA);
  static const Color card = Color(0xFFFFFFFF);

  // Brand Primary (Navy)
  static const Color primary = Color(0xFF123C61);
  static const Color primaryPressed = Color(0xFF0D2C48);

  // Interactive & Badges
  static const Color link = Color(0xFF1D5FC2);
  static const Color infoContainer = Color(0xFFE7EEF5);
  static const Color onInfoContainer = Color(0xFF1D3A5C);

  // Offline / Warning Banner
  static const Color warningContainer = Color(0xFFFDF1DC);
  static const Color warningBorder = Color(0xFFF3C989);
  static const Color onWarningContainer = Color(0xFF8A5A11);

  // Error & Destructive
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFDEDEC);

  // Success & Synced
  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFEAFBF2);
  static const Color syncedDot = Color(0xFF5EE7A0);

  // Module Specific Inline Accents (Tokenized for reuse)
  static const Color hospitalAccent = Color(0xFF1B7A3D);
  static const Color hospitalAccentContainer = Color(0xFFEAF6EE);

  static const Color medicineAccent = Color(0xFF9A5B12);
  static const Color medicineAccentContainer = Color(0xFFFBEFE0);

  static const Color departmentAccent = Color(0xFF6B3FA0);
  static const Color departmentAccentContainer = Color(0xFFF1E9FB);

  static const Color vitalHeartRate = Color(0xFF8A2E4A);
  static const Color vitalHeartRateContainer = Color(0xFFFBE8EE);

  static const Color vitalTemperature = Color(0xFFB45309);
  static const Color vitalTemperatureContainer = Color(0xFFFEF3E2);

  static const Color vitalWeight = Color(0xFF3B4B5C);
  static const Color vitalWeightContainer = Color(0xFFEAEEF2);

  static const Color favoriteStar = Color(0xFFF5A524);
  static const Color inverseSurface = Color(0xFF14171B);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF123C61), Color(0xFF1D5FA6)],
  );
}
