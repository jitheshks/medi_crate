import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// OAuthDeletionRequestDialog informs OAuth users (Google / Apple) about the deletion
/// request process and opens the official Google Form.
class OAuthDeletionRequestDialog extends StatelessWidget {
  final String? email;

  const OAuthDeletionRequestDialog({super.key, this.email});

  static const String deletionFormUrl = 'https://forms.gle/HbJrx6VgYCxL2afcA';

  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  static Future<void> show(BuildContext context, {String? email}) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return;
    _lastOpenTime = now;
    await showDialog(
      context: context,
      builder: (context) => OAuthDeletionRequestDialog(email: email),
    );
  }

  @visibleForTesting
  static void reset() {
    _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _openForm(BuildContext context) async {
    final uri = Uri.parse(OAuthDeletionRequestDialog.deletionFormUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        context.showSnackBar(
          'Could not open deletion request form. Please visit: ${OAuthDeletionRequestDialog.deletionFormUrl}',
        );
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar(
          'Could not open deletion request form. Please visit: ${OAuthDeletionRequestDialog.deletionFormUrl}',
        );
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        Navigator.pop(context);
        context.go(AppRoutes.welcome);
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar('Failed to sign out. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userEmail = email?.trim();

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Request Account Deletion',
              style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Because your account is authenticated with Google or Apple, account deletion requests are submitted securely through our account deletion form.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (userEmail != null && userEmail.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Email',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Important Notes:',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• Opening the request form will not delete your account immediately.\n'
              '• An administrator will process your request and permanently delete your server data and associated records.\n'
              '• You can continue using MediCrate until your request is completed, or choose to sign out now.',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _handleSignOut(context),
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          child: const Text('Sign Out'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open Request Form'),
          onPressed: () => _openForm(context),
        ),
      ],
    );
  }
}
