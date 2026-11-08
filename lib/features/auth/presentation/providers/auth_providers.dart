import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../profile/data/datasources/remote/user_remote_data_source.dart';
import '../../data/datasources/local/auth_local_data_source.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/apple_auth_service.dart';
import '../../data/services/google_auth_service.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';

export 'auth_notifier.dart';
export 'auth_state.dart';

final hiveServiceProvider = Provider<HiveService>((ref) => HiveService());
final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.onConnectivityChanged;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  final service = SyncService(
    hiveService: hive,
    connectivityService: connectivity,
    apiClient: apiClient,
    onSyncCompleted: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient(
    secureStorage: secureStorage,
    onSessionExpired: () {
      // Option D: A legacy Laravel 401 represents legacy backend dormancy,
      // NOT an application session expiration. Decoupled from AuthNotifier
      // so Supabase sessions are never terminated by legacy Laravel responses.
      developer.log(
        '⚠️ [ApiClient] Legacy Laravel 401 intercepted. Application session preserved.',
        name: 'MediCrate.Auth',
      );
    },
  );
});

final Provider<GoogleAuthService> googleAuthServiceProvider =
    Provider<GoogleAuthService>((ref) {
      return GoogleAuthService();
    });

final Provider<AppleAuthService> appleAuthServiceProvider =
    Provider<AppleAuthService>((ref) {
      return AppleAuthService();
    });

final Provider<AuthLocalDataSource> authLocalDataSourceProvider =
    Provider<AuthLocalDataSource>((ref) {
      final hive = ref.watch(hiveServiceProvider);
      return AuthLocalDataSource(hive);
    });

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return AuthRemoteDataSource(apiClient);
    });

final Provider<UserRemoteDataSource> userRemoteDataSourceProvider =
    Provider<UserRemoteDataSource>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return UserRemoteDataSource(apiClient: apiClient);
    });

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      return AuthRepository(
        localDataSource: ref.watch(authLocalDataSourceProvider),
        remoteDataSource: ref.watch(authRemoteDataSourceProvider),
        secureStorage: ref.watch(secureStorageProvider),
        connectivityService: ref.watch(connectivityServiceProvider),
        userRemoteDataSource: ref.watch(userRemoteDataSourceProvider),
      );
    });

final NotifierProvider<AuthNotifier, AuthState> authControllerProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Controls whether the OTP screen starts the periodic countdown timer.
/// Enabled by default in production; can be overridden in widget tests.
final otpTimerEnabledProvider = Provider<bool>((ref) => true);
