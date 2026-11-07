import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';
import 'dob_picker_field.dart';
import 'gender_chip_selector.dart';

/// SignUpForm manages local registration form controllers, focus nodes, DOB/gender state, and validation.
class SignUpForm extends StatefulWidget {
  final bool isLoading;
  final Function(
    String name,
    String email,
    String password,
    DateTime? selectedDob,
    String? selectedGender,
  )
  onSubmit;

  const SignUpForm({
    super.key,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  DateTime? _selectedDob;
  String? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _dobError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobError = null;
      });
    }
  }

  void _handleSubmit() {
    if (widget.isLoading) return;
    if (_selectedDob == null) {
      setState(() => _dobError = 'Please select your date of birth');
    } else {
      setState(() => _dobError = null);
    }

    if (!_formKey.currentState!.validate() || _selectedDob == null) return;

    widget.onSubmit(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _selectedDob,
      _selectedGender,
    );
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
              label: 'FULL NAME',
              hint: 'Asha Menon',
              controller: _nameController,
              focusNode: _nameFocusNode,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            DobPickerField(selectedDate: _selectedDob, onTap: _pickDob),
            if (_dobError != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _dobError!,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            GenderChipSelector(
              selectedGender: _selectedGender,
              onSelected: (val) => setState(() => _selectedGender = val),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'EMAIL',
              hint: 'you@example.com',
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              enableSuggestions: false,
              autocorrect: false,
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
              hint: 'Min 8 chars (uppercase, lowercase, number, symbol)',
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
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
            const SizedBox(height: 4),
            Text(
              'Minimum 8 characters with upper, lower, number, & special character.',
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'CONFIRM PASSWORD',
              hint: 'Re-enter your password',
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              obscureText: _obscureConfirmPassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
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
              validator: (val) => Validators.validateConfirmPassword(
                val,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'CREATE YOUR ACCOUNT',
              isLoading: widget.isLoading,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
