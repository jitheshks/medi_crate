import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_colors_dark.dart';
import '../constants/app_radius.dart';
import '../constants/app_typography.dart';
import 'app_semantic_colors.dart';

export 'app_semantic_colors.dart';

/// AppTheme builds the ThemeData for Material 3.
/// AppTheme builds the ThemeData for Material 3.
abstract class AppTheme {
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    return TextTheme(
      displayLarge: AppTypography.display.copyWith(color: onSurface),
      displayMedium: AppTypography.display.copyWith(color: onSurface),
      displaySmall: AppTypography.display.copyWith(color: onSurface),
      headlineLarge: AppTypography.h1.copyWith(color: onSurface),
      headlineMedium: AppTypography.h2.copyWith(color: onSurface),
      headlineSmall: AppTypography.h3.copyWith(color: onSurface),
      titleLarge: AppTypography.h2.copyWith(color: onSurface),
      titleMedium: AppTypography.h3.copyWith(color: onSurface),
      titleSmall: AppTypography.subtitle.copyWith(color: onSurfaceVariant),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: onSurface),
      bodySmall: AppTypography.caption.copyWith(color: onSurfaceVariant),
      labelLarge: AppTypography.button.copyWith(color: onSurface),
      labelMedium: AppTypography.labelMedium.copyWith(color: onSurfaceVariant),
      labelSmall: AppTypography.labelSmall.copyWith(color: onSurfaceVariant),
    );
  }

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.infoContainer,
      onPrimaryContainer: AppColors.onInfoContainer,
      secondary: AppColors.link,
      onSecondary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.mutedForeground,
      surfaceContainerLowest: AppColors.card,
      surfaceContainerHigh: AppColors.card,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.error,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        hintStyle: AppTypography.subtitle.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          textStyle: AppTypography.button.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline, width: 1),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          textStyle: AppTypography.button.copyWith(color: colorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: AppTypography.button.copyWith(
            fontSize: 14,
            color: colorScheme.primary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlBorder,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        titleTextStyle: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primary,
        labelStyle: AppTypography.caption.copyWith(
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: AppTypography.caption.copyWith(
          color: colorScheme.onPrimary,
        ),
        side: BorderSide(color: colorScheme.outline, width: 1),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
        showCheckmark: false,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
        checkColor: WidgetStatePropertyAll<Color>(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.surfaceContainerHighest.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline;
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      extensions: const [AppSemanticColors.light],
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColorsDark.primary,
      onPrimary: const Color(0xFF0A2138),
      primaryContainer: AppColorsDark.infoContainer,
      onPrimaryContainer: AppColorsDark.onInfoContainer,
      secondary: AppColorsDark.link,
      onSecondary: const Color(0xFF0A2138),
      surface: AppColorsDark.card,
      onSurface: AppColorsDark.ink,
      onSurfaceVariant: AppColorsDark.mutedForeground,
      surfaceContainerLowest: AppColorsDark.card,
      surfaceContainerHigh: AppColorsDark.surfaceContainerHigh,
      error: AppColorsDark.error,
      onError: const Color(0xFF601410),
      errorContainer: AppColorsDark.errorContainer,
      onErrorContainer: AppColorsDark.error,
      outline: AppColorsDark.border,
      outlineVariant: AppColorsDark.border,
    );

    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColorsDark.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsDark.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        hintStyle: AppTypography.subtitle.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          textStyle: AppTypography.button.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline, width: 1),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          textStyle: AppTypography.button.copyWith(color: colorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: AppTypography.button.copyWith(
            fontSize: 14,
            color: colorScheme.primary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFEDF1F5),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: const Color(0xFF12151A),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlBorder,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        titleTextStyle: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primary,
        labelStyle: AppTypography.caption.copyWith(
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: AppTypography.caption.copyWith(
          color: colorScheme.onPrimary,
        ),
        side: BorderSide(color: colorScheme.outline, width: 1),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
        showCheckmark: false,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
        checkColor: WidgetStatePropertyAll<Color>(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.surfaceContainerHighest.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline;
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      extensions: const [AppSemanticColors.dark],
    );
  }
}
