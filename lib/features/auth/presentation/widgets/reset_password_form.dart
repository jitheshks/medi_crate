import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';

/// ResetPasswordForm manages password input, confirmation matching, and submission.
class ResetPasswordForm extends StatefulWidget {
  final bool isLoading;
  final Function(String newPassword, String confirmPassword) onSubmit;

  const ResetPasswordForm({
    super.key,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(_passwordController.text, _confirmController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: 'NEW PASSWORD',
            hint: '••••••••',
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
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
            validator: Validators.validatePassword,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'CONFIRM NEW PASSWORD',
            hint: '••••••••',
            controller: _confirmController,
            focusNode: _confirmFocusNode,
            obscureText: _obscureConfirmPassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(AppIcons.lock, size: 20),
            onFieldSubmitted: (_) => _handleSubmit(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? AppIcons.eyeOff : AppIcons.eye,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            validator: (v) =>
                Validators.validateConfirmPassword(v, _passwordController.text),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Save New Password',
            isLoading: widget.isLoading,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
