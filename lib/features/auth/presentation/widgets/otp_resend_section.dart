import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';

/// OtpResendSection renders the timer countdown or interactive Resend Code link.
class OtpResendSection extends StatelessWidget {
  final int secondsRemaining;
  final String formattedTimer;
  final bool isOnline;
  final bool isLoading;
  final VoidCallback onResend;

  const OtpResendSection({
    super.key,
    required this.secondsRemaining,
    required this.formattedTimer,
    required this.isOnline,
    required this.isLoading,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Didn't receive the code? ",
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (secondsRemaining > 0)
          Text(
            'Resend in $formattedTimer',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          GestureDetector(
            onTap: (isOnline && !isLoading) ? onResend : null,
            child: Text(
              'Resend Code',
              style: AppTypography.bodyMedium.copyWith(
                color: isOnline
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
