import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// DeleteAccountDialog forces typing "DELETE" and entering current password to confirm account deletion (B5).
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  static Future<void> show(BuildContext context) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return;
    _lastOpenTime = now;
    await showDialog(
      context: context,
      builder: (context) => const DeleteAccountDialog(),
    );
  }

  @visibleForTesting
  static void reset() {
    _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _canDelete = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() {
      _canDelete =
          _confirmController.text.trim() == 'DELETE' &&
          _passwordController.text.trim().isNotEmpty;
    });
  }

  Future<void> _handleDelete() async {
    if (!_canDelete) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .deleteAccount(currentPassword: _passwordController.text.trim());

      if (mounted) {
        Navigator.pop(context);
        context.go(AppRoutes.welcome);
        context.showSnackBar('Account deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is AppException
              ? e.userFriendlyMessage
              : 'Failed to delete account. Please verify your password.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text(
        'Delete Account',
        style: AppTypography.h2.copyWith(color: colorScheme.error),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is irreversible and will delete your account and profile data on the server.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Enter your current password:',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Current Password',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _validate(),
            ),
            const SizedBox(height: 14),
            Text(
              'Type DELETE to confirm:',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Type DELETE',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _validate(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: (_canDelete && !_isLoading) ? _handleDelete : null,
          child: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onError,
                  ),
                )
              : Text(
                  'Delete Account',
                  style: TextStyle(color: colorScheme.onError),
                ),
        ),
      ],
    );
  }
}
