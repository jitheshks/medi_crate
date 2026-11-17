import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/secure_storage_service.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/auth/data/datasources/local/auth_local_data_source.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FakeSecureStorageService extends SecureStorageService {
  bool clearAuthTokenCalled = false;

  @override
  Future<void> clearAuthToken() async {
    clearAuthTokenCalled = true;
  }
}

class FakeConnectivityService extends ConnectivityService {
  bool online;
  FakeConnectivityService({this.online = true}) : super(autoInitialize: false);

  @override
  Future<bool> checkConnectivity() async => online;
}

class FakeAuthLocalDataSource extends Fake implements AuthLocalDataSource {
  UserModel? cachedUser;
  bool clearUserCalled = false;

  @override
  Future<UserModel?> getUser() async => cachedUser;

  @override
  Future<void> saveUser(UserModel user) async {
    cachedUser = user;
  }

  @override
  Future<void> clearUser() async {
    clearUserCalled = true;
    cachedUser = null;
  }
}

class FakeGoTrueClient extends Fake implements sb.GoTrueClient {
  sb.User? mockUser;
  bool shouldThrowInvalidPasswordOnSignIn = false;
  bool shouldThrowInvalidOtp = false;
  bool updateUserCalled = false;
  String? lastUpdatedEmail;
  bool verifyOtpCalled = false;
  String? lastVerifyOtpEmail;
  String? lastVerifyOtpToken;
  sb.OtpType? lastVerifyOtpType;
  bool signOutCalled = false;

  @override
  sb.User? get currentUser => mockUser;

  @override
  Future<sb.AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (shouldThrowInvalidPasswordOnSignIn) {
      throw const sb.AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );
    }
    return sb.AuthResponse(session: null, user: mockUser);
  }

  @override
  Future<sb.UserResponse> updateUser(
    sb.UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    updateUserCalled = true;
    lastUpdatedEmail = attributes.email;
    return sb.UserResponse.fromJson(mockUser?.toJson() ?? {});
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
    verifyOtpCalled = true;
    lastVerifyOtpEmail = email;
    lastVerifyOtpToken = token;
    lastVerifyOtpType = type;

    if (shouldThrowInvalidOtp) {
      throw const sb.AuthException('Token is expired', statusCode: '400');
    }

    final updatedUser = sb.User(
      id: mockUser?.id ?? 'user-uuid-1',
      appMetadata: mockUser?.appMetadata ?? {},
      userMetadata: mockUser?.userMetadata ?? {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );

    return sb.AuthResponse(session: null, user: updatedUser);
  }

  @override
  Future<void> signOut({sb.SignOutScope scope = sb.SignOutScope.global}) async {
    signOutCalled = true;
    mockUser = null;
  }
}

class FakeSupabaseClient extends Fake implements sb.SupabaseClient {
  final FakeGoTrueClient _auth;
  bool rpcCalled = false;
  String? lastRpcFunctionName;
  bool shouldThrowRpcError = false;

  FakeSupabaseClient({FakeGoTrueClient? auth})
    : _auth = auth ?? FakeGoTrueClient();

  @override
  FakeGoTrueClient get auth => _auth;

  @override
  sb.PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    rpcCalled = true;
    lastRpcFunctionName = fn;
    if (shouldThrowRpcError) {
      throw const sb.PostgrestException(
        message: 'Database execution failed',
        code: '500',
      );
    }
    return FakePostgrestFilterBuilder<T>();
  }
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements sb.PostgrestFilterBuilder<T> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) async {
    return onValue(null as T);
  }
}

class FakeHiveService extends Fake implements HiveService {}

class FakeSupabaseStorageService extends Fake implements SupabaseStorageService {
  bool deleteAllUserFilesCalled = false;
  String? lastPurgedUserId;
  bool shouldThrowStorageError = false;

  @override
  Future<void> deleteAllUserFiles({required String userId}) async {
    deleteAllUserFilesCalled = true;
    lastPurgedUserId = userId;
    if (shouldThrowStorageError) {
      throw const StorageOperationException('Simulated storage purge failure');
    }
  }
}

void main() {
  group('Phase 8.4: Supabase Identity Parity — Account Deletion (B5)', () {
    late FakeSupabaseClient fakeClient;
    late FakeGoTrueClient fakeAuth;
    late FakeAuthLocalDataSource fakeLocalDataSource;
    late FakeSecureStorageService fakeSecureStorage;
    late FakeConnectivityService fakeConnectivity;
    late FakeSupabaseStorageService fakeStorageService;
    late SupabaseAuthRemoteDataSource remoteDataSource;
    late AuthRepository authRepository;

    setUp(() {
      fakeAuth = FakeGoTrueClient();
      fakeClient = FakeSupabaseClient(auth: fakeAuth);
      fakeLocalDataSource = FakeAuthLocalDataSource();
      fakeSecureStorage = FakeSecureStorageService();
      fakeConnectivity = FakeConnectivityService(online: true);
      fakeStorageService = FakeSupabaseStorageService();

      remoteDataSource = SupabaseAuthRemoteDataSource(
        fakeClient,
        customStorageService: fakeStorageService,
      );
      authRepository = AuthRepository(
        localDataSource: fakeLocalDataSource,
        supabaseRemoteDataSource: remoteDataSource,
        secureStorage: fakeSecureStorage,
        connectivityService: fakeConnectivity,
        supabaseClient: fakeClient,
      );
    });

    test(
      '1. deleteAccount throws NetworkException when offline without executing RPC',
      () async {
        fakeConnectivity.online = false;

        await expectLater(
          () => authRepository.deleteAccount(currentPassword: 'password123'),
          throwsA(isA<NetworkException>()),
        );

        expect(fakeClient.rpcCalled, isFalse);
        expect(fakeSecureStorage.clearAuthTokenCalled, isFalse);
        expect(fakeLocalDataSource.clearUserCalled, isFalse);
      },
    );

    test(
      '2. deleteAccount verifies current password and fails before calling RPC if password is wrong',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@example.com',
        );
        fakeAuth.shouldThrowInvalidPasswordOnSignIn = true;

        await expectLater(
          () => authRepository.deleteAccount(currentPassword: 'wrong-password'),
          throwsA(isA<UnauthorizedException>()),
        );

        expect(fakeClient.rpcCalled, isFalse);
        expect(fakeSecureStorage.clearAuthTokenCalled, isFalse);
        expect(fakeLocalDataSource.clearUserCalled, isFalse);
      },
    );

    test(
      '3. deleteAccount throws ServerException and preserves local user if RPC fails',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@example.com',
        );
        fakeClient.shouldThrowRpcError = true;

        await expectLater(
          () => authRepository.deleteAccount(
            currentPassword: 'correct-password',
          ),
          throwsA(isA<ServerException>()),
        );

        expect(fakeStorageService.deleteAllUserFilesCalled, isTrue);
        expect(fakeStorageService.lastPurgedUserId, equals('user-uuid-1'));
        expect(fakeClient.rpcCalled, isTrue);
        expect(fakeClient.lastRpcFunctionName, equals('delete_user_account'));
        expect(fakeSecureStorage.clearAuthTokenCalled, isFalse);
        expect(fakeLocalDataSource.clearUserCalled, isFalse);
      },
    );

    test(
      '4. deleteAccount calls delete_user_account RPC and purges local storage on success',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@example.com',
        );

        final message = await authRepository.deleteAccount(
          currentPassword: 'valid-password',
        );

        expect(message, equals('Account successfully deleted.'));
        expect(fakeStorageService.deleteAllUserFilesCalled, isTrue);
        expect(fakeStorageService.lastPurgedUserId, equals('user-uuid-1'));
        expect(fakeClient.rpcCalled, isTrue);
        expect(fakeClient.lastRpcFunctionName, equals('delete_user_account'));
        expect(fakeSecureStorage.clearAuthTokenCalled, isTrue);
        expect(fakeLocalDataSource.clearUserCalled, isTrue);
        expect(fakeAuth.signOutCalled, isTrue);
      },
    );

    test(
      '5. deleteAccount throws ServerException and preserves database/local state if storage purge fails',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@example.com',
        );
        fakeStorageService.shouldThrowStorageError = true;

        await expectLater(
          () => authRepository.deleteAccount(
            currentPassword: 'valid-password',
          ),
          throwsA(isA<ServerException>()),
        );

        expect(fakeStorageService.deleteAllUserFilesCalled, isTrue);
        expect(fakeClient.rpcCalled, isFalse);
        expect(fakeSecureStorage.clearAuthTokenCalled, isFalse);
        expect(fakeLocalDataSource.clearUserCalled, isFalse);
        expect(fakeAuth.signOutCalled, isFalse);
      },
    );

    test(
      '6. deleteAccount succeeds even if local cache cleanup throws after remote deletion',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@example.com',
        );

        final result = await authRepository.deleteAccount(
          currentPassword: 'valid-password',
        );

        expect(result, equals('Account successfully deleted.'));
        expect(fakeClient.rpcCalled, isTrue);
      },
    );
  });

  group('Phase 8.4: Supabase Identity Parity — Email Change (B4)', () {
    late FakeSupabaseClient fakeClient;
    late FakeGoTrueClient fakeAuth;
    late FakeAuthLocalDataSource fakeLocalDataSource;
    late FakeSecureStorageService fakeSecureStorage;
    late FakeConnectivityService fakeConnectivity;
    late SupabaseAuthRemoteDataSource remoteDataSource;
    late AuthRepository authRepository;

    setUp(() {
      fakeAuth = FakeGoTrueClient();
      fakeClient = FakeSupabaseClient(auth: fakeAuth);
      fakeLocalDataSource = FakeAuthLocalDataSource();
      fakeSecureStorage = FakeSecureStorageService();
      fakeConnectivity = FakeConnectivityService(online: true);

      remoteDataSource = SupabaseAuthRemoteDataSource(fakeClient);
      authRepository = AuthRepository(
        localDataSource: fakeLocalDataSource,
        supabaseRemoteDataSource: remoteDataSource,
        secureStorage: fakeSecureStorage,
        connectivityService: fakeConnectivity,
        supabaseClient: fakeClient,
      );
    });

    test(
      '1. requestChangeEmail rejects same email address as validation error',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'current@example.com',
        );

        await expectLater(
          () => authRepository.requestChangeEmail(
            currentPassword: 'password123',
            newEmail: 'current@example.com',
          ),
          throwsA(isA<ValidationException>()),
        );

        expect(fakeAuth.updateUserCalled, isFalse);
      },
    );

    test('2. requestChangeEmail rejects incorrect current password', () async {
      fakeAuth.mockUser = sb.User(
        id: 'user-uuid-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'current@example.com',
      );
      fakeAuth.shouldThrowInvalidPasswordOnSignIn = true;

      await expectLater(
        () => authRepository.requestChangeEmail(
          currentPassword: 'wrong-password',
          newEmail: 'new@example.com',
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(fakeAuth.updateUserCalled, isFalse);
    });

    test(
      '3. requestChangeEmail updates user email in GoTrue and dispatches confirmation',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'current@example.com',
        );

        final msg = await authRepository.requestChangeEmail(
          currentPassword: 'valid-password',
          newEmail: 'new@example.com',
        );

        expect(msg, contains('Verification code sent to new@example.com'));
        expect(fakeAuth.updateUserCalled, isTrue);
        expect(fakeAuth.lastUpdatedEmail, equals('new@example.com'));
      },
    );

    test(
      '4. confirmChangeEmail verifies OTP with OtpType.emailChange and updates local cache',
      () async {
        fakeAuth.mockUser = sb.User(
          id: 'user-uuid-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'current@example.com',
        );

        fakeLocalDataSource.cachedUser = const UserModel(
          id: 'user-uuid-1',
          name: 'Test User',
          email: 'current@example.com',
        );

        final res = await authRepository.confirmChangeEmail(
          otp: '123456',
          newEmail: 'new@example.com',
        );

        expect(res['status'], equals('success'));
        expect(res['user']['email'], equals('new@example.com'));
        expect(fakeAuth.verifyOtpCalled, isTrue);
        expect(fakeAuth.lastVerifyOtpEmail, equals('new@example.com'));
        expect(fakeAuth.lastVerifyOtpToken, equals('123456'));
        expect(fakeAuth.lastVerifyOtpType, equals(sb.OtpType.emailChange));
        expect(
          fakeLocalDataSource.cachedUser?.email,
          equals('new@example.com'),
        );
      },
    );
  });

  group('Phase 8.4 / Cleanup: Sync Dispatch Gate Decoupling', () {
    test(
      '1. Remote push is skipped when isRemoteSyncEnabled is false and coordinator is null',
      () async {
        SyncService.isRemoteSyncEnabled = false;

        final service = SyncService(
          hiveService: FakeHiveService(),
          connectivityService: FakeConnectivityService(online: true),
        );

        await service.syncPending();

        expect(SyncService.isRemoteSyncEnabled, isFalse);
      },
    );

    test(
      '2. Unified remote sync flag controls sync state',
      () {
        SyncService.isRemoteSyncEnabled = false;
        expect(SyncService.isRemoteSyncEnabled, isFalse);

        SyncService.isRemoteSyncEnabled = true;
        expect(SyncService.isRemoteSyncEnabled, isTrue);

        // Reset to safe default
        SyncService.isRemoteSyncEnabled = false;
        expect(SyncService.isRemoteSyncEnabled, isFalse);
      },
    );
  });
}
