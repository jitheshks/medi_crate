import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/sync/supabase_sync_coordinator.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../data/datasources/local/auth_local_data_source.dart';
import '../../data/datasources/remote/supabase_auth_remote_data_source.dart';
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

final supabaseSyncCoordinatorProvider =
    Provider<SupabaseSyncCoordinator>((ref) {
      final hive = ref.watch(hiveServiceProvider);
      final client = ref.watch(supabaseClientProvider);
      return SupabaseSyncCoordinator(
        hiveService: hive,
        customClient: client,
      );
    });

final syncServiceProvider = Provider<SyncService>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final supabaseSyncCoordinator = ref.watch(supabaseSyncCoordinatorProvider);
  final service = SyncService(
    hiveService: hive,
    connectivityService: connectivity,
    customSupabaseSyncCoordinator: supabaseSyncCoordinator,
    onSyncCompleted: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
  ref.onDispose(() => service.dispose());
  return service;
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

final Provider<sb.SupabaseClient> supabaseClientProvider =
    Provider<sb.SupabaseClient>((ref) {
      return SupabaseConfig.client;
    });

final Provider<SupabaseAuthRemoteDataSource>
supabaseAuthRemoteDataSourceProvider = Provider<SupabaseAuthRemoteDataSource>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRemoteDataSource(client);
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      return AuthRepository(
        localDataSource: ref.watch(authLocalDataSourceProvider),
        supabaseRemoteDataSource: ref.watch(
          supabaseAuthRemoteDataSourceProvider,
        ),
        secureStorage: ref.watch(secureStorageProvider),
        connectivityService: ref.watch(connectivityServiceProvider),
        supabaseClient: ref.watch(supabaseClientProvider),
      );
    });

final NotifierProvider<AuthNotifier, AuthState> authControllerProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Controls whether the OTP screen starts the periodic countdown timer.
/// Enabled by default in production; can be overridden in widget tests.
final otpTimerEnabledProvider = Provider<bool>((ref) => true);
