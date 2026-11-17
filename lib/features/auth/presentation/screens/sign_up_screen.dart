import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/offline_banner.dart';
import '../../../../shared/widgets/feedback/vault_badge.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_social_sign_in_buttons.dart';
import '../widgets/sign_up_footer.dart';
import '../widgets/sign_up_form.dart';
import '../widgets/sign_up_header.dart';
import 'terms_privacy_sheet.dart';

/// SignUpScreen collects user details to initiate new account registration (A1).
class SignUpScreen extends ConsumerWidget {
  const SignUpScreen({super.key});

  Future<void> _handleGoogleSignIn(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();

    if (success && context.mounted) {
      TextInput.finishAutofillContext();
      context.go(AppRoutes.dashboard);
    }
  }

  void _onFormSubmit({
    required BuildContext context,
    required WidgetRef ref,
    required String name,
    required String email,
    required String password,
    required DateTime? selectedDob,
    String? selectedGender,
  }) {
    if (ref.read(authControllerProvider).isLoading) return;
    TermsPrivacySheet.show(
      context: context,
      onAccept: () => _registerUser(
        context: context,
        ref: ref,
        name: name,
        email: email,
        password: password,
        selectedDob: selectedDob,
        selectedGender: selectedGender,
      ),
    );
  }

  Future<void> _registerUser({
    required BuildContext context,
    required WidgetRef ref,
    required String name,
    required String email,
    required String password,
    required DateTime? selectedDob,
    String? selectedGender,
  }) async {
    if (ref.read(authControllerProvider).isLoading) return;
    final formattedDob = selectedDob != null
        ? DateFormat('yyyy-MM-dd').format(selectedDob)
        : '';
    String? normalizedGender;
    if (selectedGender != null && selectedGender.trim().isNotEmpty) {
      final g = selectedGender.trim().toLowerCase();
      normalizedGender = (g == 'others') ? 'other' : g;
    }

    final cleanName = name.trim();
    final cleanEmail = email.trim();

    final response = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          name: cleanName,
          email: cleanEmail,
          password: password,
          passwordConfirmation: password,
          dob: formattedDob,
          gender: normalizedGender,
        );

    if (response != null && context.mounted) {
      TextInput.finishAutofillContext();
      if (response.isPendingVerification) {
        context.showSnackBar(
          response.message ?? 'Email not verified. OTP resent successfully.',
        );
      }
      final extraMap = <String, dynamic>{'email': cleanEmail, 'type': 'signup'};
      if (response.userId != null) {
        extraMap['user_id'] = response.userId;
      }
      context.pushGuarded(AppRoutes.otpVerification, extra: extraMap);
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
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft, size: 20),
          onPressed: () => context.popOrGo(AppRoutes.login),
        ),
        title: Text(
          'MediCrate',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: true,
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
                        const SignUpHeader(),
                        const SizedBox(height: 20),
                        if (authState.signupError != null) ...[
                          _buildErrorBanner(context, authState.signupError!),
                          const SizedBox(height: 16),
                        ],
                        SignUpForm(
                          isLoading: authState.isLoading,
                          onFieldChanged: () {
                            if (authState.signupError != null) {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearSignupError();
                            }
                          },
                          onSubmit: (name, email, password, dob, gender) =>
                              _onFormSubmit(
                                context: context,
                                ref: ref,
                                name: name,
                                email: email,
                                password: password,
                                selectedDob: dob,
                                selectedGender: gender,
                              ),
                        ),
                        const SizedBox(height: 24),
                        _buildDivider(colorScheme),
                        const SizedBox(height: 20),
                        // Social sign-in (Google/Apple) failures are stored in
                        // authState.loginError by AuthNotifier; surface them here
                        // with the existing banner. signupError stays reserved
                        // for the account-registration form above.
                        if (authState.loginError != null) ...[
                          _buildErrorBanner(context, authState.loginError!),
                          const SizedBox(height: 16),
                        ],
                        AuthSocialSignInButtons(
                          onGoogleTap: authState.isLoading
                              ? null
                              : () => _handleGoogleSignIn(ref, context),
                        ),
                        const SizedBox(height: 28),
                        const SignUpFooter(),
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

  Widget _buildDivider(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.outline)),
      ],
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
