import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../api/ssl_security_context.dart';
import '../connectivity/connectivity_service.dart';
import '../storage/hive_service.dart';
import '../storage/secure_storage_service.dart';
import 'background_clinical_pull.dart';
import 'sync_lock.dart';
import 'sync_service.dart';

/// Top-level callback dispatcher required by WorkManager.
/// Must be annotated with `@pragma('vm:entry-point')` for AOT/tree-shaking safety.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    return await BackgroundSyncService.executeBackgroundTask(taskName);
  });
}

/// BackgroundSyncService orchestrates headless background synchronization using WorkManager.
class BackgroundSyncService {
  static const String oneOffSyncTaskId = 'com.medivalut.sync.oneoff';
  static const String oneOffSyncTaskName = 'mediCrateOneOffSync';

  static const String periodicSyncTaskId = 'com.medivalut.sync.periodic';
  static const String periodicSyncTaskName = 'mediCratePeriodicSync';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initializes the WorkManager plugin and registers periodic safety-net synchronization.
  /// Can be safely invoked during app startup.
  static Future<void> initialize({Workmanager? customWorkmanager}) async {
    // Idempotent: a dev hot-restart re-runs main(); a second real init is a
    // no-op anyway (registerPeriodicTask uses ExistingPeriodicWorkPolicy.keep).
    if (_isInitialized && customWorkmanager == null) return;
    if (customWorkmanager != null ||
        (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
      try {
        final wm = customWorkmanager ?? Workmanager();
        await wm.initialize(callbackDispatcher);
        _isInitialized = true;

        // Register periodic background sync safety net (every 15 minutes on Android)
        await wm.registerPeriodicTask(
          periodicSyncTaskId,
          periodicSyncTaskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } catch (e) {
        debugPrint(
          '[BackgroundSyncService] WorkManager initialization skipped or failed: $e',
        );
      }
    }
  }

  /// Schedules a one-time background sync task when offline mutations are queued.
  /// Uses ExistingWorkPolicy.keep to prevent redundant duplicate workers.
  static Future<void> scheduleOneTimeSync({
    Workmanager? customWorkmanager,
  }) async {
    if (customWorkmanager != null ||
        (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
      try {
        final wm = customWorkmanager ?? Workmanager();
        await wm.registerOneOffTask(
          oneOffSyncTaskId,
          oneOffSyncTaskName,
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.keep,
        );
      } catch (e) {
        debugPrint(
          '[BackgroundSyncService] Failed to schedule one-time sync: $e',
        );
      }
    }
  }

  /// Headless execution logic invoked by WorkManager in the background isolate.
  ///
  /// Full cycle (Phase 5): claim the cross-context [SyncLock] lease once, then
  ///   1. push pending mutations  ([SyncService.syncPending], reusing the lease)
  ///   2. pull the 7 clinical domains -> Hive  ([BackgroundClinicalPull])
  /// then release the lease and ask WorkManager to retry if a transient push
  /// failure remains. The foreground app picks up the merged Hive state via the
  /// existing `clinicalCacheRevisionProvider` when it next resumes — this
  /// isolate never touches Riverpod.
  static Future<bool> executeBackgroundTask(
    String taskName, {
    HiveService? customHiveService,
    SecureStorageService? customSecureStorage,
    ApiClient? customApiClient,
    ConnectivityService? customConnectivityService,
    SyncService? customSyncService,
    BackgroundClinicalPull? customBackgroundPull,
  }) async {
    debugPrint('[BackgroundSyncService] Executing background task: $taskName');

    try {
      // 0. Ensure Flutter binding & TLS context are initialized in the background isolate
      WidgetsFlutterBinding.ensureInitialized();
      if (!SslSecurityContext.isInitialized) {
        try {
          await SslSecurityContext.initialize();
        } catch (_) {}
      }

      // 1. Initialize Hive inside the background isolate if not already initialized
      if (customHiveService == null) {
        await HiveService.init();
      }

      final hiveService = customHiveService ?? HiveService();
      final syncBox = hiveService.syncQueueBox;

      // 2. Construct headless services & API client for background execution
      if (!dotenv.isInitialized) {
        try {
          await dotenv.load(fileName: ".env");
        } catch (_) {}
      }
      final secureStorage = customSecureStorage ?? SecureStorageService();
      final apiClient =
          customApiClient ?? ApiClient(secureStorage: secureStorage);
      final connectivity = customConnectivityService ?? ConnectivityService();

      final syncService =
          customSyncService ??
          SyncService(
            hiveService: hiveService,
            connectivityService: connectivity,
            apiClient: apiClient,
          );
      final backgroundPull =
          customBackgroundPull ?? const BackgroundClinicalPull();

      // 3. Claim the cross-context lease for the whole push+pull cycle. If the
      //    foreground app already holds it, it is doing the same work now —
      //    yield and let WorkManager reschedule.
      final lock = SyncLock(hiveService.settingsBox);
      final leaseToken = await lock.tryAcquire();
      if (leaseToken == null) {
        debugPrint(
          '[BackgroundSyncService] Sync lease held by foreground; skipping this run.',
        );
        return true;
      }

      try {
        // 4. PUSH pending mutations first (dependency ordering + server-id
        //    backfill + queue cleanup all happen here).
        await syncService.syncPending(force: true, lockAlreadyHeld: true);

        // 5. PULL server -> Hive for every known profile, reusing the existing
        //    repository pull + merge (PendingMutationGuard still applies).
        await backgroundPull.run(
          hiveService: hiveService,
          apiClient: apiClient,
          connectivityService: connectivity,
          secureStorage: secureStorage,
        );
      } finally {
        await lock.release(leaseToken);
      }

      // 6. Evaluate remaining queue items. If any item failed with a transient
      //    error (retryCount < 5), request a WorkManager retry (return false).
      bool hasTransientFailures = false;
      for (final itemRaw in syncBox.values) {
        final status = itemRaw['status']?.toString();
        final retryCount = itemRaw['retryCount'] as int? ?? 0;
        if (status == 'failed' && retryCount < 5) {
          hasTransientFailures = true;
          break;
        }
      }

      return !hasTransientFailures;
    } catch (e, stack) {
      debugPrint(
        '[BackgroundSyncService] Background sync task failed: $e\n$stack',
      );
      return false;
    }
  }
}
