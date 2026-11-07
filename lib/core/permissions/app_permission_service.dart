import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_radius.dart';
import '../constants/app_typography.dart';
import '../extensions/build_context_extensions.dart';

/// AppPermissionService coordinates contextual runtime permissions with user-friendly
/// recovery flows and settings redirection using permission_handler.
class AppPermissionService {
  /// Contextually requests Camera permission with denied / permanently denied handling.
  static Future<bool> requestCameraPermission(
    BuildContext context, {
    String featureName = 'take a profile photo',
  }) async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.camera.status;

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          return await showPermanentlyDeniedDialog(
            context,
            title: 'Camera Permission Required',
            message:
                'Camera access is currently disabled for MediCrate. Please enable camera permission in your device settings to $featureName.',
            permission: Permission.camera,
          );
        }
        return false;
      }

      if (status.isRestricted) {
        if (context.mounted) {
          _showRestrictedSnackbar(
            context,
            'Camera access is restricted on this device.',
          );
        }
        return false;
      }

      // Request permission from system
      final requestResult = await Permission.camera.request();

      if (requestResult.isGranted || requestResult.isLimited) {
        return true;
      }

      if (requestResult.isPermanentlyDenied) {
        if (context.mounted) {
          return await showPermanentlyDeniedDialog(
            context,
            title: 'Camera Permission Required',
            message:
                'Camera access is currently disabled for MediCrate. Please enable camera permission in your device settings to $featureName.',
            permission: Permission.camera,
          );
        }
        return false;
      }

      // Denied once (not permanently)
      if (context.mounted) {
        _showDeniedSnackbar(
          context,
          'Camera permission is required to $featureName.',
          onTryAgain: () =>
              requestCameraPermission(context, featureName: featureName),
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Contextually checks Photos / Gallery permission where required by the OS.
  static Future<bool> requestPhotoPermission(
    BuildContext context, {
    String featureName = 'select a profile photo',
  }) async {
    if (kIsWeb) return true;

    // Modern Android (API 33+) uses Android Photo Picker which requires no storage permissions.
    if (Platform.isAndroid) {
      return true;
    }

    if (Platform.isIOS) {
      try {
        final status = await Permission.photos.status;
        if (status.isGranted || status.isLimited) {
          return true;
        }

        if (status.isPermanentlyDenied) {
          if (context.mounted) {
            return await showPermanentlyDeniedDialog(
              context,
              title: 'Photo Library Permission Required',
              message:
                  'Photo library access is currently disabled for MediCrate. Please enable photo access in your device settings to $featureName.',
              permission: Permission.photos,
            );
          }
          return false;
        }

        final requestResult = await Permission.photos.request();
        if (requestResult.isGranted || requestResult.isLimited) {
          return true;
        }

        if (requestResult.isPermanentlyDenied) {
          if (context.mounted) {
            return await showPermanentlyDeniedDialog(
              context,
              title: 'Photo Library Permission Required',
              message:
                  'Photo library access is currently disabled for MediCrate. Please enable photo access in your device settings to $featureName.',
              permission: Permission.photos,
            );
          }
          return false;
        }

        if (context.mounted) {
          _showDeniedSnackbar(
            context,
            'Photo library access is required to $featureName.',
            onTryAgain: () =>
                requestPhotoPermission(context, featureName: featureName),
          );
        }
        return false;
      } catch (_) {
        return true;
      }
    }

    return true;
  }

  /// Displays an honest, theme-consistent dialog directing the user to device settings.
  static Future<bool> showPermanentlyDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
    required Permission permission,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.settings_outlined, color: colorScheme.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      await openAppSettings();
      // Re-check permission status upon returning from Settings
      final updatedStatus = await permission.status;
      return updatedStatus.isGranted || updatedStatus.isLimited;
    }

    return false;
  }

  static void _showDeniedSnackbar(
    BuildContext context,
    String message, {
    required VoidCallback onTryAgain,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    context.showSnackBar(
      message,
      action: SnackBarAction(
        label: 'Try Again',
        textColor: colorScheme.primary,
        onPressed: onTryAgain,
      ),
    );
  }

  static void _showRestrictedSnackbar(BuildContext context, String message) {
    context.showSnackBar(message);
  }
}
