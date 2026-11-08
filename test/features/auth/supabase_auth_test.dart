import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/secure_storage_service.dart';
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/auth/data/datasources/local/auth_local_data_source.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/data/repositories/auth_repository.dart';
import 'package:medi_crate/features/auth/data/services/google_auth_service.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ---------------------------------------------------------------------------
// Test Doubles and Mocks
// ---------------------------------------------------------------------------

class FakeSecureStorageService extends SecureStorageService {
  String? token;
  String? refreshToken;

  @override
  Future<String?> getAuthToken() async => token;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAuthToken(String t) async {
    token = t;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    token = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearAuthToken() async {
    token = null;
    refreshToken = null;
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
  bool shouldThrowInvalidCredentials = false;
  bool shouldThrowEmailNotConfirmed = false;
  bool shouldThrowUserAlreadyExists = false;
  bool shouldThrowInvalidOtp = false;
  bool resendCalled = false;
  sb.OtpType? lastResendType;
  bool resetPasswordForEmailCalled = false;
  bool updateUserCalled = false;
  String? lastUpdatedPassword;
  bool signOutCalled = false;
  String? lastGoogleIdToken;

  final StreamController<sb.AuthState> _authStreamController =
      StreamController<sb.AuthState>.broadcast();

  @override
  Stream<sb.AuthState> get onAuthStateChange => _authStreamController.stream;

  @override
  sb.User? get currentUser => mockUser;

  @override
  sb.Session? get currentSession => mockSession;

  void emitAuthState(sb.AuthChangeEvent event, sb.Session? session) {
    _authStreamController.add(sb.AuthState(event, session));
  }

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
    if (shouldThrowUserAlreadyExists) {
      throw const sb.AuthException(
        'User already registered',
        statusCode: '422',
      );
    }
    return sb.AuthResponse(session: mockSession, user: mockUser);
  }

  @override
  Future<sb.AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (shouldThrowInvalidCredentials) {
      throw const sb.AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );
    }
    if (shouldThrowEmailNotConfirmed) {
      throw const sb.AuthException('Email not confirmed', statusCode: '400');
    }
    return sb.AuthResponse(session: mockSession, user: mockUser);
  }

  @override
  Future<sb.AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required sb.OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    if (shouldThrowInvalidOtp) {
      throw const sb.AuthException('Token is expired', statusCode: '400');
    }
    return sb.AuthResponse(session: mockSession, user: mockUser);
  }

  @override
  Future<sb.ResendResponse> resend({
    String? email,
    String? phone,
    required sb.OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    resendCalled = true;
    lastResendType = type;
    return sb.ResendResponse();
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    resetPasswordForEmailCalled = true;
  }

  @override
  Future<sb.UserResponse> updateUser(
    sb.UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    updateUserCalled = true;
    lastUpdatedPassword = attributes.password;
    return sb.UserResponse.fromJson(mockUser?.toJson() ?? {});
  }

  @override
  Future<sb.AuthResponse> signInWithIdToken({
    required sb.OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    lastGoogleIdToken = idToken;
    return sb.AuthResponse(session: mockSession, user: mockUser);
  }

  @override
  Future<void> signOut({sb.SignOutScope scope = sb.SignOutScope.global}) async {
    signOutCalled = true;
    mockUser = null;
    mockSession = null;
  }

  @override
  Future<sb.AuthResponse> refreshSession([String? refreshToken]) async {
    return sb.AuthResponse(session: mockSession, user: mockUser);
  }
}

class FakeSupabaseClient extends Fake implements sb.SupabaseClient {
  final FakeGoTrueClient _auth;

  FakeSupabaseClient({FakeGoTrueClient? auth})
    : _auth = auth ?? FakeGoTrueClient();

  @override
  FakeGoTrueClient get auth => _auth;
}

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  final FakeGoogleSignInAuthentication _auth;

  FakeGoogleSignInAccount(this._auth);

  @override
  GoogleSignInAuthentication get authentication => _auth;
}

class FakeGoogleSignInAuthentication extends Fake
    implements GoogleSignInAuthentication {
  @override
  final String? idToken;

  FakeGoogleSignInAuthentication({this.idToken});
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? accountToReturn;
  bool shouldThrowCancellation = false;

  @override
  Future<GoogleSignInAccount> authenticate({List<String>? scopeHint}) async {
    if (shouldThrowCancellation) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'User canceled sign-in.',
      );
    }
    return accountToReturn!;
  }

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

sb.User createDummySupabaseUser({
  String id = 'sb-user-uuid-12345',
  String email = 'patient@medicrate.com',
  String name = 'Jane Doe',
  String dob = '1995-05-15',
  String gender = 'female',
  String? provider = 'email',
  bool isConfirmed = true,
}) {
  return sb.User(
    id: id,
    appMetadata: {'provider': provider},
    userMetadata: {
      'full_name': name,
      'dob': dob,
      'gender': gender,
      'blood_group': 'O+',
    },
    aud: 'authenticated',
    createdAt: DateTime(2025, 1, 1).toIso8601String(),
    email: email,
    emailConfirmedAt: isConfirmed
        ? DateTime(2025, 1, 2).toIso8601String()
        : null,
  );
}

sb.Session createDummySupabaseSession({required sb.User user}) {
  return sb.Session(
    accessToken: 'mock-sb-access-token-jwt',
    refreshToken: 'mock-sb-refresh-token-jwt',
    tokenType: 'bearer',
    user: user,
  );
}

// ---------------------------------------------------------------------------
// Main Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late FakeSecureStorageService fakeSecureStorage;
  late FakeConnectivityService fakeConnectivity;
  late FakeGoTrueClient fakeGoTrue;
  late FakeSupabaseClient fakeSupabaseClient;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medi_crate_sb_auth_test_');
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

    fakeSecureStorage = FakeSecureStorageService();
    fakeConnectivity = FakeConnectivityService(online: true);
    fakeGoTrue = FakeGoTrueClient();
    fakeSupabaseClient = FakeSupabaseClient(auth: fakeGoTrue);

    SupabaseConfig.setMockClient(fakeSupabaseClient);
  });

  tearDown(() async {
    SupabaseConfig.resetForTesting();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('1. SupabaseConfig & Initialization Validation Tests', () {
    test('validateConfig throws SupabaseConfigurationException on empty or missing URL', () {
      expect(
        () => SupabaseConfig.validateConfig(url: '', anonKey: 'dummy-anon-key'),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    });

    test(
      'validateConfig throws SupabaseConfigurationException on malformed URL',
      () {
        expect(
          () => SupabaseConfig.validateConfig(
            url: 'not-a-valid-url',
            anonKey: 'dummy-anon-key',
          ),
          throwsA(isA<SupabaseConfigurationException>()),
        );
      },
    );

    test(
      'validateConfig throws SupabaseConfigurationException on empty anonKey',
      () {
        expect(
          () => SupabaseConfig.validateConfig(
            url: 'https://test.supabase.co',
            anonKey: '',
          ),
          throwsA(isA<SupabaseConfigurationException>()),
        );
      },
    );

    test('validateConfig returns trimmed valid config for valid inputs', () {
      final config = SupabaseConfig.validateConfig(
        url: '  https://valid.supabase.co  ',
        anonKey: '  valid-anon-key-123  ',
      );
      expect(config.url, 'https://valid.supabase.co');
      expect(config.anonKey, 'valid-anon-key-123');
    });

    test('SupabaseConfig.client throws StateError when uninitialized and no mock client is set', () {
      SupabaseConfig.resetForTesting();
      expect(() => SupabaseConfig.client, throwsA(isA<StateError>()));
    });

    test('SupabaseConfig.setMockClient sets custom client and sets isInitialized to true', () {
      final mockClient = FakeSupabaseClient();
      SupabaseConfig.setMockClient(mockClient);
      expect(SupabaseConfig.isInitialized, isTrue);
      expect(SupabaseConfig.client, same(mockClient));
    });
  });

  group('2. UserModel Supabase Mapping Tests', () {
    test('UserModel.fromSupabaseUser maps all metadata fields accurately', () {
      final sbUser = createDummySupabaseUser(
        id: 'user-42',
        email: 'alice@example.com',
        name: 'Alice Wonder',
        dob: '1992-04-12',
        gender: 'female',
      );

      final user = UserModel.fromSupabaseUser(sbUser);
      expect(user.id, 'user-42');
      expect(user.email, 'alice@example.com');
      expect(user.name, 'Alice Wonder');
      expect(user.dateOfBirth, '1992-04-12');
      expect(user.gender, 'female');
      expect(user.bloodGroup, 'O+');
      expect(user.authProvider, AuthProviderType.emailPassword);
    });

    test(
      'UserModel.fromSupabaseUser resolves OAuth provider from appMetadata',
      () {
        final sbUser = createDummySupabaseUser(provider: 'google');
        final user = UserModel.fromSupabaseUser(sbUser);
        expect(user.authProvider, AuthProviderType.google);
      },
    );

    test('UserModel.fromSupabaseUser falls back to email prefix when metadata is empty', () {
      final sbUser = sb.User(
        id: 'u-1',
        appMetadata: {},
        userMetadata: null,
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'bob.smith@medicrate.com',
      );

      final user = UserModel.fromSupabaseUser(sbUser);
      expect(user.name, 'bob.smith');
      expect(user.authProvider, AuthProviderType.emailPassword);
    });
  });

  group('3. Supabase Email/Password Remote Data Source & Repository Tests', () {
    late SupabaseAuthRemoteDataSource remoteDataSource;
    late AuthLocalDataSource localDataSource;
    late AuthRepository repository;

    setUp(() {
      remoteDataSource = SupabaseAuthRemoteDataSource(fakeSupabaseClient);
      localDataSource = AuthLocalDataSource(hiveService);
      repository = AuthRepository(
        localDataSource: localDataSource,
        supabaseRemoteDataSource: remoteDataSource,
        secureStorage: fakeSecureStorage,
        connectivityService: fakeConnectivity,
        supabaseClient: fakeSupabaseClient,
      );
    });

    test('signUp returns pendingVerification when Supabase session is null (email confirmation required)', () async {
      fakeGoTrue.mockUser = createDummySupabaseUser(isConfirmed: false);
      fakeGoTrue.mockSession = null;

      final result = await repository.signUp(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'Password123!',
        passwordConfirmation: 'Password123!',
        dob: '1995-05-15',
        gender: 'female',
      );

      expect(result.isPendingVerification, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test(
      'signUp throws ValidationException when passwords do not match',
      () async {
        expect(
          () => repository.signUp(
            name: 'Jane Doe',
            email: 'jane@example.com',
            password: 'Password123!',
            passwordConfirmation: 'Mismatch123!',
            dob: '1995-05-15',
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'signUp throws ValidationException when user is already registered',
      () async {
        fakeGoTrue.shouldThrowUserAlreadyExists = true;

        expect(
          () => repository.signUp(
            name: 'Jane Doe',
            email: 'existing@example.com',
            password: 'Password123!',
            passwordConfirmation: 'Password123!',
            dob: '1995-05-15',
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'signIn with valid credentials succeeds and caches user in Hive',
      () async {
        final sbUser = createDummySupabaseUser();
        fakeGoTrue.mockUser = sbUser;
        fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

        final result = await repository.signIn(
          email: 'patient@medicrate.com',
          password: 'Password123!',
        );

        expect(result.isSuccess, isTrue);
        expect(result.authData?.email, 'patient@medicrate.com');

        // Verify cached in Hive
        final cachedUser = await localDataSource.getUser();
        expect(cachedUser, isNotNull);
        expect(cachedUser?.id, sbUser.id);
        expect(cachedUser?.email, 'patient@medicrate.com');

        // Verify no legacy Laravel token stored in secure storage
        expect(await fakeSecureStorage.getAuthToken(), isNull);
      },
    );

    test('signIn with unconfirmed email returns pendingVerification and resends OTP', () async {
      fakeGoTrue.shouldThrowEmailNotConfirmed = true;

      final result = await repository.signIn(
        email: 'unconfirmed@medicrate.com',
        password: 'Password123!',
      );

      expect(result.isPendingVerification, isTrue);
      expect(result.isSuccess, isFalse);
      expect(fakeGoTrue.resendCalled, isTrue);
      expect(fakeGoTrue.lastResendType, sb.OtpType.signup);
    });

    test(
      'signIn with invalid credentials throws UnauthorizedException',
      () async {
        fakeGoTrue.shouldThrowInvalidCredentials = true;

        expect(
          () => repository.signIn(
            email: 'wrong@medicrate.com',
            password: 'BadPassword!',
          ),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );

    test(
      'verifyEmail with valid OTP creates session and caches user in Hive',
      () async {
        final sbUser = createDummySupabaseUser(isConfirmed: true);
        fakeGoTrue.mockUser = sbUser;
        fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

        final user = await repository.verifyEmail(
          email: 'patient@medicrate.com',
          otp: '1234',
        );

        expect(user.id, sbUser.id);
        expect(user.email, 'patient@medicrate.com');

        final cached = await localDataSource.getUser();
        expect(cached?.id, sbUser.id);
      },
    );

    test('verifyEmail with invalid OTP throws ValidationException', () async {
      fakeGoTrue.shouldThrowInvalidOtp = true;

      expect(
        () =>
            repository.verifyEmail(email: 'patient@medicrate.com', otp: '0000'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('resendOtp delegates to Supabase with correct OtpType', () async {
      await repository.resendOtp(
        email: 'patient@medicrate.com',
        type: 'signup',
      );
      expect(fakeGoTrue.resendCalled, isTrue);
      expect(fakeGoTrue.lastResendType, sb.OtpType.signup);

      await repository.resendOtp(
        email: 'patient@medicrate.com',
        type: 'reset_password',
      );
      expect(fakeGoTrue.lastResendType, sb.OtpType.recovery);
    });

    test('forgotPassword triggers resetPasswordForEmail', () async {
      final res = await repository.forgotPassword('patient@medicrate.com');
      expect(fakeGoTrue.resetPasswordForEmailCalled, isTrue);
      expect(res.message, contains('Password reset code'));
    });

    test('resetPassword verifies recovery OTP, updates password, and clears session', () async {
      final sbUser = createDummySupabaseUser();
      fakeGoTrue.mockUser = sbUser;
      fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

      // Pre-seed a local user
      await localDataSource.saveUser(UserModel.fromSupabaseUser(sbUser));
      expect(await localDataSource.getUser(), isNotNull);

      final res = await repository.resetPassword(
        email: 'patient@medicrate.com',
        otp: '1234',
        newPassword: 'NewPassword123!',
        passwordConfirmation: 'NewPassword123!',
      );

      expect(fakeGoTrue.updateUserCalled, isTrue);
      expect(fakeGoTrue.lastUpdatedPassword, 'NewPassword123!');
      expect(fakeGoTrue.signOutCalled, isTrue);
      expect(res.message, contains('Password reset successfully'));

      // Local session must be cleared after password reset
      expect(await localDataSource.getUser(), isNull);
    });
  });

  group('4. Native Google Sign-In Tests (Direct Supabase Exchange)', () {
    late FakeGoogleSignIn fakeGoogleSignIn;
    late GoogleAuthService googleAuthService;
    late SupabaseAuthRemoteDataSource remoteDataSource;
    late AuthLocalDataSource localDataSource;
    late AuthRepository repository;

    setUp(() {
      fakeGoogleSignIn = FakeGoogleSignIn();
      googleAuthService = GoogleAuthService(
        googleSignInInstance: fakeGoogleSignIn,
      );
      remoteDataSource = SupabaseAuthRemoteDataSource(fakeSupabaseClient);
      localDataSource = AuthLocalDataSource(hiveService);
      repository = AuthRepository(
        localDataSource: localDataSource,
        supabaseRemoteDataSource: remoteDataSource,
        secureStorage: fakeSecureStorage,
        connectivityService: fakeConnectivity,
        supabaseClient: fakeSupabaseClient,
      );
    });

    test('authenticateWithGoogle returns cancelled when user dismisses account picker', () async {
      fakeGoogleSignIn.shouldThrowCancellation = true;

      final result = await googleAuthService.authenticateWithGoogle();
      expect(result.isCancelled, isTrue);
      expect(result.idToken, isNull);
    });

    test(
      'authenticateWithGoogle returns failure when ID token is empty',
      () async {
        fakeGoogleSignIn.accountToReturn = FakeGoogleSignInAccount(
          FakeGoogleSignInAuthentication(idToken: null),
        );

        final result = await googleAuthService.authenticateWithGoogle();
        expect(result.isCancelled, isFalse);
        expect(result.failureStage, 'B_ID_TOKEN_RETRIEVAL');
        expect(result.errorMessage, contains('empty or null'));
      },
    );

    test('authenticateWithGoogle returns raw Google ID token on success without Firebase exchange', () async {
      fakeGoogleSignIn.accountToReturn = FakeGoogleSignInAccount(
        FakeGoogleSignInAuthentication(idToken: 'google-raw-id-token-xyz'),
      );

      final result = await googleAuthService.authenticateWithGoogle();
      expect(result.isCancelled, isFalse);
      expect(result.failureStage, isNull);
      expect(result.idToken, 'google-raw-id-token-xyz');
      expect(
        result.firebaseIdToken,
        'google-raw-id-token-xyz',
      ); // backward compat alias
    });

    test('repository.googleLogin exchanges Google ID token with Supabase and sets Google provider', () async {
      final sbUser = createDummySupabaseUser(provider: 'google');
      fakeGoTrue.mockUser = sbUser;
      fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

      final user = await repository.googleLogin('google-raw-id-token-xyz');

      expect(fakeGoTrue.lastGoogleIdToken, 'google-raw-id-token-xyz');
      expect(user.authProvider, AuthProviderType.google);
      expect(user.email, 'patient@medicrate.com');

      // Verify cached in Hive
      final cached = await localDataSource.getUser();
      expect(cached?.authProvider, AuthProviderType.google);
    });
  });

  group('5. Riverpod AuthNotifier & Session State Tests', () {
    late ProviderContainer container;
    late AuthLocalDataSource localDataSource;
    late AuthRepository repository;
    late FakeGoogleSignIn fakeGoogleSignIn;
    late GoogleAuthService googleAuthService;

    setUp(() {
      localDataSource = AuthLocalDataSource(hiveService);
      repository = AuthRepository(
        localDataSource: localDataSource,
        supabaseRemoteDataSource: SupabaseAuthRemoteDataSource(
          fakeSupabaseClient,
        ),
        secureStorage: fakeSecureStorage,
        connectivityService: fakeConnectivity,
        supabaseClient: fakeSupabaseClient,
      );
      fakeGoogleSignIn = FakeGoogleSignIn();
      googleAuthService = GoogleAuthService(
        googleSignInInstance: fakeGoogleSignIn,
      );

      container = ProviderContainer(
        overrides: [
          hiveServiceProvider.overrideWithValue(hiveService),
          secureStorageProvider.overrideWithValue(fakeSecureStorage),
          connectivityServiceProvider.overrideWithValue(fakeConnectivity),
          supabaseClientProvider.overrideWithValue(fakeSupabaseClient),
          authRepositoryProvider.overrideWithValue(repository),
          googleAuthServiceProvider.overrideWithValue(googleAuthService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state runs checkInitialSession and restores session from Supabase', () async {
      final sbUser = createDummySupabaseUser();
      fakeGoTrue.mockUser = sbUser;
      fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

      // Wait for initialSessionReady future
      await container.read(authControllerProvider.notifier).initialSessionReady;

      final state = container.read(authControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.id, sbUser.id);
    });

    test(
      'signInWithGoogle handles user cancellation without showing error banner',
      () async {
        fakeGoogleSignIn.shouldThrowCancellation = true;

        final notifier = container.read(authControllerProvider.notifier);
        await notifier.initialSessionReady;

        final success = await notifier.signInWithGoogle();
        expect(success, isFalse);

        final state = container.read(authControllerProvider);
        expect(state.isLoading, isFalse);
        expect(state.loginError, isNull);
      },
    );

    test('signInWithGoogle authenticates and updates Riverpod state', () async {
      final sbUser = createDummySupabaseUser(provider: 'google');
      fakeGoTrue.mockUser = sbUser;
      fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);
      fakeGoogleSignIn.accountToReturn = FakeGoogleSignInAccount(
        FakeGoogleSignInAuthentication(idToken: 'valid-google-id-token'),
      );

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.initialSessionReady;

      final success = await notifier.signInWithGoogle();
      expect(success, isTrue);

      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.authProvider, AuthProviderType.google);
    });

    test(
      'onAuthStateChange signedOut event clears session state in Riverpod',
      () async {
        final sbUser = createDummySupabaseUser();
        fakeGoTrue.mockUser = sbUser;
        fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

        final notifier = container.read(authControllerProvider.notifier);
        await notifier.initialSessionReady;

        expect(container.read(authControllerProvider).isAuthenticated, isTrue);

        // Trigger signedOut auth event
        fakeGoTrue.emitAuthState(sb.AuthChangeEvent.signedOut, null);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(authControllerProvider).isAuthenticated, isFalse);
        expect(container.read(authControllerProvider).user, isNull);
      },
    );

    test(
      'signOut terminates Supabase session and clears Riverpod state',
      () async {
        final sbUser = createDummySupabaseUser();
        fakeGoTrue.mockUser = sbUser;
        fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

        final notifier = container.read(authControllerProvider.notifier);
        await notifier.initialSessionReady;

        expect(container.read(authControllerProvider).isAuthenticated, isTrue);

        await notifier.signOut();

        expect(fakeGoTrue.signOutCalled, isTrue);
        expect(container.read(authControllerProvider).isAuthenticated, isFalse);
        expect(await localDataSource.getUser(), isNull);
      },
    );
  });

  group(
    '6. Hive Clinical Data Preservation & Legacy Backend Isolation Tests',
    () {
      late AuthLocalDataSource localDataSource;
      late AuthRepository repository;

      setUp(() async {
        localDataSource = AuthLocalDataSource(hiveService);
        repository = AuthRepository(
          localDataSource: localDataSource,
          supabaseRemoteDataSource: SupabaseAuthRemoteDataSource(
            fakeSupabaseClient,
          ),
          secureStorage: fakeSecureStorage,
          connectivityService: fakeConnectivity,
          supabaseClient: fakeSupabaseClient,
        );

        // Pre-seed clinical records and profile entries in Hive
        await hiveService.userBox.put('consultation_c101', {
          'id': 'c101',
          'doctor_name': 'Dr. Sharma',
          'status': 'completed',
        });
        await hiveService.userBox.put('vital_v202', {
          'id': 'v202',
          'type': 'blood_pressure',
          'value': '120/80',
        });
        await hiveService.userBox.put('report_r303', {
          'id': 'r303',
          'title': 'Lipid Profile Report',
          'status': 'verified',
        });
        await hiveService.profileBox.put('profile_active', {
          'id': 'profile-user-1',
          'name': 'Primary Profile',
        });
        await hiveService.syncQueueBox.put('pending_mutation_1', {
          'id': 'pending_mutation_1',
          'action': 'CREATE',
          'entity': 'consultation',
        });
      });

      test('Signing out of Supabase NEVER deletes Hive clinical records or sync queues', () async {
        final sbUser = createDummySupabaseUser();
        fakeGoTrue.mockUser = sbUser;
        fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

        // Sign in
        await repository.signIn(
          email: 'patient@medicrate.com',
          password: 'Password123!',
        );

        expect(await localDataSource.getUser(), isNotNull);

        // Sign out
        await repository.signOut();

        // Auth session is cleared
        expect(await localDataSource.getUser(), isNull);
        expect(await localDataSource.isLoggedIn(), isFalse);

        // CRITICAL CHECK: Hive clinical records must remain 100% intact!
        final consultation = hiveService.userBox.get('consultation_c101');
        expect(consultation, isNotNull);
        expect(consultation?['doctor_name'], 'Dr. Sharma');
        expect(hiveService.userBox.get('vital_v202'), isNotNull);
        expect(hiveService.userBox.get('report_r303'), isNotNull);
        expect(hiveService.profileBox.get('profile_active'), isNotNull);
        expect(hiveService.syncQueueBox.get('pending_mutation_1'), isNotNull);
      });

      test(
        'Password reset NEVER deletes Hive clinical records or sync queues',
        () async {
          final sbUser = createDummySupabaseUser();
          fakeGoTrue.mockUser = sbUser;
          fakeGoTrue.mockSession = createDummySupabaseSession(user: sbUser);

          await repository.resetPassword(
            email: 'patient@medicrate.com',
            otp: '1234',
            newPassword: 'NewPassword123!',
            passwordConfirmation: 'NewPassword123!',
          );

          // Verify clinical keys survive
          expect(hiveService.userBox.get('consultation_c101'), isNotNull);
          expect(hiveService.userBox.get('vital_v202'), isNotNull);
          expect(hiveService.userBox.get('report_r303'), isNotNull);
          expect(hiveService.profileBox.get('profile_active'), isNotNull);
          expect(hiveService.syncQueueBox.get('pending_mutation_1'), isNotNull);
        },
      );

      test('Legacy Laravel sync flags remain suspended during Supabase auth operation', () {
        expect(BackgroundSyncService.isLaravelSyncSuspended, isTrue);
        expect(SyncService.isRemotePushSuspended, isTrue);
      });
    },
  );
}
