import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// PasswordChangeSection is an expandable card containing current and new password fields.
class PasswordChangeSection extends ConsumerStatefulWidget {
  const PasswordChangeSection({super.key});

  @override
  ConsumerState<PasswordChangeSection> createState() =>
      _PasswordChangeSectionState();
}

class _PasswordChangeSectionState extends ConsumerState<PasswordChangeSection> {
  bool _expanded = false;
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordChange() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final msg = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentController.text.trim(),
            newPassword: _newController.text.trim(),
            newPasswordConfirmation: _newController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _expanded = false;
          _obscureCurrentPassword = true;
          _obscureNewPassword = true;
          _currentController.clear();
          _newController.clear();
        });
        context.showSnackBar(
          msg.isNotEmpty ? msg : 'Password updated successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is AppException
            ? e.userFriendlyMessage
            : 'Failed to update password. Please check your credentials.';
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
        leading: Icon(Icons.lock_outline, color: colorScheme.primary),
        title: Text(
          'Change Password',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          'Update your account password',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _currentController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: _obscureCurrentPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setState(
                        () =>
                            _obscureCurrentPassword = !_obscureCurrentPassword,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    helperText: 'Minimum 8 characters',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: _obscureNewPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Update Password',
                  isLoading: _isLoading,
                  onPressed: _submitPasswordChange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
