import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/storage/hive_service.dart';
import 'core/supabase/supabase_config.dart';
import 'core/sync/background_sync_service.dart';
import 'core/sync/sync_rollout_config.dart';
import 'core/utils/app_logger.dart';
import 'features/auth/data/services/google_auth_service.dart';
import 'shared/widgets/feedback/app_error_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    try {
      await dotenv.load(fileName: '.env');
      AppLogger.info('.env configuration loaded successfully', 'Startup');
    } catch (e) {
      AppLogger.warning(
        '.env load skipped or failed: $e (falling back to compile-time environment)',
        'Startup',
      );
    }

    final envGoogleClientId =
        (dotenv.isInitialized ? dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID') : null)
            ?.trim();
    const compileTimeGoogleClientId =
        String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final googleClientId =
        (envGoogleClientId != null && envGoogleClientId.isNotEmpty)
            ? envGoogleClientId
            : (compileTimeGoogleClientId.isNotEmpty
                ? compileTimeGoogleClientId
                : null);

    // These initializers have no cross-dependencies; run them concurrently.
    // Hive is fully opened here so startup providers can read boxes immediately.
    // Firebase is not used; Supabase is the sole backend & authentication authority.
    await Future.wait([
      HiveService.init(),
      GoogleAuthService.initialize(serverClientId: googleClientId),
    ]);

    // Supabase is initialized once after environment variables are loaded.
    await SupabaseConfig.initialize();

    // Ingest internal beta synchronization rollout configuration and fail-closed controls.
    SyncRolloutConfig.loadFromEnvironment();
  } catch (e, stack) {
    // A required dependency failed; surface it instead of mounting a broken app.
    debugPrint('[Startup] Fatal initialization failure: $e\n$stack');
    runApp(_StartupErrorApp(error: e));
    return;
  }

  // Enable the existing background sync safety net now that Hive is open.
  // Internally platform-guarded, idempotent, and wrapped in try/catch — it
  // registers the periodic WorkManager task and never gates startup on the
  // network. A failure here must not block the app.
  try {
    await BackgroundSyncService.initialize();
  } catch (e) {
    debugPrint('[Startup] Background sync init skipped: $e');
  }

  runApp(const ProviderScope(child: MediCrateApp()));
}

/// Minimal standalone app shown when required pre-runApp initialization fails.
class _StartupErrorApp extends StatelessWidget {
  final Object error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: AppErrorState(
            title: 'Unable to Start MediCrate',
            message:
                'MediCrate could not finish starting up. Please close the app '
                'completely and open it again.',
            error: error,
          ),
        ),
      ),
    );
  }
}
