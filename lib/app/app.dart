import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/sync/foreground_resume_sync.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/settings/presentation/providers/settings_providers.dart';
import 'routes/app_router.dart';

/// MediCrateApp initializes MaterialApp.router with global design system theme and routing.
///
/// It also owns the app-lifecycle plumbing for Phase 5 foreground refresh: when
/// the app resumes, or connectivity is restored while it is running, it kicks
/// [runForegroundResumeSync] (fire-and-forget, never blocks the frame) so data a
/// background WorkManager sync merged into Hive surfaces through the existing
/// `clinicalCacheRevisionProvider`.
class MediCrateApp extends ConsumerStatefulWidget {
  const MediCrateApp({super.key});

  @override
  ConsumerState<MediCrateApp> createState() => _MediCrateAppState();
}

class _MediCrateAppState extends ConsumerState<MediCrateApp>
    with WidgetsBindingObserver {
  DateTime? _lastForegroundSync;

  /// Debounce so a rapid resume/online flap does not launch overlapping cycles.
  static const Duration _minGap = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeForegroundSync();
    }
  }

  void _maybeForegroundSync() {
    final now = DateTime.now();
    if (_lastForegroundSync != null &&
        now.difference(_lastForegroundSync!) < _minGap) {
      return;
    }
    _lastForegroundSync = now;
    final container = ProviderScope.containerOf(context, listen: false);
    unawaited(runForegroundResumeSync(container));
  }

  @override
  Widget build(BuildContext context) {
    // Connectivity restored while the app is in the foreground -> also refresh
    // (the offline -> online foreground path required by Phase 5 Part 14).
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final was = prev?.value ?? false;
      final now = next.value ?? false;
      if (now && !was) _maybeForegroundSync();
    });

    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);
    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'MediCrate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
