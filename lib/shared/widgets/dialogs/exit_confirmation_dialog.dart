import 'package:flutter/material.dart';

import '../../../core/constants/app_typography.dart';

/// ExitConfirmationDialog displays a standardized confirmation dialog before exiting the app.
class ExitConfirmationDialog extends StatelessWidget {
  const ExitConfirmationDialog({super.key});

  static bool _isDialogOpen = false;

  @visibleForTesting
  static bool get isDialogOpen => _isDialogOpen;

  @visibleForTesting
  static void reset() {
    _isDialogOpen = false;
  }

  /// Displays the confirmation dialog. Returns true if user confirmed exit, false/null otherwise.
  static Future<bool?> show(BuildContext context) async {
    if (_isDialogOpen) return null;
    _isDialogOpen = true;
    try {
      return await showDialog<bool>(
        context: context,
        builder: (ctx) => const ExitConfirmationDialog(),
      );
    } finally {
      _isDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.exit_to_app_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Exit MediCrate',
              style: AppTypography.h2.copyWith(
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to exit the application?',
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Exit'),
        ),
      ],
    );
  }
}
