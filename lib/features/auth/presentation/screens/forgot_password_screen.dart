import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/offline_banner.dart';
import '../providers/auth_providers.dart';
import '../widgets/forgot_password_form.dart';

/// ForgotPasswordScreen initiates password recovery via 4-digit OTP email (A5).
class ForgotPasswordScreen extends ConsumerWidget {
  const ForgotPasswordScreen({super.key});

  Future<void> _handleSubmit(
    WidgetRef ref,
    BuildContext context,
    String email,
  ) async {
    final cleanEmail = email.trim();
    final success = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(cleanEmail);

    if (success && context.mounted) {
      context.pushGuarded(
        AppRoutes.otpVerification,
        extra: {'email': cleanEmail, 'type': 'reset_password'},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft, size: 20),
          onPressed: () => context.popOrGo(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isOnline) const OfflineBanner(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 8,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.lock_reset_rounded,
                            color: colorScheme.onPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Reset your password',
                          style: AppTypography.h1.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter the email address associated with your account. We'll send a 4-digit verification code to verify your identity and reset your password.",
                          style: AppTypography.subtitle.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (authState.forgotPasswordError != null) ...[
                          _buildErrorBanner(
                            context,
                            authState.forgotPasswordError!,
                          ),
                          const SizedBox(height: 16),
                        ],
                        ForgotPasswordForm(
                          isLoading: authState.isLoading,
                          isOnline: isOnline,
                          onSubmit: (email) =>
                              _handleSubmit(ref, context, email),
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
      child: Text(
        message,
        style: AppTypography.caption.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
