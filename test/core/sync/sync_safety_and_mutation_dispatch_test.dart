import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medi_crate/core/connectivity/connectivity_service.dart';
import 'package:medi_crate/core/storage/hive_service.dart';
import 'package:medi_crate/core/sync/models/sync_queue_item.dart';
import 'package:medi_crate/core/sync/queue_coalescer.dart';
import 'package:medi_crate/core/sync/sync_lock.dart';
import 'package:medi_crate/core/sync/sync_service.dart';

class _FakeConnectivityService extends ConnectivityService {
  final bool online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  _FakeConnectivityService({this.online = true}) : super(autoInitialize: false);

  @override
  Future<bool> checkConnectivity() async => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool status) => _controller.add(status);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;
  late _FakeConnectivityService connectivityService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medi_crate_sync_safety_');
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
    connectivityService = _FakeConnectivityService(online: true);
  });

  tearDown(() async {
    SyncService.isRemoteSyncEnabled = false;
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TASK 1 — Missing Remote Data Source Defers Without Data Loss', () {
    final entities = [
      'consultation',
      'doctor',
      'hospital',
      'report',
      'appointment',
      'medicine',
      'measurement',
      'profile',
    ];

    for (final entity in entities) {
      test('Missing $entity remote data source defers item, does not burn retry, and keeps item in Hive', () async {
        final queueBox = hiveService.syncQueueBox;
        final item = SyncQueueItem(
          id: 'queue_${entity}_1',
          entity: entity,
          operation: 'create',
          payload: {
            'id': 'local_${entity}_1',
            'client_uuid': 'cuuid-$entity-123',
            'profile_id': 1,
            'name': 'Test $entity',
          },
        );

        await queueBox.put(item.id, item.toMap());

        // Temporarily permit remote push execution inside test
        SyncService.isRemoteSyncEnabled = true;
        var syncCompletedCalled = false;
        final testSyncService = SyncService(
          hiveService: hiveService,
          connectivityService: connectivityService,
          onSyncCompleted: () => syncCompletedCalled = true,
        );

        await testSyncService.syncPending(force: true);

        // 1. Item must still exist in Hive
        expect(queueBox.containsKey(item.id), isTrue,
            reason: 'Item for $entity should not be deleted when remote is missing');

        final updatedRaw = queueBox.get(item.id);
        expect(updatedRaw, isNotNull);
        final updated = SyncQueueItem.fromMap(Map<String, dynamic>.from(updatedRaw!));

        // 2. Status must be deferred
        expect(updated.status, 'deferred');

        // 3. retryCount must NOT be incremented
        expect(updated.retryCount, 0);

        // 4. claimToken and claimedAt must be cleared
        expect(updated.claimToken, isNull);
        expect(updated.claimedAt, isNull);

        // 5. Must not report as successfully synchronized
        expect(syncCompletedCalled, isFalse);
      });
    }
  });

  group('TASK 2 — Protect Primary Profile Deletion', () {
    test('1. Central SyncService preserves rejected primary profile delete in Hive with dead-letter status', () async {
      SyncService.isRemoteSyncEnabled = true;

      final queueBox = hiveService.syncQueueBox;
      final item = SyncQueueItem(
        id: 'q_primary_del_central',
        entity: 'profile',
        operation: 'delete',
        payload: {
          'id': 'prof_primary_usr1',
          'is_primary': true,
          'relationship': 'Self',
        },
      );

      await queueBox.put(item.id, item.toMap());

      final testSyncService = SyncService(
        hiveService: hiveService,
        connectivityService: connectivityService,
      );

      try {
        await testSyncService.syncPending(force: true);

        // Must NOT be deleted from Hive!
        expect(queueBox.containsKey(item.id), isTrue);

        final raw = queueBox.get(item.id);
        expect(raw, isNotNull);
        final stored = SyncQueueItem.fromMap(Map<String, dynamic>.from(raw!));

        expect(stored.status, 'failed');
        expect(stored.retryCount, 99);
        expect(stored.errorMessage, contains('prohibited by system invariant'));
      } finally {
        testSyncService.dispose();
        SyncService.isRemoteSyncEnabled = false;
      }
    });

    });

  group('TASK 4 — Queue Coalescing and Durability', () {
    test('1. In-flight CREATE is not folded or discarded by subsequent UPDATE', () {
      final now = DateTime.now();
      final inFlightCreate = SyncQueueItem(
        id: 'item_con_create',
        entity: 'consultation',
        operation: 'create',
        status: 'syncing',
        claimToken: 'proc_active_1',
        claimedAt: now,
        payload: {
          'id': 'con_local_1',
          'client_uuid': 'cuuid-con-99',
          'notes': 'Original notes',
        },
      );

      final incomingUpdate = SyncQueueItem(
        id: 'item_con_update',
        entity: 'consultation',
        operation: 'update',
        payload: {
          'id': 'con_local_1',
          'client_uuid': 'cuuid-con-99',
          'notes': 'Updated notes while in flight',
        },
      );

      final result = QueueCoalescer.coalesce(
        existing: [QueueEntry(inFlightCreate.id, inFlightCreate)],
        incoming: incomingUpdate,
        now: now,
        leaseDuration: SyncLock.leaseDuration,
      );

      // In-flight item must NOT be deleted or mutated
      expect(result.keysToDelete, isEmpty);
      // Incoming update must be appended as its own separate queue entry
      expect(result.putKey, incomingUpdate.id);
      expect(result.putItem, isNotNull);
      expect(result.putItem!.operation, 'update');
    });

    test('2. Pending (not in flight) CREATE followed by UPDATE safely collapses into a single CREATE', () {
      final now = DateTime.now();
      final pendingCreate = SyncQueueItem(
        id: 'item_con_create_pending',
        entity: 'consultation',
        operation: 'create',
        status: 'pending',
        payload: {
          'id': 'con_local_1',
          'client_uuid': 'cuuid-con-99',
          'notes': 'Original notes',
        },
      );

      final incomingUpdate = SyncQueueItem(
        id: 'item_con_update_later',
        entity: 'consultation',
        operation: 'update',
        payload: {
          'id': 'con_local_1',
          'client_uuid': 'cuuid-con-99',
          'notes': 'Updated notes',
        },
      );

      final result = QueueCoalescer.coalesce(
        existing: [QueueEntry(pendingCreate.id, pendingCreate)],
        incoming: incomingUpdate,
        now: now,
        leaseDuration: SyncLock.leaseDuration,
      );

      // Collapses onto the original key
      expect(result.putKey, pendingCreate.id);
      expect(result.putItem, isNotNull);
      // Merged operation remains 'create' because it never reached server
      expect(result.putItem!.operation, 'create');
      expect(result.putItem!.payload['notes'], 'Updated notes');
    });
  });
}
