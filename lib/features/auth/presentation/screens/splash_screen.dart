import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../providers/auth_providers.dart';

/// SplashScreen displays brand identity, checks session state, and auto-advances:
/// Splash -> Check Authentication -> Dashboard (authenticated) OR Login (unauthenticated).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Smallest window that keeps the brand splash + logo Hero visible without a
  /// flash; the real gate is initial session readiness, not this floor.
  static const Duration _minimumBrandingDuration = Duration(milliseconds: 900);

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    _checkSessionAndNavigate();
  }

  /// Advances once the one-time initial session check has resolved.
  Future<void> _checkSessionAndNavigate() async {
    await Future.wait<dynamic>([
      ref.read(authControllerProvider.notifier).initialSessionReady,
      Future<void>.delayed(_minimumBrandingDuration),
    ]);
    _navigateNext();
  }

  void _navigateNext() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final authState = ref.read(authControllerProvider);
    if (authState.isAuthenticated) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Semantics(
            label: 'Checking your session, please wait',
            child: Column(
              children: [
                const Spacer(),
                const Hero(tag: 'app_logo', child: PulsingVaultLogo()),
                const SizedBox(height: 24),
                Text(
                  'MediVault',
                  style: AppTypography.display.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Secure Personal Health Vault',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Text(
                  'CHECKING YOUR SESSION',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: null,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
