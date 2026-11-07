import 'package:flutter/foundation.dart';

/// AppLogger provides standardized logging across the MediCrate application.
///
/// Features:
/// - Consistent `[MediCrate]` tagging with optional subsystem prefix.
/// - Suppresses verbose debug traces in release builds.
/// - Unified error logging with optional stack trace reporting.
class AppLogger {
  AppLogger._();

  /// Logs a debug message in debug mode only.
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[MediCrate:$tag]' : '[MediCrate]';
      debugPrint('$prefix $message');
    }
  }

  /// Logs an informational message.
  static void info(String message, [String? tag]) {
    final prefix = tag != null ? '[MediCrate:$tag]' : '[MediCrate]';
    debugPrint('$prefix $message');
  }

  /// Logs a warning message.
  static void warning(String message, [String? tag]) {
    final prefix = tag != null ? '[MediCrate:$tag]' : '[MediCrate]';
    debugPrint('$prefix ⚠️ WARNING: $message');
  }

  /// Logs an error message with optional error object and stack trace.
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    final prefix = tag != null ? '[MediCrate:$tag]' : '[MediCrate]';
    debugPrint('$prefix ❌ ERROR: $message');
    if (error != null) {
      debugPrint('$prefix ↳ Cause: $error');
    }
    if (stackTrace != null) {
      debugPrint('$prefix ↳ StackTrace:\n$stackTrace');
    }
  }
}
