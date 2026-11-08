import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/api/api_client.dart';
import 'package:medi_crate/core/api/dio_interceptor.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/storage/secure_storage_service.dart';
import 'package:medi_crate/core/sync/background_clinical_pull.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/consultations/data/repositories/consultation_repository.dart';
import 'package:medi_crate/features/profile/data/datasources/local/profile_local_data_source.dart';
import 'package:medi_crate/features/reports/data/models/report_model.dart';
import 'package:medi_crate/features/reports/data/repositories/report_repository.dart';
import 'package:medi_crate/features/vitals/data/repositories/measurement_repository.dart';
import 'package:workmanager/workmanager.dart';

class FakeSecureStorageService extends SecureStorageService {
  String? token;
  String? refreshToken;

  FakeSecureStorageService({this.token, this.refreshToken});

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

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(online);
}

class FakeWorkmanager implements Workmanager {
  final List<String> cancelledTasks = [];
  final List<String> registeredPeriodicTasks = [];
  final List<String> registeredOneOffTasks = [];
  bool initialized = false;

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    initialized = true;
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelledTasks.add(uniqueName);
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    registeredPeriodicTasks.add(uniqueName);
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ExistingWorkPolicy? existingWorkPolicy,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    bool? expedited,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    registeredOneOffTasks.add(uniqueName);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medi_crate_iso_test_');
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
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Phase 3B.1 Legacy Backend Isolation & Offline Protection', () {
    test('1. Laravel 401 intercepted by ApiClient does not clear Riverpod authControllerProvider session state', () async {
      final fakeStorage = FakeSecureStorageService(token: 'legacy_token');
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(online: true),
          ),
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
      );
      addTearDown(container.dispose);

      // Manually prime auth state to authenticated
      final authNotifier = container.read(authControllerProvider.notifier);
      await authNotifier.initialSessionReady;
      authNotifier.state = const AuthState(
        isAuthenticated: true,
        user: UserModel(
          id: 'usr_1',
          email: 'patient@example.com',
          name: 'Jane Doe',
        ),
      );

      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      // Retrieve ApiClient configured via apiClientProvider
      final apiClient = container.read(apiClientProvider);

      // Verify onSessionExpired callback is present but decoupled from AuthNotifier
      expect(apiClient.onSessionExpired, isNotNull);
      apiClient.onSessionExpired!();

      // Application session must remain fully preserved and active
      final stateAfter = container.read(authControllerProvider);
      expect(stateAfter.isAuthenticated, isTrue);
      expect(stateAfter.user?.email, equals('patient@example.com'));
      expect(stateAfter.sessionError, isNull);
    });

    test('2. AuthInterceptor suppresses and strips Supabase JWTs from request headers', () async {
      const supabaseJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.'
          'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      const legacySanctumToken = '42|sanctum_hashed_token_string_here';

      // 2a: isSupabaseJwt identification
      expect(AuthInterceptor.isSupabaseJwt(supabaseJwt), isTrue);
      expect(AuthInterceptor.isSupabaseJwt(legacySanctumToken), isFalse);
      expect(AuthInterceptor.isSupabaseJwt('opaque_token_string'), isFalse);
      expect(AuthInterceptor.isSupabaseJwt(''), isFalse);
      expect(AuthInterceptor.isSupabaseJwt('   '), isFalse);

      // 2b: Suppress Supabase JWT stored in secure storage from legacy requests
      final interceptorWithSupabase = AuthInterceptor(
        secureStorage: FakeSecureStorageService(token: supabaseJwt),
        apiKey: 'test-api-key',
      );
      final protectedOptions = RequestOptions(path: '/api/v1/consultations');
      await interceptorWithSupabase.onRequest(
        protectedOptions,
        RequestInterceptorHandler(),
      );
      expect(protectedOptions.headers.containsKey('Authorization'), isFalse);
      expect(protectedOptions.headers['x-api-key'], equals('test-api-key'));

      // 2c: Strip Supabase JWT if explicitly injected into Authorization header
      final optionsWithExistingJwt = RequestOptions(
        path: '/api/v1/medical-records',
        headers: {'Authorization': 'Bearer $supabaseJwt'},
      );
      await interceptorWithSupabase.onRequest(
        optionsWithExistingJwt,
        RequestInterceptorHandler(),
      );
      expect(
        optionsWithExistingJwt.headers.containsKey('Authorization'),
        isFalse,
      );

      // 2d: Legacy Sanctum tokens are safely attached
      final interceptorWithSanctum = AuthInterceptor(
        secureStorage: FakeSecureStorageService(token: legacySanctumToken),
        apiKey: 'test-api-key',
      );
      final sanctumOptions = RequestOptions(path: '/api/v1/consultations');
      await interceptorWithSanctum.onRequest(
        sanctumOptions,
        RequestInterceptorHandler(),
      );
      expect(
        sanctumOptions.headers['Authorization'],
        equals('Bearer $legacySanctumToken'),
      );
    });

    test('3. BackgroundSyncService.isLaravelSyncSuspended is true and BackgroundClinicalPull skips remote pulls', () async {
      expect(BackgroundSyncService.isLaravelSyncSuspended, isTrue);

      var pullerInvoked = false;
      const pull = BackgroundClinicalPull();

      await pull.run(
        hiveService: hiveService,
        apiClient: ApiClient(secureStorage: FakeSecureStorageService()),
        connectivityService: FakeConnectivityService(online: true),
        secureStorage: FakeSecureStorageService(token: 'active_session_token'),
        pullersFor: (profileId) {
          pullerInvoked = true;
          return [];
        },
      );

      expect(pullerInvoked, isFalse);
    });

    test('4. SyncService.syncPending() when isRemotePushSuspended is true preserves queue items untouched', () async {
      expect(SyncService.isRemotePushSuspended, isTrue);

      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: FakeConnectivityService(online: true),
      );

      final offlineId = 'consultation_${DateTime.now().microsecondsSinceEpoch}';
      final queueItem = SyncQueueItem(
        id: 'queue_mutation_101',
        entity: 'consultations',
        operation: 'create',
        payload: {
          'id': offlineId,
          'client_uuid': 'c-uuid-101',
          'title': 'Cardiology Checkup',
        },
        retryCount: 1,
        createdAt: DateTime(2026, 11, 8, 12, 0),
      );

      await syncService.addToQueue(queueItem);
      expect(hiveService.syncQueueBox.length, equals(1));

      // Attempt push synchronization
      await syncService.syncPending(force: true);

      // Queue must remain completely intact with original payload and retryCount
      expect(hiveService.syncQueueBox.length, equals(1));
      final stored = hiveService.syncQueueBox.get(
        hiveService.syncQueueBox.keys.first,
      );
      expect(stored, isNotNull);
      expect(stored!['id'], equals('queue_mutation_101'));
      expect(stored['operation'], equals('create'));
      expect(stored['retryCount'] ?? stored['retry_count'], equals(1));
      expect(stored['payload']['client_uuid'], equals('c-uuid-101'));
    });

    test('5. Local clinical CRUD operations succeed offline and persist to userBox with queue items created', () async {
      final syncService = SyncService(
        hiveService: hiveService,
        connectivityService: FakeConnectivityService(online: false),
      );

      // Seed profile in profileBox
      await hiveService.profileBox.put('prof_test_1', {
        'id': 'prof_test_1',
        'profile_id': 'prof_test_1',
        'server_profile_id': 10,
        'owner_user_id': 'user_test',
        'first_name': 'Sarah',
        'last_name': 'Connor',
        'full_name': 'Sarah Connor',
        'relationship': 'Self',
        'is_primary': true,
      });

      // 5a: Consultation local CRUD
      final consultationRepo = ConsultationRepository(
        hiveService: hiveService,
        syncService: syncService,
        connectivityService: FakeConnectivityService(online: false),
      );

      final savedConsultation = await consultationRepo.saveConsultation(
        'prof_test_1',
        {
          'id': 'consultation_555',
          'doctor_name': 'Dr. Silberman',
          'diagnosis': 'Stress reaction',
        },
      );

      expect(savedConsultation['id'], equals('consultation_555'));
      expect(hiveService.userBox.containsKey('consultation_555'), isTrue);
      final consultations = await consultationRepo.getConsultations(
        'prof_test_1',
      );
      expect(consultations.any((c) => c['id'] == 'consultation_555'), isTrue);

      // 5b: Vitals local CRUD
      final vitalsRepo = MeasurementRepository(
        hiveService: hiveService,
        syncService: syncService,
        connectivityService: FakeConnectivityService(online: false),
      );

      final savedMeasurement = await vitalsRepo.saveMeasurement('prof_test_1', {
        'id': 'measurement_444',
        'type': 'heart_rate',
        'heart_rate': 72,
      });

      expect(savedMeasurement['id'], equals('measurement_444'));
      expect(hiveService.userBox.containsKey('measurement_444'), isTrue);
      final measurements = await vitalsRepo.getMeasurements('prof_test_1');
      expect(measurements.any((m) => m['id'] == 'measurement_444'), isTrue);

      // 5c: Report local CRUD
      final reportRepo = ReportRepository(
        hiveService: hiveService,
        syncService: syncService,
        connectivityService: FakeConnectivityService(online: false),
      );

      final savedReport = await reportRepo.saveReport(
        'prof_test_1',
        ReportModel(
          id: 'report_333',
          profileId: 'prof_test_1',
          title: 'Holter Monitor ECG',
          category: 'Cardiology',
          date: DateTime(2026, 11, 8),
        ),
      );

      expect(savedReport.id, equals('report_333'));
      expect(hiveService.userBox.containsKey('report_333'), isTrue);
      final fetchedReport = await reportRepo.getReportById(
        'prof_test_1',
        'report_333',
      );
      expect(fetchedReport, isNotNull);
      expect(fetchedReport!.title, equals('Holter Monitor ECG'));

      // Verify syncQueueBox has captured all 3 offline mutations
      expect(hiveService.syncQueueBox.length, equals(3));
    });

    test('6. ProfileLocalDataSource.getProfilesForUser("") returns empty list [] when owner ID is empty', () async {
      final profileDataSource = ProfileLocalDataSource(
        hiveService: hiveService,
      );

      await hiveService.profileBox.put('profile_userA_1', {
        'id': 'profile_userA_1',
        'profile_id': 'profile_userA_1',
        'server_profile_id': 1,
        'owner_user_id': 'user_A',
        'first_name': 'Alice',
        'last_name': 'Smith',
        'full_name': 'Alice Smith',
        'relationship': 'Self',
        'client_uuid': 'uuid-alice-1',
        'is_primary': true,
      });
      await hiveService.profileBox.put('profile_userB_1', {
        'id': 'profile_userB_1',
        'profile_id': 'profile_userB_1',
        'server_profile_id': 2,
        'owner_user_id': 'user_B',
        'first_name': 'Bob',
        'last_name': 'Jones',
        'full_name': 'Bob Jones',
        'relationship': 'Self',
        'client_uuid': 'uuid-bob-1',
        'is_primary': true,
      });

      // Empty or whitespace ownerUserId must return empty list (prevents multi-tenant leakage)
      expect(await profileDataSource.getProfilesForUser(''), isEmpty);
      expect(await profileDataSource.getProfilesForUser('   '), isEmpty);
      expect(await profileDataSource.getProfileByServerId(1, ''), isNull);
      expect(await profileDataSource.getProfileByServerId(1, '   '), isNull);
      expect(
        await profileDataSource.getProfileByClientUuid('uuid-alice-1', ''),
        isNull,
      );
      expect(
        await profileDataSource.getProfileByClientUuid('uuid-alice-1', '   '),
        isNull,
      );

      // Legitimate owner returns only their own profiles
      final aliceProfiles = await profileDataSource.getProfilesForUser(
        'user_A',
      );
      expect(aliceProfiles.length, equals(1));
      expect(aliceProfiles.first.profileId, equals('profile_userA_1'));
      expect(aliceProfiles.first.fullName, equals('Alice Smith'));

      final bobProfiles = await profileDataSource.getProfilesForUser('user_B');
      expect(bobProfiles.length, equals(1));
      expect(bobProfiles.first.profileId, equals('profile_userB_1'));
    });

    test('7. Calling BackgroundSyncService.initialize repeatedly cancels active tasks and does not register periodicSyncTaskId', () async {
      final fakeWm1 = FakeWorkmanager();
      await BackgroundSyncService.initialize(customWorkmanager: fakeWm1);

      expect(
        fakeWm1.cancelledTasks,
        containsAll([
          BackgroundSyncService.legacyPeriodicSyncTaskId,
          BackgroundSyncService.legacyOneOffSyncTaskId,
          BackgroundSyncService.periodicSyncTaskId,
          BackgroundSyncService.oneOffSyncTaskId,
        ]),
      );
      expect(fakeWm1.registeredPeriodicTasks, isEmpty);
      expect(fakeWm1.registeredOneOffTasks, isEmpty);

      // Repeated initialization
      final fakeWm2 = FakeWorkmanager();
      await BackgroundSyncService.initialize(customWorkmanager: fakeWm2);

      expect(
        fakeWm2.cancelledTasks,
        containsAll([
          BackgroundSyncService.legacyPeriodicSyncTaskId,
          BackgroundSyncService.legacyOneOffSyncTaskId,
          BackgroundSyncService.periodicSyncTaskId,
          BackgroundSyncService.oneOffSyncTaskId,
        ]),
      );
      expect(fakeWm2.registeredPeriodicTasks, isEmpty);
      expect(fakeWm2.registeredOneOffTasks, isEmpty);
    });
  });
}
