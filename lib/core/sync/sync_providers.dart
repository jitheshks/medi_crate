import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../utils/id_utils.dart';
import 'models/sync_queue_item.dart';
import 'sync_rollout_config.dart';
import 'sync_service.dart';

export 'manual_sync_controller.dart';

/// Evaluates whether a raw queued item belongs to the active profile and signed-in user.
bool isQueueItemForProfile({
  required Map<dynamic, dynamic> rawItem,
  required String? activeProfileId,
  int? activeServerProfileId,
  required String? activeUserId,
  bool isPrimaryProfile = false,
}) {
  final payload = rawItem['payload'];
  if (payload is! Map) return false;
  final pMap = Map<String, dynamic>.from(payload);

  // Status check: only count outstanding/incomplete work
  final status = (rawItem['status'] ?? 'pending').toString().toLowerCase();
  if (status == 'completed' || status == 'synced' || status == 'deleted') {
    return false;
  }

  // Cross-user isolation: if payload specifies owner/user ID, ensure it matches activeUserId
  final itemUserId =
      (pMap['owner_user_id'] ??
              pMap['ownerUserId'] ??
              pMap['user_id'] ??
              pMap['userId'])
          ?.toString();
  if (activeUserId != null &&
      itemUserId != null &&
      itemUserId.isNotEmpty &&
      itemUserId != activeUserId) {
    return false;
  }

  final entity = (rawItem['entity'] ?? '').toString().toLowerCase();
  final profileId =
      (pMap['profile_id'] ??
              pMap['profileId'] ??
              pMap['server_profile_id'] ??
              pMap['serverProfileId'])
          ?.toString();

  // 1. Direct profileId match
  if (profileId != null && profileId.isNotEmpty) {
    if (activeProfileId != null &&
        IdUtils.matches(profileId, activeProfileId)) {
      return true;
    }
    if (activeServerProfileId != null &&
        IdUtils.matches(profileId, activeServerProfileId.toString())) {
      return true;
    }
  }

  // 2. Profile entity mutations for the current user
  if (entity == 'profile' ||
      entity == 'profiles' ||
      entity == 'family_member' ||
      entity == 'family_members') {
    if (activeUserId != null &&
        (itemUserId == null || itemUserId == activeUserId)) {
      if (activeProfileId != null &&
          profileId != null &&
          IdUtils.matches(profileId, activeProfileId)) {
        return true;
      }
      final clientUuid = (pMap['client_uuid'] ?? pMap['clientUuid'])
          ?.toString();
      if (activeProfileId != null &&
          clientUuid != null &&
          IdUtils.matches(clientUuid, activeProfileId)) {
        return true;
      }
      if (isPrimaryProfile &&
          (pMap['is_primary'] == true || pMap['isPrimary'] == true)) {
        return true;
      }
    }
  }

  return false;
}

/// Reactive StreamProvider delivering the real-time pending sync items count for the active profile.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.user;
  if (!authState.isAuthenticated || user == null) {
    return Stream.value(0);
  }

  final activeProfile = ref.watch(activeProfileProvider);
  final hive = ref.watch(hiveServiceProvider);
  final box = hive.syncQueueBox;

  int computeCount() {
    if (activeProfile == null) return 0;
    var count = 0;
    for (final raw in box.values) {
      if (isQueueItemForProfile(
        rawItem: raw,
        activeProfileId: activeProfile.profileId,
        activeServerProfileId: activeProfile.serverProfileId,
        activeUserId: user.id,
        isPrimaryProfile: activeProfile.isPrimary,
      )) {
        count++;
      }
    }
    return count;
  }

  final controller = StreamController<int>();
  controller.add(computeCount());

  final sub = box.watch().listen((_) {
    if (!controller.isClosed) {
      controller.add(computeCount());
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Reactive StreamProvider delivering the list of pending SyncQueueItems for the active profile.
final pendingSyncQueueItemsProvider = StreamProvider<List<SyncQueueItem>>((
  ref,
) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.user;
  if (!authState.isAuthenticated || user == null) {
    return Stream.value(const []);
  }

  final activeProfile = ref.watch(activeProfileProvider);
  final hive = ref.watch(hiveServiceProvider);
  final box = hive.syncQueueBox;

  List<SyncQueueItem> computeItems() {
    if (activeProfile == null) return const [];
    final items = <SyncQueueItem>[];
    for (final raw in box.values) {
      if (isQueueItemForProfile(
        rawItem: raw,
        activeProfileId: activeProfile.profileId,
        activeServerProfileId: activeProfile.serverProfileId,
        activeUserId: user.id,
        isPrimaryProfile: activeProfile.isPrimary,
      )) {
        try {
          items.add(SyncQueueItem.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    }
    return items;
  }

  final controller = StreamController<List<SyncQueueItem>>();
  controller.add(computeItems());

  final sub = box.watch().listen((_) {
    if (!controller.isClosed) {
      controller.add(computeItems());
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider exposing whether foreground sync rollout is paused globally.
final isRolloutPausedProvider = Provider<bool>((ref) {
  return SyncRolloutConfig.isGlobalRolloutPaused;
});

/// Provider exposing whether the current authenticated user is an authorized internal tester.
final isEligibleTesterProvider = Provider<bool>((ref) {
  final authUser = ref.watch(authControllerProvider).user;
  if (authUser == null) return false;
  return SyncService.isEligibleTester(authUser.id);
});

/// Provider for the current user's foreground sync opt-in preference.
final syncOptInProvider =
    NotifierProvider<SyncOptInNotifier, bool>(SyncOptInNotifier.new);

class SyncOptInNotifier extends Notifier<bool> {
  @override
  bool build() {
    final authUser = ref.watch(authControllerProvider).user;
    if (authUser == null) return false;
    final syncService = ref.watch(syncServiceProvider);
    return syncService.isTesterOptedIn(authUser.id);
  }

  Future<void> toggle(bool value) async {
    final authUser = ref.read(authControllerProvider).user;
    if (authUser == null) return;
    await ref.read(syncServiceProvider).setTesterOptIn(authUser.id, value);
    state = value;
  }
}
