import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// EmailChangeSection is an expandable card for requesting and verifying email change (B4).
class EmailChangeSection extends ConsumerStatefulWidget {
  const EmailChangeSection({super.key});

  @override
  ConsumerState<EmailChangeSection> createState() => _EmailChangeSectionState();
}

class _EmailChangeSectionState extends ConsumerState<EmailChangeSection> {
  bool _expanded = false;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final msg = await ref
          .read(authRepositoryProvider)
          .requestChangeEmail(
            currentPassword: _passwordController.text.trim(),
            newEmail: _emailController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        context.showSnackBar(msg.isNotEmpty ? msg : 'Verification code sent.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is AppException
            ? e.userFriendlyMessage
            : 'Failed to request email change. Please check your credentials.';
        context.showErrorSnackBar(message);
      }
    }
  }

  Future<void> _handleConfirmOtp() async {
    if (_otpController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .confirmChangeEmail(otp: _otpController.text.trim());

      if (mounted) {
        setState(() {
          _isLoading = false;
          _expanded = false;
          _otpSent = false;
          _passwordController.clear();
          _emailController.clear();
          _otpController.clear();
        });
        context.showSnackBar('Email updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is AppException
            ? e.userFriendlyMessage
            : 'Invalid OTP. Please try again.';
        context.showErrorSnackBar(message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (val) => setState(() => _expanded = val),
        leading: Icon(Icons.email_outlined, color: colorScheme.primary),
        title: Text(
          'Change Email Address',
          style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
        ),
        subtitle: Text(
          'Update primary account email with OTP verification',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_otpSent) ...[
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (val) => (val == null || val.isEmpty)
                          ? 'Password is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'New Email Address',
                        hintText: 'user@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'Send Verification Code',
                      isLoading: _isLoading,
                      onPressed: _handleRequestOtp,
                    ),
                  ] else ...[
                    Text(
                      'Verification code sent to ${_emailController.text.trim()}',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-Digit OTP',
                        hintText: '123456',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'Confirm & Update Email',
                      isLoading: _isLoading,
                      onPressed: _handleConfirmOtp,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
