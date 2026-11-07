import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// AuthSocialSignInButtons renders the compact side-by-side Google and Apple
/// sign-in pill buttons with official brand SVG icons and accessible semantics.
class AuthSocialSignInButtons extends StatelessWidget {
  final VoidCallback? onGoogleTap;
  final VoidCallback? onAppleTap;

  const AuthSocialSignInButtons({super.key, this.onGoogleTap, this.onAppleTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Continue with Google',
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: onGoogleTap,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outline, width: 1),
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
                      'assets/icons/google.svg',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Google',
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
          ),
        ),
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
}
