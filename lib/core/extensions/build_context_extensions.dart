import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_semantic_colors.dart';

extension BuildContextSnackBarX on BuildContext {
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: duration, action: action),
      );
  }

  void showSuccessSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: semanticColors.success,
          duration: duration,
          action: action,
        ),
      );
  }

  void showErrorSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(this).colorScheme.error,
          duration: duration,
          action: action,
        ),
      );
  }
}

/// Centralized navigation guard preventing rapid duplicate route pushes.
class AppNavigationGuard {
  AppNavigationGuard._();

  static DateTime _lastPushTime = DateTime.fromMillisecondsSinceEpoch(0);
  static String? _lastPushTarget;

  /// Minimum cooldown between identical route pushes.
  static const Duration duplicatePushCooldown = Duration(milliseconds: 500);

  /// Evaluates whether a navigation push to [target] is permitted.
  /// Returns `true` if allowed, `false` if dropped as a duplicate event.
  static bool canPush(String target) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastPushTime);

    // If identical target is pushed within duplicatePushCooldown, ignore.
    if (_lastPushTarget == target && elapsed < duplicatePushCooldown) {
      return false;
    }

    _lastPushTime = now;
    _lastPushTarget = target;
    return true;
  }

  /// Reset internal state (for testing).
  @visibleForTesting
  static void reset() {
    _lastPushTime = DateTime.fromMillisecondsSinceEpoch(0);
    _lastPushTarget = null;
  }
}

extension BuildContextNavigationX on BuildContext {
  /// Pushes a location with duplicate-tap prevention.
  Future<T?> pushGuarded<T extends Object?>(String location, {Object? extra}) {
    if (!AppNavigationGuard.canPush(location)) {
      return Future.value(null);
    }
    return push<T>(location, extra: extra);
  }

  void popOrGo(String location, [Object? extra]) {
    if (canPop()) {
      pop(extra);
    } else {
      go(location, extra: extra);
    }
  }
}
