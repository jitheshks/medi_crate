import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/theme/app_theme.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/datasources/local/profile_local_data_source.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/data/repositories/profile_repository.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/profile/presentation/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _FakeConnectivityService implements ConnectivityService {
  bool isOnline = true;

  @override
  Future<bool> checkConnectivity() async => isOnline;

  @override
  Future<bool> checkInternetAccess() async => isOnline;

  @override
  Future<List<ConnectivityResult>> getTransports() async =>
      isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none];

  @override
  Future<NetworkStatusModel> getDetailedStatus() async => NetworkStatusModel(
        transports:
            isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
        hasInternet: isOnline,
      );

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isOnline);

  @override
  void dispose() {}
}

class _TrackingSupabaseProfileRemoteDataSource
    extends SupabaseProfileRemoteDataSource {
  final List<ProfileModel> remoteProfiles = [];
  ProfileModel? lastUpdatedProfile;
  int updateCallCount = 0;

  @override
  Future<List<ProfileModel>> fetchProfiles({
    required String ownerUserId,
    bool includeArchived = false,
  }) async {
    return remoteProfiles.where((p) {
      if (p.ownerUserId != ownerUserId) return false;
      if (!includeArchived && p.isArchived) return false;
      return true;
    }).toList();
  }

  @override
  Future<ProfileModel> updateProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    updateCallCount++;
    lastUpdatedProfile = profile;
    final index = remoteProfiles.indexWhere(
      (p) => p.profileId == profile.profileId && p.ownerUserId == ownerUserId,
    );
    if (index >= 0) {
      remoteProfiles[index] = profile;
      return profile;
    }
    remoteProfiles.add(profile);
    return profile;
  }
}

class _FakeGoTrueClient extends Fake implements sb.GoTrueClient {
  Map<String, dynamic>? lastSignUpData;

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
    lastSignUpData = data;
    return sb.AuthResponse(
      user: sb.User(
        id: 'user-test-123',
        appMetadata: {},
        userMetadata: data ?? {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      ),
      session: null,
    );
  }
}

class _FakePostgrestClient extends Fake implements sb.PostgrestClient {
  final String _restUrl;
  _FakePostgrestClient(this._restUrl);

  @override
  String get url => '$_restUrl/rest/v1';
}

class _FakeSupabaseClient extends Fake implements sb.SupabaseClient {
  final _FakeGoTrueClient _authClient;
  final String _url;

  _FakeSupabaseClient({
    required _FakeGoTrueClient authClient,
    String url = 'https://wnaflcytkubqmrymbmcn.supabase.co',
  })  : _authClient = authClient,
        _url = url;

  @override
  sb.GoTrueClient get auth => _authClient;

  @override
  sb.PostgrestClient get rest => _FakePostgrestClient(_url);
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _overrideState;
  _FakeAuthNotifier(this._overrideState);

  @override
  AuthState build() => _overrideState;
}

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  final ProfileModel? _profile;
  _FakeActiveProfileNotifier(this._profile);

  @override
  ProfileModel? build() => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DOB Persistence & Deserialization Regression Tests', () {
    test(
        '1. SupabaseAuthRemoteDataSource.signUp sends both dob and date_of_birth in user metadata',
        () async {
      final fakeGoTrue = _FakeGoTrueClient();
      final fakeClient = _FakeSupabaseClient(authClient: fakeGoTrue);
      final dataSource = SupabaseAuthRemoteDataSource(fakeClient);

      final result = await dataSource.signUp(
        name: 'John Doe',
        email: 'john@example.com',
        password: 'Password123!',
        dob: '1995-05-15',
        gender: 'male',
      );

      expect(result.isPendingVerification, isTrue);
      expect(fakeGoTrue.lastSignUpData, isNotNull);
      expect(fakeGoTrue.lastSignUpData!['dob'], equals('1995-05-15'));
      expect(fakeGoTrue.lastSignUpData!['date_of_birth'], equals('1995-05-15'));
      expect(fakeGoTrue.lastSignUpData!['full_name'], equals('John Doe'));
      expect(fakeGoTrue.lastSignUpData!['gender'], equals('male'));
    });

    test(
        '2. UserModel deserializes dateOfBirth from dob, dateOfBirth, and date_of_birth keys',
        () {
      // From auth metadata with 'dob'
      final userFromDob = UserModel.fromSupabaseUser(
        sb.User(
          id: 'u1',
          appMetadata: {},
          userMetadata: {'full_name': 'Alice', 'dob': '1990-01-01'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      expect(userFromDob.dateOfBirth, equals('1990-01-01'));

      // From auth metadata with 'date_of_birth'
      final userFromDateOfBirth = UserModel.fromSupabaseUser(
        sb.User(
          id: 'u2',
          appMetadata: {},
          userMetadata: {'full_name': 'Bob', 'date_of_birth': '1992-02-02'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      expect(userFromDateOfBirth.dateOfBirth, equals('1992-02-02'));

      // From Map with 'dob'
      final userMapDob = UserModel.fromMap({
        'id': 'u3',
        'email': 'c@test.com',
        'name': 'Charlie',
        'dob': '1993-03-03',
      });
      expect(userMapDob.dateOfBirth, equals('1993-03-03'));

      // From Map with 'date_of_birth'
      final userMapDateOfBirth = UserModel.fromMap({
        'id': 'u4',
        'email': 'd@test.com',
        'name': 'Diana',
        'date_of_birth': '1994-04-04',
      });
      expect(userMapDateOfBirth.dateOfBirth, equals('1994-04-04'));
    });

    test(
        '3. ProfileModel deserializes dateOfBirth from date_of_birth, dateOfBirth, and dob',
        () {
      // fromMap with 'dob'
      final profileDob = ProfileModel.fromMap({
        'profile_id': 'p1',
        'owner_user_id': 'u1',
        'full_name': 'Alice',
        'relationship': 'Self',
        'dob': '1995-05-15',
      });
      expect(profileDob.dateOfBirth, equals('1995-05-15'));

      // fromMap with 'date_of_birth'
      final profileDateOfBirth = ProfileModel.fromMap({
        'profile_id': 'p2',
        'owner_user_id': 'u2',
        'full_name': 'Bob',
        'relationship': 'Self',
        'date_of_birth': '1996-06-16',
      });
      expect(profileDateOfBirth.dateOfBirth, equals('1996-06-16'));

      // fromSupabaseJson with 'dob' fallback
      final profileSupabaseDob = ProfileModel.fromSupabaseJson({
        'id': 'p3',
        'user_id': 'u3',
        'full_name': 'Charlie',
        'relationship': 'Self',
        'dob': '1997-07-17',
      });
      expect(profileSupabaseDob.dateOfBirth, equals('1997-07-17'));

      // fromSupabaseJson with 'date_of_birth'
      final profileSupabaseDateOfBirth = ProfileModel.fromSupabaseJson({
        'id': 'p4',
        'user_id': 'u4',
        'full_name': 'Diana',
        'relationship': 'Self',
        'date_of_birth': '1998-08-18',
      });
      expect(profileSupabaseDateOfBirth.dateOfBirth, equals('1998-08-18'));
    });
  });

  group('ProfileRepository DOB Hydration & Remote Persistence Tests', () {
    late Directory tempDir;
    late HiveService hiveService;
    late ProfileLocalDataSource localDataSource;
    late _TrackingSupabaseProfileRemoteDataSource fakeRemoteDataSource;
    late _FakeConnectivityService fakeConnectivity;
    late SyncService syncService;
    late ProfileRepository profileRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('profile_dob_test_');
      Hive.init(tempDir.path);

      for (final boxName in const [
        HiveService.authBoxName,
        HiveService.syncQueueBoxName,
        HiveService.userBoxName,
        HiveService.settingsBoxName,
        HiveService.profileBoxName,
      ]) {
        await Hive.openBox<Map>(boxName);
      }

      hiveService = HiveService();
      localDataSource = ProfileLocalDataSource(hiveService: hiveService);
      fakeRemoteDataSource = _TrackingSupabaseProfileRemoteDataSource();
      fakeConnectivity = _FakeConnectivityService();
      syncService = SyncService(
        hiveService: hiveService,
        connectivityService: fakeConnectivity,
      );

      profileRepo = ProfileRepository(
        localDataSource: localDataSource,
        remoteDataSource: fakeRemoteDataSource,
        connectivityService: fakeConnectivity,
        syncService: syncService,
        hiveService: hiveService,
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '4. ensureDefaultProfile hydrates primary profile with user DOB when handle_new_user() created profile with null DOB',
        () async {
      const userId = 'user-signup-1';
      final registeredUser = UserModel(
        id: userId,
        email: 'newuser@example.com',
        name: 'Jane Doe',
        dateOfBirth: '1995-05-15',
        gender: 'female',
      );

      // Simulates the row created by PostgreSQL trigger handle_new_user()
      // Notice: date_of_birth and gender are NULL as in the hosted Supabase schema
      final triggerCreatedProfile = ProfileModel(
        profileId: 'prof-trigger-uuid',
        ownerUserId: userId,
        fullName: 'Jane Doe',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: null,
        gender: null,
      );
      fakeRemoteDataSource.remoteProfiles.add(triggerCreatedProfile);

      // Call ensureDefaultProfile
      final primary = await profileRepo.ensureDefaultProfile(registeredUser);

      // The returned primary profile must have the hydrated DOB and gender
      expect(primary.dateOfBirth, equals('1995-05-15'));
      expect(primary.gender, equals('female'));

      // The local Hive box must store the hydrated profile
      final cached = await localDataSource.getProfileById(
        'prof-trigger-uuid',
        ownerUserId: userId,
      );
      expect(cached, isNotNull);
      expect(cached!.dateOfBirth, equals('1995-05-15'));

      // The update must have been pushed to Supabase so the remote row has the DOB
      expect(fakeRemoteDataSource.updateCallCount, equals(1));
      expect(fakeRemoteDataSource.lastUpdatedProfile, isNotNull);
      expect(
        fakeRemoteDataSource.lastUpdatedProfile!.dateOfBirth,
        equals('1995-05-15'),
      );
    });

    test(
        '5. ensureDefaultProfile preserves existing remote DOB when already populated',
        () async {
      const userId = 'user-existing-1';
      final user = UserModel(
        id: userId,
        email: 'existing@example.com',
        name: 'Existing User',
        dateOfBirth: '1990-01-01',
      );

      final populatedRemoteProfile = ProfileModel(
        profileId: 'prof-populated-uuid',
        ownerUserId: userId,
        fullName: 'Existing User',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: '1985-10-20',
        gender: 'male',
      );
      fakeRemoteDataSource.remoteProfiles.add(populatedRemoteProfile);

      final primary = await profileRepo.ensureDefaultProfile(user);

      // Existing remote DOB is authoritative and must not be overwritten
      expect(primary.dateOfBirth, equals('1985-10-20'));
      expect(fakeRemoteDataSource.updateCallCount, equals(0));
    });

    test(
        '6. ensureDefaultProfile safely supports null user DOB without error',
        () async {
      const userId = 'user-no-dob-1';
      final userWithoutDob = UserModel(
        id: userId,
        email: 'nodob@example.com',
        name: 'No Dob User',
        dateOfBirth: null,
      );

      final triggerCreatedProfile = ProfileModel(
        profileId: 'prof-null-uuid',
        ownerUserId: userId,
        fullName: 'No Dob User',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: null,
      );
      fakeRemoteDataSource.remoteProfiles.add(triggerCreatedProfile);

      final primary = await profileRepo.ensureDefaultProfile(userWithoutDob);

      expect(primary.dateOfBirth, isNull);
      expect(fakeRemoteDataSource.updateCallCount, equals(0));
    });

    test(
        '7. pullProfiles does not overwrite local populated DOB when remote returns null',
        () async {
      const userId = 'user-pull-1';

      // Local profile has populated DOB
      final localProfile = ProfileModel(
        profileId: 'prof-local-uuid',
        ownerUserId: userId,
        fullName: 'Jane Local',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: '1995-05-15',
        gender: 'female',
      );
      await localDataSource.saveProfile(localProfile);

      // Remote row has null DOB (e.g. sync delay or trigger row)
      final remoteProfile = ProfileModel(
        profileId: 'prof-local-uuid',
        ownerUserId: userId,
        fullName: 'Jane Local',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: null,
        gender: null,
      );
      fakeRemoteDataSource.remoteProfiles.add(remoteProfile);

      // Pull profiles from remote
      await profileRepo.pullProfiles(userId, force: true);

      // Local profile must retain its DOB
      final afterPull = await localDataSource.getProfileById(
        'prof-local-uuid',
        ownerUserId: userId,
      );
      expect(afterPull, isNotNull);
      expect(afterPull!.dateOfBirth, equals('1995-05-15'));
      expect(afterPull.gender, equals('female'));
    });
  });

  group('ProfileScreen DOB Presentation Widget Tests', () {
    testWidgets(
        '8. ProfileScreen displays DOB populated from active profile model',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const userId = 'user-widget-1';
      const user = UserModel(
        id: userId,
        email: 'widget@example.com',
        name: 'Jane Doe',
        dateOfBirth: '1995-05-15',
      );

      final profile = ProfileModel(
        profileId: 'prof-widget-1',
        ownerUserId: userId,
        fullName: 'Jane Doe',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: '1995-05-15',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  user: user,
                  isAuthenticated: true,
                ),
              ),
            ),
            activeProfileProvider
                .overrideWith(() => _FakeActiveProfileNotifier(profile)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);
      // Date formatting produces a visible text containing '1995'
      expect(find.textContaining('1995'), findsWidgets);
    });

    testWidgets(
        '9. ProfileScreen falls back to user registration DOB when active profile dateOfBirth is empty',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const userId = 'user-widget-2';
      const user = UserModel(
        id: userId,
        email: 'widget2@example.com',
        name: 'Bob Smith',
        dateOfBirth: '1992-04-12',
      );

      // Active profile has null DOB (simulating pre-sync state)
      final profileWithoutDob = ProfileModel(
        profileId: 'prof-widget-2',
        ownerUserId: userId,
        fullName: 'Bob Smith',
        relationship: 'Self',
        isPrimary: true,
        dateOfBirth: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  user: user,
                  isAuthenticated: true,
                ),
              ),
            ),
            activeProfileProvider.overrideWith(
              () => _FakeActiveProfileNotifier(profileWithoutDob),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);
      // Fallback extracts user registration DOB '1992-04-12' -> displays '1992'
      expect(find.textContaining('1992'), findsWidgets);
    });
  });
}
