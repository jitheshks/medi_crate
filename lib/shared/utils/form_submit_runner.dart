import 'package:flutter/material.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/extensions/build_context_extensions.dart';

/// Lightweight static helper encapsulating form validation pre-check,
/// loading lifecycle toggle, duplicate submission guarding, and mounted-guarded exception handling.
class FormSubmitRunner {
  static final Set<Object> _activeSubmissions = <Object>{};

  /// Executes an async submission [action] within a standard try-finally lifecycle.
  ///
  /// Evaluates [formKey] validation first. If invalid, aborts immediately.
  /// Prevents concurrent/duplicate submissions on rapid double taps.
  /// Otherwise toggles [setLoading], executes [action], catches exceptions for UI feedback,
  /// and guarantees [setLoading] is reset in the finally block.
  static Future<T?> run<T>({
    required BuildContext context,
    required bool Function() isMounted,
    required void Function(bool isLoading) setLoading,
    required Future<T> Function() action,
    GlobalKey<FormState>? formKey,
    void Function(T result)? onSuccess,
    void Function(Object error)? onError,
    String? defaultErrorMessage,
  }) async {
    final lockKey = formKey ?? context;
    if (_activeSubmissions.contains(lockKey)) {
      return null;
    }

    if (formKey != null && !(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    _activeSubmissions.add(lockKey);
    setLoading(true);

    try {
      final result = await action();
      if (isMounted()) {
        onSuccess?.call(result);
      }
      return result;
    } on AppException catch (e) {
      if (isMounted()) {
        if (onError != null) {
          onError(e);
        } else if (context.mounted) {
          context.showErrorSnackBar(e.userFriendlyMessage);
        }
      }
      return null;
    } catch (e) {
      if (isMounted()) {
        if (onError != null) {
          onError(e);
        } else if (context.mounted) {
          context.showErrorSnackBar(
            defaultErrorMessage ?? "Couldn't save changes. Please try again.",
          );
        }
      }
      return null;
    } finally {
      _activeSubmissions.remove(lockKey);
      if (isMounted()) {
        setLoading(false);
      }
    }
  }
}
