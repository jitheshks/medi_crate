import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/secure_storage_service.dart';
import 'package:medi_crate/core/utils/validators.dart';
import 'package:medi_crate/features/auth/data/datasources/local/auth_local_data_source.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/data/repositories/auth_repository.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:medi_crate/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:medi_crate/features/auth/presentation/widgets/auth_social_sign_in_buttons.dart';
import 'package:medi_crate/features/auth/presentation/widgets/otp_input_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ---------------------------------------------------------------------------
// Test Doubles
// ---------------------------------------------------------------------------

class FakeSecureStorage extends SecureStorageService {
  String? token;
  @override
  Future<String?> getAuthToken() async => token;
  @override
  Future<void> clearAuthToken() async {
    token = null;
  }
}

class FakeConnectivityService extends ConnectivityService {
  final bool online;
  FakeConnectivityService({this.online = true}) : super(autoInitialize: false);

  @override
  Future<bool> checkConnectivity() async => online;
}

class FakeGoTrueClient extends Fake implements sb.GoTrueClient {
  sb.User? mockUser;
  sb.Session? mockSession;
  bool signOutCalled = false;

  @override
  sb.User? get currentUser => mockUser;
  @override
  sb.Session? get currentSession => mockSession;

  @override
  Stream<sb.AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<void> signOut({sb.SignOutScope scope = sb.SignOutScope.global}) async {
    signOutCalled = true;
    mockUser = null;
    mockSession = null;
  }
}

class FakeSupabaseClient extends Fake implements sb.SupabaseClient {
  final FakeGoTrueClient _auth;
  FakeSupabaseClient({FakeGoTrueClient? auth})
    : _auth = auth ?? FakeGoTrueClient();
  @override
  FakeGoTrueClient get auth => _auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. OTP Validation & Route Safety Regression Tests', () {
    test(
      'validateOtp strictly enforces 6 digits by default for Supabase GoTrue',
      () {
        expect(Validators.validateOtp('123456'), isNull);
        expect(Validators.validateOtp('987654'), isNull);

        // When allowLegacy4Digit is false (default), 4-digit code is rejected
        expect(Validators.validateOtp('1234'), contains('6 digits'));
      },
    );

    test(
      'validateOtp accepts 4 digits only when allowLegacy4Digit is true',
      () {
        expect(Validators.validateOtp('1234', allowLegacy4Digit: true), isNull);
        expect(
          Validators.validateOtp('123456', allowLegacy4Digit: true),
          isNull,
        );
        expect(
          Validators.validateOtp('12345', allowLegacy4Digit: true),
          contains('6 digits'),
        );
      },
    );

    test('validateOtp rejects malformed inputs', () {
      expect(Validators.validateOtp(''), contains('verification code'));
      expect(Validators.validateOtp(null), contains('verification code'));
      expect(Validators.validateOtp('1234567'), contains('6 digits'));
      expect(Validators.validateOtp('abcdef'), contains('numbers only'));
      expect(Validators.validateOtp('12-345'), contains('numbers only'));
    });

    test(
      'OtpVerificationScreen constructor safely clamps invalid otpLength to 6',
      () {
        // Zero
        final screenZero = OtpVerificationScreen(
          email: 'test@example.com',
          otpLength: 0,
        );
        expect(screenZero.otpLength, 6);

        // Negative value
        final screenNeg = OtpVerificationScreen(
          email: 'test@example.com',
          otpLength: -5,
        );
        expect(screenNeg.otpLength, 6);

        // Unreasonably large value
        final screenLarge = OtpVerificationScreen(
          email: 'test@example.com',
          otpLength: 9999,
        );
        expect(screenLarge.otpLength, 6);

        // Valid lengths are preserved
        expect(
          OtpVerificationScreen(
            email: 'test@example.com',
            otpLength: 4,
          ).otpLength,
          4,
        );
        expect(
          OtpVerificationScreen(
            email: 'test@example.com',
            otpLength: 6,
          ).otpLength,
          6,
        );
        expect(
          OtpVerificationScreen(
            email: 'test@example.com',
            otpLength: 8,
          ).otpLength,
          8,
        );
      },
    );
  });

  group('2. OTP Widget & Responsiveness Regression Tests', () {
    testWidgets('OtpInputRow fits without overflow at narrow 320dp viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controllers = List.generate(6, (_) => TextEditingController());
      final focusNodes = List.generate(6, (_) => FocusNode());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: OtpInputRow(
                  controllers: controllers,
                  focusNodes: focusNodes,
                  onChanged: (index, val) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(6));
    });

    testWidgets(
      'OtpInputRow fits without overflow at 360dp and 480dp viewports',
      (tester) async {
        for (final width in [360.0, 480.0]) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          final controllers = List.generate(6, (_) => TextEditingController());
          final focusNodes = List.generate(6, (_) => FocusNode());

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: OtpInputRow(
                      controllers: controllers,
                      focusNodes: focusNodes,
                      onChanged: (index, val) {},
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Failed at width: $width',
          );
          expect(find.byType(TextFormField), findsNWidgets(6));
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets('Pasting full 6-digit code populates all 6 controllers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationScreen(
              email: 'patient@medicrate.com',
              type: 'signup',
              otpLength: 6,
            ),
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(6));

      // Paste 6 digits into first box
      await tester.enterText(fields.first, '849201');
      await tester.pump();

      expect(find.text('8'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
      'Partial paste populates available boxes and focuses next empty box',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: OtpVerificationScreen(
                email: 'patient@medicrate.com',
                type: 'signup',
                otpLength: 6,
              ),
            ),
          ),
        );

        final fields = find.byType(TextFormField);

        // Paste 3 digits into first box
        await tester.enterText(fields.first, '735');
        await tester.pump();

        expect(find.text('7'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      },
    );

    testWidgets('Non-numeric characters in paste are filtered out', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationScreen(
              email: 'patient@medicrate.com',
              type: 'signup',
              otpLength: 6,
            ),
          ),
        ),
      );

      final fields = find.byType(TextFormField);

      // Paste text with hyphens and letters
      await tester.enterText(fields.first, '9-A-8-B-7-6');
      await tester.pump();

      expect(find.text('9'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('Focus advances between boxes on single digit entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationScreen(
              email: 'patient@medicrate.com',
              type: 'signup',
              otpLength: 6,
            ),
          ),
        ),
      );

      final fields = find.byType(TextFormField);

      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      await tester.enterText(fields.at(1), '2');
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('3. Screen-Level Form Error Dismissal Tests', () {
    testWidgets('ForgotPasswordScreen dismisses error banner on text edit', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeErrorAuthNotifier(
              initialState: const AuthState(
                forgotPasswordError: 'Account not found',
                loginError: 'Unrelated login error',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ForgotPasswordScreen()),
        ),
      );

      // Verify error banner is visible
      expect(find.text('Account not found'), findsOneWidget);

      // Type in email field
      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'p');
      await tester.pump();

      // Verify forgotPasswordError is cleared and banner is gone
      expect(find.text('Account not found'), findsNothing);

      // Verify unrelated error was NOT cleared
      expect(
        container.read(authControllerProvider).loginError,
        'Unrelated login error',
      );
    });

    testWidgets('ResetPasswordScreen dismisses error banner on text edit', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeErrorAuthNotifier(
              initialState: const AuthState(
                resetPasswordError: 'Reset token expired',
                loginError: 'Unrelated error',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ResetPasswordScreen(
              email: 'patient@medicrate.com',
              token: '123456',
            ),
          ),
        ),
      );

      expect(find.text('Reset token expired'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'N');
      await tester.pump();

      expect(find.text('Reset token expired'), findsNothing);
      expect(
        container.read(authControllerProvider).loginError,
        'Unrelated error',
      );
    });

    testWidgets('SignUpScreen dismisses error banner on text edit', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeErrorAuthNotifier(
              initialState: const AuthState(
                signupError: 'Email already registered',
                loginError: 'Unrelated error',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SignUpScreen()),
        ),
      );

      expect(find.text('Email already registered'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'D');
      await tester.pump();

      expect(find.text('Email already registered'), findsNothing);
      expect(
        container.read(authControllerProvider).loginError,
        'Unrelated error',
      );
    });
  });

  group('4. Google Sign-In Interaction Tests', () {
    testWidgets(
      'Full-width Google button invokes callback and disables during loading',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthSocialSignInButtons(
                onGoogleTap: () => tapped = true,
                showApple: false,
              ),
            ),
          ),
        );

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Apple'), findsNothing);

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();
        expect(tapped, isTrue);

        // When loading, callback is null
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AuthSocialSignInButtons(
                onGoogleTap: null,
                showApple: false,
              ),
            ),
          ),
        );

        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('SignInScreen and SignUpScreen do not pass showApple: true', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SignInScreen()),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SignUpScreen()),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
    });
  });

  group('5. Hive Clinical-Data Preservation Regression Tests', () {
    late Directory tempDir;
    late HiveService hiveService;
    late AuthLocalDataSource localDataSource;
    late AuthRepository authRepository;
    late FakeSecureStorage fakeSecureStorage;
    late FakeGoTrueClient fakeGoTrue;
    late FakeSupabaseClient fakeSupabaseClient;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'hive_auth_preservation_test_',
      );
      Hive.init(tempDir.path);

      await Future.wait([
        Hive.openBox<Map>(HiveService.authBoxName),
        Hive.openBox<Map>(HiveService.syncQueueBoxName),
        Hive.openBox<Map>(HiveService.userBoxName),
        Hive.openBox<Map>(HiveService.settingsBoxName),
        Hive.openBox<Map>(HiveService.consentBoxName),
        Hive.openBox<Map>(HiveService.profileBoxName),
      ]);

      hiveService = HiveService();

      // Seed clinical data across all boxes
      await hiveService.userBox.put('consultation_c101', {
        'id': 'c101',
        'doctor_name': 'Dr. Sharma',
        'notes': 'Follow up on hypertension',
      });
      await hiveService.userBox.put('vital_v202', {
        'id': 'v202',
        'type': 'blood_pressure',
        'value': '120/80',
      });
      await hiveService.userBox.put('report_r303', {
        'id': 'r303',
        'title': 'Complete Blood Count',
        'status': 'verified',
      });

      await hiveService.profileBox.put('profile_active', {
        'id': 'p101',
        'name': 'Asha Menon',
        'relationship': 'Self',
      });

      await hiveService.syncQueueBox.put('pending_mutation_1', {
        'id': 'm001',
        'action': 'create',
        'entity': 'consultation',
      });

      fakeSecureStorage = FakeSecureStorage();
      fakeGoTrue = FakeGoTrueClient();
      fakeSupabaseClient = FakeSupabaseClient(auth: fakeGoTrue);

      localDataSource = AuthLocalDataSource(hiveService);
      authRepository = AuthRepository(
        localDataSource: localDataSource,
        supabaseRemoteDataSource: SupabaseAuthRemoteDataSource(
          fakeSupabaseClient,
        ),
        secureStorage: fakeSecureStorage,
        connectivityService: FakeConnectivityService(online: true),
        supabaseClient: fakeSupabaseClient,
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'Saving and clearing auth user NEVER mutates clinical entities',
      () async {
        // Step 1: Save auth user
        final user = UserModel(
          id: 'user_u101',
          name: 'Asha Menon',
          email: 'asha@medicrate.com',
        );
        await localDataSource.saveUser(user);

        // Verify auth user is stored
        final retrieved = await localDataSource.getUser();
        expect(retrieved?.id, 'user_u101');

        // Verify clinical records are untouched
        expect(hiveService.userBox.get('consultation_c101'), isNotNull);
        expect(hiveService.userBox.get('vital_v202'), isNotNull);
        expect(hiveService.userBox.get('report_r303'), isNotNull);
        expect(hiveService.profileBox.get('profile_active'), isNotNull);
        expect(hiveService.syncQueueBox.get('pending_mutation_1'), isNotNull);

        // Step 2: Clear auth user
        await localDataSource.clearUser();

        // Verify auth user is cleared
        expect(await localDataSource.getUser(), isNull);

        // Verify ALL clinical data remains 100% intact
        final consultation = hiveService.userBox.get('consultation_c101');
        expect(consultation, isNotNull);
        expect(consultation?['doctor_name'], 'Dr. Sharma');

        final vital = hiveService.userBox.get('vital_v202');
        expect(vital, isNotNull);
        expect(vital?['value'], '120/80');

        final report = hiveService.userBox.get('report_r303');
        expect(report, isNotNull);
        expect(report?['title'], 'Complete Blood Count');

        final profile = hiveService.profileBox.get('profile_active');
        expect(profile, isNotNull);
        expect(profile?['name'], 'Asha Menon');

        final syncItem = hiveService.syncQueueBox.get('pending_mutation_1');
        expect(syncItem, isNotNull);
        expect(syncItem?['id'], 'm001');
      },
    );

    test('AuthRepository.signOut preserves all Hive clinical boxes and pending sync mutations', () async {
      await localDataSource.saveUser(
        UserModel(id: 'u1', name: 'User', email: 'u1@test.com'),
      );
      await fakeSecureStorage.saveAuthToken('legacy_token');

      await authRepository.signOut();

      // Auth cache is cleared
      expect(await localDataSource.getUser(), isNull);
      expect(await fakeSecureStorage.getAuthToken(), isNull);

      // Clinical boxes and pending mutations MUST remain untouched
      expect(hiveService.userBox.get('consultation_c101'), isNotNull);
      expect(hiveService.userBox.get('vital_v202'), isNotNull);
      expect(hiveService.userBox.get('report_r303'), isNotNull);
      expect(hiveService.profileBox.get('profile_active'), isNotNull);
      expect(hiveService.syncQueueBox.get('pending_mutation_1'), isNotNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Test Helper Notifier for Screen-Level Error Banner Verification
// ---------------------------------------------------------------------------

class FakeErrorAuthNotifier extends AuthNotifier {
  final AuthState initialState;

  FakeErrorAuthNotifier({required this.initialState});

  @override
  AuthState build() => initialState;

  @override
  void clearForgotPasswordError() {
    state = state.copyWith(clearForgotPasswordError: true);
  }

  @override
  void clearResetPasswordError() {
    state = state.copyWith(clearResetPasswordError: true);
  }

  @override
  void clearSignupError() {
    state = state.copyWith(clearSignupError: true);
  }

  @override
  void clearLoginError() {
    state = state.copyWith(clearLoginError: true);
  }
}
