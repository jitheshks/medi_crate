import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// AuthSocialSignInButtons renders social sign-in pill buttons.
/// In MediCrate's Supabase-first architecture, Google Sign-In is the primary native social auth.
/// When [showApple] is false (default), it renders a full-width "Continue with Google" button.
class AuthSocialSignInButtons extends StatelessWidget {
  final VoidCallback? onGoogleTap;
  final VoidCallback? onAppleTap;
  final bool showApple;

  const AuthSocialSignInButtons({
    super.key,
    this.onGoogleTap,
    this.onAppleTap,
    this.showApple = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!showApple || onAppleTap == null) {
      return _buildGoogleButton(context, isFullWidth: true);
    }

    return Row(
      children: [
        Expanded(child: _buildGoogleButton(context, isFullWidth: false)),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Continue with Apple',
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: onAppleTap,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.surface,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/apple.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.surface,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Apple',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.button.copyWith(
                          color: colorScheme.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context, {required bool isFullWidth}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Continue with Google',
      child: SizedBox(
        height: 50,
        width: isFullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: onGoogleTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline, width: 1),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/google.svg',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isFullWidth ? 'Continue with Google' : 'Google',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.button.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
