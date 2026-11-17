import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';

/// SignInForm manages local form controllers, focus nodes, validation, and password visibility.
class SignInForm extends StatefulWidget {
  final bool isLoading;
  final Function(String email, String password) onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback? onValidationFailed;
  final VoidCallback? onFieldChanged;

  const SignInForm({
    super.key,
    required this.isLoading,
    required this.onSubmit,
    required this.onForgotPassword,
    this.onValidationFailed,
    this.onFieldChanged,
  });

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleTextChanged);
    _passwordController.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    widget.onFieldChanged?.call();
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleTextChanged);
    _passwordController.removeListener(_handleTextChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (widget.isLoading) return;
    if (!_formKey.currentState!.validate()) {
      widget.onValidationFailed?.call();
      return;
    }
    widget.onSubmit(_emailController.text.trim(), _passwordController.text);
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
              label: 'EMAIL ADDRESS',
              hint: 'name@example.com',
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autofillHints: const [AutofillHints.email],
              prefixIcon: const Icon(AppIcons.mail, size: 20),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'PASSWORD',
              hint: '••••••••',
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _handleSubmit(),
              prefixIcon: const Icon(AppIcons.lock, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? AppIcons.eyeOff : AppIcons.eye,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPassword,
                child: Text(
                  'Forgot password?',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Sign In',
              isLoading: widget.isLoading,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
