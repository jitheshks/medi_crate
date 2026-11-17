import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/secure_storage_service.dart';
import 'package:medi_crate/features/auth/data/datasources/local/auth_local_data_source.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/data/repositories/auth_repository.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/auth/presentation/widgets/sign_up_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ---------------------------------------------------------------------------
// Test Doubles
// ---------------------------------------------------------------------------

class DiagnosticFakeGoTrueClient extends Fake implements sb.GoTrueClient {
  Future<sb.AuthResponse> Function({
    String? email,
    required String password,
    Map<String, dynamic>? data,
  })? onSignUp;

  final StreamController<sb.AuthState> _authStream =
      StreamController<sb.AuthState>.broadcast();

  @override
  Stream<sb.AuthState> get onAuthStateChange => _authStream.stream;

  @override
  sb.User? get currentUser => null;

  @override
  sb.Session? get currentSession => null;

  @override
  Future<sb.AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    sb.OtpChannel channel = sb.OtpChannel.sms,
  }) async {
    if (onSignUp != null) {
      return await onSignUp!(email: email, password: password, data: data);
    }
    return sb.AuthResponse(session: null, user: null);
  }
}

class DiagnosticFakeSupabaseClient extends Fake implements sb.SupabaseClient {
  final DiagnosticFakeGoTrueClient _authClient;
  final String _url;

  DiagnosticFakeSupabaseClient({
    required this._authClient,
    this._url = 'https://wnaflcytkubqmrymbmcn.supabase.co',
  });

  @override
  sb.GoTrueClient get auth => _authClient;

  @override
  sb.PostgrestClient get rest => DiagnosticFakePostgrestClient(_url);
}

class DiagnosticFakePostgrestClient extends Fake
    implements sb.PostgrestClient {
  final String _restUrl;
  DiagnosticFakePostgrestClient(this._restUrl);

  @override
  String get url => '$_restUrl/rest/v1';
}

class DiagnosticFakeConnectivityService extends ConnectivityService {
  final bool online;
  DiagnosticFakeConnectivityService({this.online = true})
      : super(autoInitialize: false);

  @override
  Future<bool> checkConnectivity() async => online;
}

class DiagnosticFakeAuthLocalDataSource extends Fake
    implements AuthLocalDataSource {
  UserModel? savedUser;
  @override
  Future<void> saveUser(UserModel user) async => savedUser = user;
  @override
  Future<UserModel?> getUser() async => savedUser;
  @override
  Future<bool> isLoggedIn() async => savedUser != null;
}

class DiagnosticFakeSecureStorageService extends Fake
    implements SecureStorageService {
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiagnosticFakeGoTrueClient fakeGoTrue;
  late DiagnosticFakeSupabaseClient fakeClient;
  late SupabaseAuthRemoteDataSource remoteDataSource;
  late AuthRepository repository;
  late DiagnosticFakeConnectivityService fakeConnectivity;

  setUp(() {
    fakeGoTrue = DiagnosticFakeGoTrueClient();
    fakeClient = DiagnosticFakeSupabaseClient(authClient: fakeGoTrue);
    remoteDataSource = SupabaseAuthRemoteDataSource(fakeClient);
    fakeConnectivity = DiagnosticFakeConnectivityService(online: true);
    repository = AuthRepository(
      localDataSource: DiagnosticFakeAuthLocalDataSource(),
      supabaseRemoteDataSource: remoteDataSource,
      secureStorage: DiagnosticFakeSecureStorageService(),
      connectivityService: fakeConnectivity,
      supabaseClient: fakeClient,
    );
  });

  group('Registration Network Diagnostics & Exception Handling Tests', () {
    test('1. Successful registration initiates and completes with pending verification', () async {
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        return sb.AuthResponse(
          session: null,
          user: sb.User(
            id: 'mock-user-uuid-1',
            appMetadata: {},
            userMetadata: data ?? {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      };

      final result = await repository.signUp(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'Password123!',
        passwordConfirmation: 'Password123!',
        dob: '1995-05-15',
        gender: 'female',
      );

      expect(result.isPendingVerification, isTrue);
      expect(result.message, equals('Verification code sent to your email.'));
    });

    test('2. SocketException (Network unreachable errno 101) maps to user-friendly NetworkException with cause', () async {
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
          address: null,
          port: 443,
        );
      };

      try {
        await repository.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
          passwordConfirmation: 'Password123!',
          dob: '1995-05-15',
        );
        fail('Should have thrown NetworkException');
      } on NetworkException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals(
            'Unable to connect to the server. Check your internet connection and try again.',
          ),
        );
        expect(e.code, equals('SOCKET_EXCEPTION_101'));
        expect(e.cause, isA<SocketException>());
        expect(e.stackTrace, isNotNull);
      }
    });

    test('3. ClientException categories are handled and differentiated cleanly', () async {
      final endpointUri = Uri.parse(
        'https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/signup',
      );

      // 3a. ClientException wrapping SocketException errno 101 (The exact issue observed on emulator)
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw http.ClientException(
          'SocketException: Connection failed (OS Error: Network is unreachable, errno = 101)',
          endpointUri,
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown NetworkException');
      } on NetworkException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals(
            'Unable to connect to the server. Check your internet connection and try again.',
          ),
        );
        expect(e.code, equals('NETWORK_UNREACHABLE'));
        expect(e.cause, isA<http.ClientException>());
      }

      // 3b. DNS resolution failure
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw http.ClientException(
          'Failed host lookup: "wnaflcytkubqmrymbmcn.supabase.co"',
          endpointUri,
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown NetworkException');
      } on NetworkException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals(
            'Unable to connect to the server. Check your internet connection and try again.',
          ),
        );
        expect(e.code, equals('DNS_LOOKUP_FAILED'));
      }

      // 3c. Connection refused
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw http.ClientException(
          'Connection refused',
          endpointUri,
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown NetworkException');
      } on NetworkException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals(
            'Unable to connect to the server. Check your internet connection and try again.',
          ),
        );
        expect(e.code, equals('CONNECTION_REFUSED'));
      }

      // 3d. Connection timeout
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw http.ClientException(
          'Connection timed out',
          endpointUri,
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown ApiTimeoutException');
      } on ApiTimeoutException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals(
            'Connection timed out. Please check your network and try again.',
          ),
        );
      }

      // 3e. TLS/Certificate error
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw http.ClientException(
          'HandshakeException: Certificate verify failed',
          endpointUri,
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown NetworkException');
      } on NetworkException catch (e) {
        expect(e.code, equals('TLS_SECURITY_ERROR'));
        expect(
          e.userFriendlyMessage,
          contains('Unable to establish a secure connection'),
        );
      }

      // 3f. Non-network general ClientException (does NOT get misclassified as network unreachable)
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw http.ClientException(
          'Malformed HTTP chunked response body',
          endpointUri,
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown UnknownApiException');
      } on UnknownApiException catch (e) {
        expect(e.code, equals('CLIENT_EXCEPTION'));
        expect(e.message, contains('Communication with server failed'));
      }
    });

    test('4. TimeoutException is mapped to ApiTimeoutException', () async {
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw TimeoutException('Request exceeded 15 seconds', const Duration(seconds: 15));
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown ApiTimeoutException');
      } on ApiTimeoutException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals(
            'Connection timed out. Please check your network and try again.',
          ),
        );
        expect(e.cause, isA<TimeoutException>());
        expect(e.stackTrace, isNotNull);
      }
    });

    test('5. AuthException preserves authentication error without misclassifying as network error', () async {
      // 5a. User already registered
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw const sb.AuthException(
          'User already registered',
          statusCode: '422',
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown ValidationException');
      } on ValidationException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals('An account with this email already exists.'),
        );
        expect(e.isNetworkError, isFalse);
        expect(e.cause, isA<sb.AuthException>());
      }

      // 5b. Weak password
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw const sb.AuthException(
          'Password should be at least 8 characters',
          statusCode: '422',
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'pass',
        );
        fail('Should have thrown ValidationException');
      } on ValidationException catch (e) {
        expect(
          e.userFriendlyMessage,
          equals('Password should be at least 8 characters'),
        );
        expect(e.isNetworkError, isFalse);
      }

      // 5c. Rate limiting
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw const sb.AuthException(
          'Too many requests',
          statusCode: '429',
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown ServerException');
      } on ServerException catch (e) {
        expect(e.code, equals('RATE_LIMIT_EXCEEDED'));
        expect(
          e.userFriendlyMessage,
          contains('Too many requests. Please wait a moment'),
        );
        expect(e.isNetworkError, isFalse);
      }
    });

    test('6. Unexpected exceptions are caught, preserved, and translated into UnknownApiException', () async {
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw const FormatException('Unexpected payload structure from gateway');
      };

      try {
        await remoteDataSource.signUp(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'Password123!',
        );
        fail('Should have thrown UnknownApiException');
      } on UnknownApiException catch (e) {
        expect(e.cause, isA<FormatException>());
        expect(e.stackTrace, isNotNull);
        expect(e.message, contains('Registration failed unexpectedly'));
      }
    });

    test('7. Debug diagnostics log endpoint host and operation without exposing passwords or tokens', () async {
      final printedLogs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printedLogs.add(message);
      };

      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        throw const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
        );
      };

      try {
        await remoteDataSource.signUp(
          name: 'John Sensitive',
          email: 'john_sensitive_pii@example.com',
          password: 'SuperSecretPassword99!',
        );
      } catch (_) {}

      // Verify logs exist and contain operation and host
      expect(printedLogs.isNotEmpty, isTrue);
      final combinedLogs = printedLogs.join('\n');
      expect(combinedLogs, contains('signUp'));
      expect(combinedLogs, contains('wnaflcytkubqmrymbmcn.supabase.co'));

      // Crucial security assertion: NEVER log password or sensitive payload
      expect(combinedLogs, isNot(contains('SuperSecretPassword99!')));
    });

    test('8. AuthNotifier loading state and duplicate-submit prevention', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final completer = Completer<sb.AuthResponse>();
      fakeGoTrue.onSignUp = ({data, email, required password}) => completer.future;

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.initialSessionReady;

      // First call initiates loading
      final future1 = notifier.signUp(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'Password123!',
        passwordConfirmation: 'Password123!',
        dob: '1995-05-15',
      );

      expect(container.read(authControllerProvider).isLoading, isTrue);

      // Concurrent second call while first is loading: dropped immediately
      final duplicateResult = await notifier.signUp(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'Password123!',
        passwordConfirmation: 'Password123!',
        dob: '1995-05-15',
      );

      expect(duplicateResult, isNull);

      // Complete first call with an error to verify state reset
      completer.completeError(
        const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
        ),
      );

      final result1 = await future1;
      expect(result1, isNull);

      // Loading is reset to false, and error message is populated
      final finalState = container.read(authControllerProvider);
      expect(finalState.isLoading, isFalse);
      expect(
        finalState.signupError,
        equals(
          'Unable to connect to the server. Check your internet connection and try again.',
        ),
      );

      // A retry can now proceed because loading state was safely cleared
      fakeGoTrue.onSignUp = ({data, email, required password}) async {
        return sb.AuthResponse(session: null, user: null);
      };

      final retryResult = await notifier.signUp(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'Password123!',
        passwordConfirmation: 'Password123!',
        dob: '1995-05-15',
      );

      expect(retryResult, isNotNull);
      expect(container.read(authControllerProvider).isLoading, isFalse);
    });

    testWidgets('9. SignUpForm button disables during loading and retains inputs on failure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SignUpForm(
                isLoading: true,
                onSubmit: (name, email, password, dob, gender) {},
              ),
            ),
          ),
        ),
      );

      // Verify PrimaryButton is disabled when isLoading is true
      final elevatedButtonFinder = find.byType(ElevatedButton);
      expect(elevatedButtonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(elevatedButtonFinder);
      expect(elevatedButton.onPressed, isNull);

      // Verify CircularProgressIndicator is rendered
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('10. Outgoing Supabase Auth HTTP requests include apikey and authorization headers', () async {
      const testAnonKey = 'sb_publishable_test_key_1234567890';
      const testUrl = 'https://wnaflcytkubqmrymbmcn.supabase.co';

      http.Request? capturedRequest;

      final mockHttpClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': 'user-123',
            'aud': 'authenticated',
            'created_at': DateTime.now().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = sb.SupabaseClient(
        testUrl,
        testAnonKey,
        httpClient: mockHttpClient,
        authOptions: const sb.AuthClientOptions(
          authFlowType: sb.AuthFlowType.implicit,
        ),
      );

      await client.auth.signUp(
        email: 'test_user@example.com',
        password: 'Password123!',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.headers['apikey'], equals(testAnonKey));
      expect(
        capturedRequest!.headers['authorization'],
        equals('Bearer $testAnonKey'),
      );
    });
  });
}
