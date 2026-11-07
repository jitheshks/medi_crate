import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../providers/auth_providers.dart';
import '../widgets/reset_password_form.dart';

/// ResetPasswordScreen handles new password submission with 4-digit OTP (A6).
class ResetPasswordScreen extends ConsumerWidget {
  final String? email;
  final String? token; // 4-digit OTP

  const ResetPasswordScreen({super.key, this.email, this.token});

  Future<void> _handleReset(
    WidgetRef ref,
    BuildContext context,
    String newPassword,
    String confirmPassword,
  ) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          email: email ?? '',
          otp: token ?? '',
          newPassword: newPassword,
          passwordConfirmation: confirmPassword,
        );

    if (success && context.mounted) {
      context.showSuccessSnackBar(
        'Password reset successfully! Please sign in.',
      );
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.popOrGo(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Password',
                    style: AppTypography.display.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your new password must be at least 8 characters long with uppercase, lowercase, number, and special character.',
                    style: AppTypography.subtitle.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (authState.resetPasswordError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        authState.resetPasswordError!,
                        style: AppTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ResetPasswordForm(
                    isLoading: authState.isLoading,
                    onSubmit: (newPassword, confirmPassword) => _handleReset(
                      ref,
                      context,
                      newPassword,
                      confirmPassword,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
