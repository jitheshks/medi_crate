import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';

/// OtpHeader displays the screen title and masked email description.
class OtpHeader extends StatelessWidget {
  final String email;

  const OtpHeader({super.key, required this.email});

  String _maskEmail(String email) {
    if (email.isEmpty) return 'your registered email address';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final domain = parts[1];
    if (username.length <= 2) {
      return '$username***@$domain';
    }
    return '${username.substring(0, 2)}***@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Text(
          'Verify your identity',
          style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the verification code sent to ${_maskEmail(email)}.',
          style: AppTypography.subtitle.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
