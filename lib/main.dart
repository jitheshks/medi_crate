import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

import 'core/api/ssl_security_context.dart';
import 'core/storage/hive_service.dart';
import 'core/sync/background_sync_service.dart';
import 'features/auth/data/services/google_auth_service.dart';
import 'shared/widgets/feedback/app_error_state.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // These initializers have no cross-dependencies; run them concurrently.
    // Hive is fully opened here so startup providers can read boxes immediately.
    await Future.wait([
      dotenv.load(fileName: '.env'),
      SslSecurityContext.initialize(),
      HiveService.init(),
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      GoogleAuthService.initialize(serverClientId: kGoogleWebServerClientId),
    ]);
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
            title: 'Unable to Start MediVault',
            message:
                'MediVault could not finish starting up. Please close the app '
                'completely and open it again.',
            error: error,
          ),
        ),
      ),
    );
  }
}
