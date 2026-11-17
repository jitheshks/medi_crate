import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/security/ssl_security_context.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/shared/widgets/feedback/app_error_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup Configuration & Asset Loading Tests', () {
    test('1. .env asset loads through flutter_dotenv without error', () async {
      await dotenv.load(fileName: '.env');
      expect(dotenv.isInitialized, isTrue);

      final supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
      expect(supabaseUrl, isNotNull);
      expect(supabaseUrl, startsWith('https://wnaflcytkubqmrymbmcn'));

      final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
      expect(supabaseAnonKey, isNotNull);
      expect(supabaseAnonKey, startsWith('sb_publishable_'));

      final googleClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID');
      expect(googleClientId, isNotNull);
      expect(googleClientId, startsWith('842207080347-'));
      expect(googleClientId, endsWith('.apps.googleusercontent.com'));
    });

    test('2. Legacy private keys are absent from client .env bundle', () async {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
      expect(dotenv.maybeGet('MEDICRATE_API_KEY'), isNull);
      expect(dotenv.maybeGet('MEDIVAULT_API_KEY'), isNull);
    });

    test('3. SupabaseConfig.validateConfig validates successfully from loaded .env', () async {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
      final config = SupabaseConfig.validateConfig();
      expect(config.url, startsWith('https://wnaflcytkubqmrymbmcn'));
      expect(config.anonKey, startsWith('sb_publishable_'));
    });

    test('4. SslSecurityContext is decoupled from critical startup path', () {
      // SslSecurityContext is preserved for legacy dormant code but does not gate startup
      expect(SslSecurityContext.isInitialized, isFalse);
      expect(SslSecurityContext.context, isNull);
    });

    testWidgets('5. Startup error widget displays MediCrate branding', (tester) async {
      final testError = Exception('Simulated fatal startup failure');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: AppErrorState(
                title: 'Unable to Start MediCrate',
                message:
                    'MediCrate could not finish starting up. Please close the app '
                    'completely and open it again.',
                error: testError,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Unable to Start MediCrate'), findsOneWidget);
      expect(
        find.textContaining('MediCrate could not finish starting up'),
        findsOneWidget,
      );
      expect(find.textContaining('MediVault'), findsNothing);
    });

    test('6. Activation switches are strictly disabled by default prior to controlled rollout', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });
  });
}
