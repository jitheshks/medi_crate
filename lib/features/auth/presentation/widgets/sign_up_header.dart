import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';

/// SignUpHeader renders the top heading and subtitle for the registration screen.
class SignUpHeader extends StatelessWidget {
  const SignUpHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create your MediVault account',
          style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Create your secure personal health record.',
          style: AppTypography.subtitle.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
