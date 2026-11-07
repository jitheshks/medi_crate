import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/build_context_extensions.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../shared/widgets/feedback/app_error_state.dart';
import 'app_routes.dart';

export 'app_routes.dart';

/// Listens to authControllerProvider and triggers GoRouter redirect re-evaluations.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.isLoading != next.isLoading) {
        notifyListeners();
      }
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final isAuthenticated = authState.isAuthenticated;
    final path = state.uri.path;

    final isSplash = path == AppRoutes.root || path == AppRoutes.splash;
    if (isSplash) {
      return null;
    }

    final isAuthOnlyRoute =
        path == AppRoutes.login ||
        path == AppRoutes.signIn ||
        path == AppRoutes.signup ||
        path == AppRoutes.signUp ||
        path == AppRoutes.register ||
        path == AppRoutes.forgotPassword ||
        path == AppRoutes.resetPassword;

    final isPublicRoute =
        isAuthOnlyRoute ||
        path == AppRoutes.otpVerification ||
        path == AppRoutes.terms ||
        path == AppRoutes.termsPrivacy;

    // If not authenticated and attempting to access a protected route
    if (!isAuthenticated && !isPublicRoute) {
      if (authState.isLoading) {
        return null;
      }
      return AppRoutes.login;
    }

    // If authenticated and attempting to access an auth-only entry route -> redirect to /dashboard
    if (isAuthenticated && isAuthOnlyRoute) {
      return AppRoutes.dashboard;
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

Widget _buildRouterErrorScreen(
  BuildContext context,
  GoRouterState state,
  Ref? ref,
) {
  developer.log(
    '❌ [ROUTER ERROR] Navigation failed for path: ${state.uri.path} | Error: ${state.error}',
    name: 'MediVault.Router',
  );

  return Scaffold(
    appBar: AppBar(
      title: const Text('MediVault'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          final authState = ref?.read(authControllerProvider);
          final fallback = authState?.isAuthenticated == true
              ? AppRoutes.dashboard
              : AppRoutes.login;
          context.popOrGo(fallback);
        },
      ),
    ),
    body: SafeArea(
      child: AppErrorState(
        title: 'Unable to Open Page',
        message: "We couldn't open this page. Please try again.",
        onRetry: () {
          final authState = ref?.read(authControllerProvider);
          if (authState?.isAuthenticated == true) {
            context.go(AppRoutes.dashboard);
          } else {
            context.go(AppRoutes.login);
          }
        },
        retryLabel: 'Return to Home',
      ),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: appRoutes,
    errorBuilder: (context, state) =>
        _buildRouterErrorScreen(context, state, ref),
  );
});

/// Direct GoRouter instance for standalone contexts
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: appRoutes,
  errorBuilder: (context, state) =>
      _buildRouterErrorScreen(context, state, null),
);
