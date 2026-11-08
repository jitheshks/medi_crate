import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/terms_privacy_screen.dart';
import 'app_routes.dart';

int _sanitizeOtpLength(dynamic val) {
  if (val == null) return 6;
  final parsed = int.tryParse(val.toString());
  if (parsed == null || parsed < 4 || parsed > 8) {
    return 6;
  }
  return parsed;
}

final List<RouteBase> authRoutes = [
  GoRoute(
    path: AppRoutes.root,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: AppRoutes.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const SignInScreen(),
  ),
  GoRoute(
    path: AppRoutes.signIn,
    builder: (context, state) => const SignInScreen(),
  ),
  GoRoute(
    path: AppRoutes.signup,
    builder: (context, state) => const SignUpScreen(),
  ),
  GoRoute(
    path: AppRoutes.signUp,
    builder: (context, state) => const SignUpScreen(),
  ),
  GoRoute(
    path: AppRoutes.register,
    builder: (context, state) => const SignUpScreen(),
  ),
  GoRoute(
    path: AppRoutes.forgotPassword,
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: AppRoutes.resetPassword,
    builder: (context, state) {
      String email = '';
      String? token;
      if (state.extra is Map) {
        final extra = state.extra as Map;
        email = (extra['email'] ?? '').toString().trim();
        token = (extra['code'] ?? extra['token'] ?? extra['otp'])?.toString();
      }
      if (email.isEmpty) {
        email = (state.uri.queryParameters['email'] ?? '').trim();
      }
      token ??=
          state.uri.queryParameters['token'] ??
          state.uri.queryParameters['code'] ??
          state.uri.queryParameters['otp'];
      return ResetPasswordScreen(email: email, token: token);
    },
  ),
  GoRoute(
    path: AppRoutes.terms,
    builder: (context, state) => const TermsPrivacyScreen(),
  ),
  GoRoute(
    path: AppRoutes.termsPrivacy,
    builder: (context, state) => const TermsPrivacyScreen(),
  ),
  GoRoute(
    path: AppRoutes.otpVerification,
    builder: (context, state) {
      String email = '';
      String type = 'signup';
      int? timerSeconds;
      int? userId;
      int otpLength = 6;
      if (state.extra is Map) {
        final extra = state.extra as Map;
        email = (extra['email'] ?? '').toString().trim();
        type = (extra['type'] ?? extra['mode'] ?? 'signup').toString();
        if (extra.containsKey('timer_seconds')) {
          timerSeconds = int.tryParse(extra['timer_seconds'].toString());
        }
        if (extra.containsKey('user_id')) {
          userId = int.tryParse(extra['user_id'].toString());
        }
        if (extra.containsKey('otp_length')) {
          otpLength = _sanitizeOtpLength(extra['otp_length']);
        }
      } else if (state.extra is String) {
        email = (state.extra as String).trim();
      }
      if (email.isEmpty) {
        email = (state.uri.queryParameters['email'] ?? '').trim();
      }
      if (state.uri.queryParameters.containsKey('type') ||
          state.uri.queryParameters.containsKey('mode')) {
        type =
            state.uri.queryParameters['type'] ??
            state.uri.queryParameters['mode'] ??
            type;
      }
      if (state.uri.queryParameters.containsKey('timer_seconds')) {
        timerSeconds = int.tryParse(
          state.uri.queryParameters['timer_seconds'] ?? '',
        );
      }
      if (state.uri.queryParameters.containsKey('user_id')) {
        userId = int.tryParse(state.uri.queryParameters['user_id'] ?? '');
      }
      if (state.uri.queryParameters.containsKey('otp_length')) {
        otpLength = _sanitizeOtpLength(state.uri.queryParameters['otp_length']);
      }
      return OtpVerificationScreen(
        email: email,
        type: type,
        initialTimerSeconds: timerSeconds,
        userId: userId,
        otpLength: otpLength,
      );
    },
  ),
];
