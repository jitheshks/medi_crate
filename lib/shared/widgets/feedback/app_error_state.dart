import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/exceptions/app_exception.dart';

/// AppErrorState provides a standardized, category-aware M3 error card with retry action.
class AppErrorState extends StatelessWidget {
  final String? message;
  final String? title;
  final Object? error;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    this.message,
    this.title,
    this.error,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine error categorization
    final appEx = error is AppException ? error as AppException : null;

    final isOffline =
        appEx?.isNetworkError == true ||
        (error?.toString().toLowerCase().contains('network') ?? false) ||
        (error?.toString().toLowerCase().contains('socket') ?? false) ||
        (error?.toString().toLowerCase().contains('connection') ?? false);

    final isFeatureUnavailable =
        appEx?.isFeatureUnavailable == true ||
        (error?.toString().toLowerCase().contains('not yet implemented') ??
            false) ||
        (error?.toString().toLowerCase().contains('unavailable') ?? false);

    final isForbidden =
        appEx?.isForbidden == true ||
        (error?.toString().toLowerCase().contains('permission') ?? false);

    final isNotFound = appEx?.isNotFound == true;
    final isRateLimited = appEx?.isRateLimited == true;
    final isServerError = appEx?.isServerError == true;

    // Pick icon, title, and message
    IconData icon;
    String displayTitle;
    String displayMessage;
    Color containerColor;
    Color iconColor;
    Color textColor;
    Color buttonColor;

    Color onButtonColor;

    if (isFeatureUnavailable) {
      icon = Icons.construction_outlined;
      displayTitle = title ?? 'Feature Coming Soon';
      displayMessage = message ?? 'This module is currently being integrated and will be available in an upcoming update.';
      containerColor = colorScheme.secondaryContainer.withValues(alpha: 0.5);
      iconColor = colorScheme.secondary;
      textColor = colorScheme.onSecondaryContainer;
      buttonColor = colorScheme.secondary;
      onButtonColor = colorScheme.onSecondary;
    } else if (isOffline) {
      icon = Icons.wifi_off_rounded;
      displayTitle = title ?? 'Connection Error';
      displayMessage =
          message ??
          (appEx?.userFriendlyMessage ??
              'Unable to connect to MediCrate servers. Please check your internet connection and try again.');
      containerColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      buttonColor = colorScheme.error;
      onButtonColor = colorScheme.onError;
    } else if (isForbidden) {
      icon = Icons.lock_outline_rounded;
      displayTitle = title ?? 'Access Restricted';
      displayMessage =
          message ??
          (appEx?.userFriendlyMessage ??
              'You do not have permission to view or modify this resource.');
      containerColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      buttonColor = colorScheme.error;
      onButtonColor = colorScheme.onError;
    } else if (isNotFound) {
      icon = Icons.search_off_rounded;
      displayTitle = title ?? 'Record Not Found';
      displayMessage =
          message ??
          (appEx?.userFriendlyMessage ??
              'The requested record or resource could not be found.');
      containerColor = colorScheme.surfaceContainerHighest;
      iconColor = colorScheme.onSurfaceVariant;
      textColor = colorScheme.onSurface;
      buttonColor = colorScheme.primary;
      onButtonColor = colorScheme.onPrimary;
    } else if (isRateLimited) {
      icon = Icons.timer_outlined;
      displayTitle = title ?? 'Too Many Requests';
      displayMessage =
          message ??
          (appEx?.userFriendlyMessage ??
              'Too many requests. Please wait a moment before trying again.');
      containerColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      buttonColor = colorScheme.error;
      onButtonColor = colorScheme.onError;
    } else if (isServerError) {
      icon = Icons.dns_outlined;
      displayTitle = title ?? 'Server Error';
      displayMessage =
          message ??
          (appEx?.userFriendlyMessage ??
              'MediCrate servers encountered an error. Please try again shortly.');
      containerColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      buttonColor = colorScheme.error;
      onButtonColor = colorScheme.onError;
    } else {
      icon = Icons.error_outline_rounded;
      displayTitle = title ?? 'Unable to Load Data';
      displayMessage =
          message ??
          (appEx?.userFriendlyMessage ??
              (error != null
                  ? _cleanErrorMessage(error.toString())
                  : 'An unexpected error occurred. Please try again.'));
      containerColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      buttonColor = colorScheme.error;
      onButtonColor = colorScheme.onError;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                displayTitle,
                style: AppTypography.h3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                displayMessage,
                style: AppTypography.bodyMedium.copyWith(
                  color: textColor.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(retryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: onButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _cleanErrorMessage(String raw) {
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }
}
