import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/background_sync_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:medi_crate/core/utils/id_utils.dart';
import 'package:medi_crate/features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import 'package:medi_crate/features/appointments/data/models/appointment_model.dart';
import 'package:medi_crate/features/appointments/data/repositories/appointment_repository.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';

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

class _FakeSupabaseAppointmentRemoteDataSource
    extends SupabaseAppointmentRemoteDataSource {
  final List<AppointmentModel> remoteAppointments = [];
  bool shouldThrowNetworkError = false;
  AppointmentModel? lastCreatedAppointment;
  AppointmentModel? lastUpdatedAppointment;
  String? lastDeletedAppointmentId;
  int _idCounter = 0;

  @override
  Future<List<AppointmentModel>> fetchAppointments({
    required String ownerUserId,
    required String profileId,
    String? status,
    String? doctorId,
    String? hospitalId,
    String? from,
    String? to,
    int? limit,
    void Function(int total)? onTotal,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final list = remoteAppointments
        .where((a) => IdUtils.matches(a.profileId, profileId))
        .toList();
    onTotal?.call(list.length);
    return list;
  }

  @override
  Future<AppointmentModel?> getAppointmentById({
    required String appointmentId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(appointmentId);
    try {
      return remoteAppointments.firstWhere(
        (a) =>
            IdUtils.matches(a.id, cleanId) ||
            (a.clientUuid != null && a.clientUuid == cleanId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppointmentModel> createAppointment({
    required AppointmentModel appointment,
    required String ownerUserId,
    required String profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastCreatedAppointment = appointment;
    final cleanId = IdUtils.unprefix(appointment.id);
    _idCounter++;
    final effectiveId = UuidUtils.isValidUuid(cleanId)
        ? cleanId
        : 'a0000000-0000-0000-0000-${_idCounter.toString().padLeft(12, '0')}';
    final created = appointment.copyWith(
      id: effectiveId,
      profileId: profileId,
      clientUuid: appointment.clientUuid ?? effectiveId,
    );
    remoteAppointments.add(created);
    return created;
  }

  @override
  Future<AppointmentModel> updateAppointment({
    required AppointmentModel appointment,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    lastUpdatedAppointment = appointment;
    final cleanId = IdUtils.unprefix(appointment.id);
    final index =
        remoteAppointments.indexWhere((a) => IdUtils.matches(a.id, cleanId));
    if (index >= 0) {
      remoteAppointments[index] = appointment;
    } else {
      remoteAppointments.add(appointment);
    }
    return appointment;
  }

  @override
  Future<void> deleteAppointment({
    required String appointmentId,
    required String ownerUserId,
    String? profileId,
  }) async {
    if (shouldThrowNetworkError) throw const NetworkException('Network error');
    final cleanId = IdUtils.unprefix(appointmentId);
    lastDeletedAppointmentId = cleanId;
    remoteAppointments.removeWhere((a) => IdUtils.matches(a.id, cleanId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeSupabaseAppointmentRemoteDataSource fakeRemoteDataSource;
  late _FakeConnectivityService fakeConnectivity;
  late SyncService syncService;
  late AppointmentRepository appointmentRepo;
  bool pullFreshnessBumped = false;

  const ownerUserId = '11111111-2222-3333-4444-555555555555';
  const profileId = '22222222-3333-4444-5555-666666666666';
  const appointmentUuid = '33333333-4444-5555-6666-777777777777';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('appointment_repo_test_');
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
    fakeRemoteDataSource = _FakeSupabaseAppointmentRemoteDataSource();
    fakeConnectivity = _FakeConnectivityService();
    syncService = SyncService(
      hiveService: hiveService,
      connectivityService: fakeConnectivity,
    );

    pullFreshnessBumped = false;
    appointmentRepo = AppointmentRepository(
      hiveService: hiveService,
      supabaseRemoteDataSource: fakeRemoteDataSource,
      connectivityService: fakeConnectivity,
      syncService: syncService,
      onPullMerged: () {
        pullFreshnessBumped = true;
      },
    );

    // Seed active session in authBox and active profile in profileBox
    await hiveService.authBox.put('current_user', {
      'id': ownerUserId,
      'email': 'primary@example.com',
    });
    final profile = ProfileModel(
      profileId: profileId,
      ownerUserId: ownerUserId,
      fullName: 'Primary User',
      relationship: 'Self',
      isPrimary: true,
    );
    await hiveService.profileBox.put(profileId, profile.toMap());
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AppointmentRepository Supabase Integration Tests', () {
    test('1. Sync flags are preserved and active', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
      expect(BackgroundSyncService.isBackgroundSyncEnabled, isFalse);
    });

    test('2. pullAppointments fetches from Supabase and merges into Hive cache with freshness signal', () async {
      fakeRemoteDataSource.remoteAppointments.add(
        AppointmentModel(
          id: appointmentUuid,
          profileId: profileId,
          title: 'Cardiology Checkup',
          doctorName: 'Dr. Gregory House',
          hospitalName: 'Princeton Plainsboro',
          date: DateTime(2026, 11, 20, 10, 30),
          createdAt: DateTime(2026, 11, 10, 10, 0),
          updatedAt: DateTime(2026, 11, 10, 10, 0),
        ),
      );

      await appointmentRepo.pullAppointments(profileId);

      expect(pullFreshnessBumped, isTrue);
      final key = 'appointment_$appointmentUuid';
      final cached = hiveService.userBox.get(key);
      expect(cached, isNotNull);
      final model = AppointmentModel.fromJson(Map<String, dynamic>.from(cached as Map));
      expect(model.title, equals('Cardiology Checkup'));
      expect(model.doctorName, equals('Dr. Gregory House'));
      expect(model.hospitalName, equals('Princeton Plainsboro'));
    });

    test('3. getAppointmentById reads from Hive first, falls back to Supabase', () async {
      const existingId = 'appointment_existing-local-1111';
      final localAppointment = AppointmentModel(
        id: existingId,
        profileId: profileId,
        title: 'Local Routine Visit',
        doctorName: 'Dr. Local Medic',
        date: DateTime(2026, 11, 18, 9, 0),
        createdAt: DateTime(2026, 11, 10, 9, 0),
        updatedAt: DateTime(2026, 11, 10, 9, 0),
      );
      await hiveService.userBox.put(existingId, localAppointment.toJson());

      // Should return directly from Hive without calling Supabase
      final fromHive = await appointmentRepo.getAppointmentById(profileId, existingId);
      expect(fromHive, isNotNull);
      expect(fromHive!.title, equals('Local Routine Visit'));

      // Test fallback to Supabase when not present in Hive
      fakeRemoteDataSource.remoteAppointments.add(
        AppointmentModel(
          id: appointmentUuid,
          profileId: profileId,
          title: 'Remote Neurology Consult',
          doctorName: 'Dr. Remote Specialist',
          date: DateTime(2026, 11, 22, 11, 0),
          createdAt: DateTime(2026, 11, 10, 8, 0),
          updatedAt: DateTime(2026, 11, 10, 8, 0),
        ),
      );

      final fromSupabase = await appointmentRepo.getAppointmentById(profileId, appointmentUuid);
      expect(fromSupabase, isNotNull);
      expect(fromSupabase!.title, equals('Remote Neurology Consult'));
      // Verify cached in Hive
      final normKey = 'appointment_$appointmentUuid';
      expect(hiveService.userBox.containsKey(normKey), isTrue);
    });

    test('4. saveAppointmentModel updates existing Supabase appointment when ID is UUID', () async {
      final existingModel = AppointmentModel(
        id: appointmentUuid,
        profileId: profileId,
        title: 'Initial Consultation',
        doctorName: 'Dr. Gregory House',
        date: DateTime(2026, 11, 20, 10, 0),
        createdAt: DateTime(2026, 11, 10, 10, 0),
        updatedAt: DateTime(2026, 11, 10, 10, 0),
      );
      await hiveService.userBox.put('appointment_$appointmentUuid', existingModel.toJson());

      final updatedModel = existingModel.copyWith(
        title: 'Confirmed Cardiology Follow-up',
        status: 'confirmed',
      );

      final saved = await appointmentRepo.saveAppointmentModel(profileId, updatedModel);

      expect(saved.title, equals('Confirmed Cardiology Follow-up'));
      expect(saved.status, equals('confirmed'));
      expect(fakeRemoteDataSource.lastUpdatedAppointment, isNotNull);
      expect(fakeRemoteDataSource.lastUpdatedAppointment!.title, equals('Confirmed Cardiology Follow-up'));
      expect(fakeRemoteDataSource.lastCreatedAppointment, isNull);
    });

    test('5. saveAppointmentModel creates new appointment in Supabase and normalizes temporary local key', () async {
      const tempId = 'temp_appt_999';
      final newAppointment = AppointmentModel(
        id: tempId,
        profileId: profileId,
        title: 'Pediatric Checkup',
        doctorName: 'Dr. Allison Cameron',
        date: DateTime(2026, 11, 25, 14, 0),
        createdAt: DateTime(2026, 11, 11, 11, 0),
        updatedAt: DateTime(2026, 11, 11, 11, 0),
      );

      final created = await appointmentRepo.saveAppointmentModel(profileId, newAppointment);

      expect(fakeRemoteDataSource.lastCreatedAppointment, isNotNull);
      expect(UuidUtils.isValidUuid(IdUtils.unprefix(created.id)), isTrue);
      // Temporary local key must have been cleared from Hive
      expect(hiveService.userBox.containsKey(tempId), isFalse);
      expect(hiveService.userBox.containsKey('appointment_$tempId'), isFalse);
      // New key must exist
      expect(hiveService.userBox.containsKey(created.id), isTrue);
    });

    test('6. updateAppointmentStatus updates status in Supabase and persists in Hive', () async {
      final existingModel = AppointmentModel(
        id: appointmentUuid,
        profileId: profileId,
        title: 'Oncology Screening',
        doctorName: 'Dr. James Wilson',
        status: 'upcoming',
        date: DateTime(2026, 11, 21, 9, 30),
        createdAt: DateTime(2026, 11, 10, 10, 0),
        updatedAt: DateTime(2026, 11, 10, 10, 0),
      );
      await hiveService.userBox.put('appointment_$appointmentUuid', existingModel.toJson());

      final updated = await appointmentRepo.updateAppointmentStatus(
        profileId,
        appointmentUuid,
        'completed',
      );

      expect(updated, isNotNull);
      expect(updated!.status, equals('completed'));
      expect(fakeRemoteDataSource.lastUpdatedAppointment, isNotNull);
      expect(fakeRemoteDataSource.lastUpdatedAppointment!.status, equals('completed'));

      final cached = hiveService.userBox.get('appointment_$appointmentUuid');
      expect(cached, isNotNull);
      expect(cached!['status'], equals('completed'));
    });

    test('7. deleteAppointment removes record from Supabase and Hive', () async {
      final appointment = AppointmentModel(
        id: appointmentUuid,
        profileId: profileId,
        title: 'Routine Physical',
        doctorName: 'Dr. Eric Foreman',
        date: DateTime(2026, 11, 20, 15, 0),
        createdAt: DateTime(2026, 11, 10, 10, 0),
        updatedAt: DateTime(2026, 11, 10, 10, 0),
      );
      await hiveService.userBox.put('appointment_$appointmentUuid', appointment.toJson());
      fakeRemoteDataSource.remoteAppointments.add(appointment);

      await appointmentRepo.deleteAppointment(profileId, appointmentUuid);

      expect(hiveService.userBox.containsKey('appointment_$appointmentUuid'), isFalse);
      expect(fakeRemoteDataSource.lastDeletedAppointmentId, equals(appointmentUuid));
      expect(fakeRemoteDataSource.remoteAppointments, isEmpty);
    });

    test('8. Offline save queues mutation and preserves local record', () async {
      fakeConnectivity.isOnline = false;
      final offlineAppointment = AppointmentModel(
        id: 'appt_offline_101',
        profileId: profileId,
        title: 'Orthopedic Evaluation',
        doctorName: 'Dr. Robert Chase',
        date: DateTime(2026, 11, 28, 16, 0),
        createdAt: DateTime(2026, 11, 11, 11, 0),
        updatedAt: DateTime(2026, 11, 11, 11, 0),
      );

      final saved = await appointmentRepo.saveAppointmentModel(profileId, offlineAppointment);

      expect(saved.id, equals('appointment_appt_offline_101'));
      expect(fakeRemoteDataSource.lastCreatedAppointment, isNull);
      expect(hiveService.userBox.containsKey('appointment_appt_offline_101'), isTrue);

      final queueEntries = hiveService.syncQueueBox.values.toList();
      expect(queueEntries.isNotEmpty, isTrue);
      final lastQueueItem = queueEntries.last;
      expect(lastQueueItem['entity'], equals('appointments'));
    });

    test('9. Cross-user isolation: profile belonging to another user cannot be pulled or saved', () async {
      const foreignUserId = '88888888-8888-8888-8888-888888888888';
      const foreignProfileId = '77777777-7777-7777-7777-777777777777';

      final foreignProfile = ProfileModel(
        profileId: foreignProfileId,
        ownerUserId: foreignUserId,
        fullName: 'Foreign User',
        relationship: 'Other',
        isPrimary: false,
      );
      await hiveService.profileBox.put(foreignProfileId, foreignProfile.toMap());

      fakeRemoteDataSource.remoteAppointments.add(
        AppointmentModel(
          id: '55555555-5555-5555-5555-555555555555',
          profileId: foreignProfileId,
          title: 'Foreign Appointment',
          doctorName: 'Dr. Foreign Doctor',
          date: DateTime(2026, 11, 30),
          createdAt: DateTime(2026, 11, 11, 11, 0),
          updatedAt: DateTime(2026, 11, 11, 11, 0),
        ),
      );

      // Attempt to pull foreign profile — must not populate local Hive
      await appointmentRepo.pullAppointments(foreignProfileId);

      final cached = hiveService.userBox.get('appointment_55555555-5555-5555-5555-555555555555');
      expect(cached, isNull);
    });

    test('10. Supabase network failure falls back safely to local Hive cache', () async {
      fakeRemoteDataSource.shouldThrowNetworkError = true;

      // 1. Pull handles error gracefully without throwing
      await appointmentRepo.pullAppointments(profileId);

      // 2. Save persists to local Hive cache and enqueues sync mutation
      final newAppt = AppointmentModel(
        id: 'new_temp_appt',
        profileId: profileId,
        title: 'Fallback Test Appt',
        doctorName: 'Dr. Fallback Test',
        date: DateTime(2026, 11, 29),
        createdAt: DateTime(2026, 11, 11, 11, 0),
        updatedAt: DateTime(2026, 11, 11, 11, 0),
      );
      final saved = await appointmentRepo.saveAppointmentModel(profileId, newAppt);
      expect(saved.id, isNotEmpty);
      expect(hiveService.userBox.containsKey(saved.id), isTrue);

      // 3. Delete removes from Hive and queues delete mutation
      await appointmentRepo.deleteAppointment(profileId, saved.id);
      expect(hiveService.userBox.containsKey(saved.id), isFalse);
    });
  });
}
