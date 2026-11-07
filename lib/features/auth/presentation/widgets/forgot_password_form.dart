import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';

/// ForgotPasswordForm manages local email input controller, focus node, validation, and submission state.
class ForgotPasswordForm extends StatefulWidget {
  final bool isLoading;
  final bool isOnline;
  final Function(String email) onSubmit;

  const ForgotPasswordForm({
    super.key,
    required this.isLoading,
    this.isOnline = true,
    required this.onSubmit,
  });

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!widget.isOnline) {
      context.showErrorSnackBar(
        'Network connection required to send recovery code.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    widget.onSubmit(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              label: 'EMAIL',
              hint: 'abcd@email.com',
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.none,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _handleSubmit(),
              prefixIcon: const Icon(AppIcons.mail, size: 20),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                final emailTrimmed = val.trim();
                if (!emailTrimmed.contains('@') ||
                    !emailTrimmed.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'SEND RECOVERY CODE',
              isLoading: widget.isLoading,
              onPressed: widget.isOnline ? _handleSubmit : null,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Remember your password? ',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: Text(
                    'Sign In',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
