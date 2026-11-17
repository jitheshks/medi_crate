import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import 'otp_header.dart';
import 'otp_input_row.dart';
import 'otp_resend_section.dart';

class OtpVerificationForm extends StatelessWidget {
  final String email;
  final String type;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final String? error;
  final bool isLoading;
  final bool isOnline;
  final bool isCodeComplete;
  final int secondsRemaining;
  final String formattedTimer;
  final void Function(int, String) onOtpInput;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

  const OtpVerificationForm({
    super.key,
    required this.email,
    required this.type,
    required this.controllers,
    required this.focusNodes,
    required this.error,
    required this.isLoading,
    required this.isOnline,
    required this.isCodeComplete,
    required this.secondsRemaining,
    required this.formattedTimer,
    required this.onOtpInput,
    required this.onVerify,
    required this.onResend,
    required this.onChangeEmail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OtpHeader(email: email),
          const SizedBox(height: 32),
          OtpInputRow(
            controllers: controllers,
            focusNodes: focusNodes,
            onChanged: onOtpInput,
          ),
          if (!isOnline) ...[
            const SizedBox(height: 12),
            Text(
              'No internet connection. Please check your network.',
              style: AppTypography.caption.copyWith(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: AppTypography.caption.copyWith(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            text: type == 'reset_password'
                ? 'Continue to Reset Password'
                : 'Verify Email',
            isLoading: isLoading,
            onPressed: (isCodeComplete && isOnline && !isLoading)
                ? onVerify
                : null,
          ),
          const SizedBox(height: 24),
          OtpResendSection(
            secondsRemaining: secondsRemaining,
            formattedTimer: formattedTimer,
            isOnline: isOnline,
            isLoading: isLoading,
            onResend: onResend,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onChangeEmail,
            child: Text(
              'Change email',
              style: AppTypography.caption.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
