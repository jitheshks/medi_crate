import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/offline_banner.dart';
import '../../../../shared/widgets/feedback/vault_badge.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_social_sign_in_buttons.dart';
import '../widgets/sign_in_form.dart';

/// SignInScreen handles user login (A4) and navigation to dashboard or unverified OTP flow.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  Future<void> _handleGoogleSignIn(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();

    if (success && context.mounted) {
      TextInput.finishAutofillContext();
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _handleAppleSignIn(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithApple();

    if (success && context.mounted) {
      TextInput.finishAutofillContext();
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _handleSignIn(
    WidgetRef ref,
    BuildContext context,
    String email,
    String password,
  ) async {
    final result = await ref
        .read(authControllerProvider.notifier)
        .signIn(email, password);

    if (result == null) return;

    if (result.isSuccess && context.mounted) {
      TextInput.finishAutofillContext();
      context.go(AppRoutes.dashboard);
    } else if (result.isPendingVerification && context.mounted) {
      TextInput.finishAutofillContext();
      context.showSnackBar(
        result.pendingData?.message ??
            'Email not verified. Verification code resent.',
      );
      final trimmedEmail = email.trim();
      context.pushGuarded(
        AppRoutes.otpVerification,
        extra: {'email': trimmedEmail, 'type': 'signup'},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final loginError = authState.loginError ?? authState.sessionError;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: VaultBadge()),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isOnline) const OfflineBanner(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: AppSpacing.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome back to MediVault',
                          style: AppTypography.h1.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to access your secure health records',
                          style: AppTypography.subtitle.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (loginError != null) ...[
                          _buildErrorBanner(context, loginError),
                          const SizedBox(height: 16),
                        ],
                        SignInForm(
                          isLoading: authState.isLoading,
                          onValidationFailed: () => ref
                              .read(authControllerProvider.notifier)
                              .clearLoginError(),
                          onFieldChanged: () {
                            if (loginError != null) {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearLoginError();
                            }
                          },
                          onSubmit: (email, password) =>
                              _handleSignIn(ref, context, email, password),
                          onForgotPassword: () =>
                              context.pushGuarded(AppRoutes.forgotPassword),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: colorScheme.outline),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Or continue with',
                                style: AppTypography.caption.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: colorScheme.outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        AuthSocialSignInButtons(
                          onAppleTap: authState.isLoading
                              ? null
                              : () => _handleAppleSignIn(ref, context),
                          onGoogleTap: authState.isLoading
                              ? null
                              : () => _handleGoogleSignIn(ref, context),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              'New to MediVault? ',
                              style: AppTypography.bodyMedium.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  context.pushGuarded(AppRoutes.signup),
                              child: Text(
                                'Create your account',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
