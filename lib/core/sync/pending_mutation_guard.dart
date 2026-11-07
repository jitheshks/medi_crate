import 'package:hive/hive.dart';

import '../utils/id_utils.dart';

/// PendingMutationGuard protects local Hive state during remote pull-sync.
///
/// Ensures that stale server records received during background pull operations
/// NEVER overwrite or resurrect records with pending CREATE, UPDATE, or DELETE mutations
/// in [syncQueueBox].
class PendingMutationGuard {
  PendingMutationGuard._();

  /// Determines whether a remote record has a pending local mutation in [syncQueueBox].
  ///
  /// Returns `true` if a pending mutation matching [entity], [profileId], and
  /// the record identity ([remoteId] or [clientUuid]) is present in the queue.
  static bool hasPendingMutation({
    required Box<Map<dynamic, dynamic>> syncQueueBox,
    required String entity,
    required String profileId,
    required String remoteId,
    String? clientUuid,
    Box? profileBox,
  }) {
    if (syncQueueBox.isEmpty) return false;

    final targetEntity = entity.trim().toLowerCase();
    final cleanRemoteId = IdUtils.unprefix(remoteId.trim());
    final serverNumericId = IdUtils.toServerIntId(cleanRemoteId);
    final cleanClientUuid = clientUuid?.trim();

    for (final rawItem in syncQueueBox.values) {
      final itemEntity = rawItem['entity']?.toString().trim().toLowerCase();
      if (itemEntity == null || !_entityMatches(itemEntity, targetEntity)) {
        continue;
      }

      final payload = rawItem['payload'];
      if (payload is! Map) continue;

      // Extract client UUID from payload or raw item
      final queueClientUuid =
          (payload['client_uuid'] ??
                  payload['clientUuid'] ??
                  rawItem['client_uuid'] ??
                  rawItem['clientUuid'])
              ?.toString()
              .trim();

      // Special handling for Profile entity
      if (targetEntity == 'profile' ||
          targetEntity == 'profiles' ||
          targetEntity == 'family_members' ||
          targetEntity == 'family_member') {
        // 1. Client UUID matching
        if (cleanClientUuid != null &&
            cleanClientUuid.isNotEmpty &&
            queueClientUuid != null &&
            queueClientUuid.isNotEmpty) {
          if (queueClientUuid == cleanClientUuid) {
            return true;
          }
        }

        // 2. Server profile ID matching
        final queueServerId =
            payload['server_profile_id'] ??
            payload['serverProfileId'] ??
            rawItem['server_profile_id'] ??
            rawItem['serverProfileId'];
        if (queueServerId != null) {
          final queueServerIdStr = queueServerId.toString().trim();
          if (queueServerIdStr == remoteId ||
              queueServerIdStr == cleanRemoteId) {
            return true;
          }
          if (serverNumericId != null &&
              int.tryParse(queueServerIdStr) == serverNumericId) {
            return true;
          }
        }

        // 3. Profile ID matching
        final queueProfileId =
            (payload['profile_id'] ??
                    payload['profileId'] ??
                    payload['id'] ??
                    rawItem['profile_id'] ??
                    rawItem['profileId'] ??
                    rawItem['id'])
                ?.toString()
                .trim();
        if (queueProfileId != null && queueProfileId.isNotEmpty) {
          if (queueProfileId == profileId ||
              queueProfileId == remoteId ||
              queueProfileId == cleanRemoteId ||
              IdUtils.matchesProfileId(
                queueProfileId,
                profileId,
                profileBox: profileBox,
              ) ||
              IdUtils.matches(queueProfileId, profileId) ||
              IdUtils.matches(queueProfileId, remoteId)) {
            return true;
          }
        }
        continue;
      }

      // --- For non-profile entities (consultations, medicines, etc.) ---

      // 1. Profile Isolation Check: Queued mutation profile must match target profileId
      final queueProfileId =
          (payload['profile_id'] ??
                  payload['profileId'] ??
                  rawItem['profile_id'] ??
                  rawItem['profileId'])
              ?.toString()
              .trim();
      if (queueProfileId != null &&
          queueProfileId.isNotEmpty &&
          profileId.isNotEmpty) {
        if (!IdUtils.matchesProfileId(
              queueProfileId,
              profileId,
              profileBox: profileBox,
            ) &&
            !IdUtils.matches(queueProfileId, profileId) &&
            IdUtils.unprefix(queueProfileId) != IdUtils.unprefix(profileId)) {
          continue; // Mutation belongs to a different profile
        }
      }

      // 2. Client UUID Matching Check
      if (cleanClientUuid != null &&
          cleanClientUuid.isNotEmpty &&
          queueClientUuid != null &&
          queueClientUuid.isNotEmpty) {
        if (queueClientUuid == cleanClientUuid) {
          return true;
        }
      }

      // 3. Entity ID Matching Check
      final queueId =
          (payload['id'] ??
                  payload['doctorId'] ??
                  payload['hospitalId'] ??
                  payload['consultationId'] ??
                  payload['appointmentId'] ??
                  payload['reportId'] ??
                  payload['medicineId'] ??
                  payload['measurementId'] ??
                  rawItem['id'])
              ?.toString()
              .trim();

      if (queueId != null && queueId.isNotEmpty && cleanRemoteId.isNotEmpty) {
        // Direct equality or unprefixed match
        if (queueId == remoteId ||
            queueId == cleanRemoteId ||
            IdUtils.matches(queueId, remoteId) ||
            IdUtils.unprefix(queueId) == cleanRemoteId) {
          return true;
        }

        // Numeric server ID match
        final queueServerId = IdUtils.toServerIntId(queueId);
        if (queueServerId != null &&
            serverNumericId != null &&
            queueServerId == serverNumericId) {
          return true;
        }
      }
    }

    return false;
  }

  /// Helper to normalize and match entity name variations.
  static bool _entityMatches(String queueEntity, String targetEntity) {
    if (queueEntity == targetEntity) return true;

    if ((queueEntity == 'doctor' || queueEntity == 'doctors') &&
        (targetEntity == 'doctor' || targetEntity == 'doctors')) {
      return true;
    }
    if ((queueEntity == 'hospital' || queueEntity == 'hospitals') &&
        (targetEntity == 'hospital' || targetEntity == 'hospitals')) {
      return true;
    }
    if ((queueEntity == 'consultation' || queueEntity == 'consultations') &&
        (targetEntity == 'consultation' || targetEntity == 'consultations')) {
      return true;
    }
    if ((queueEntity == 'appointment' || queueEntity == 'appointments') &&
        (targetEntity == 'appointment' || targetEntity == 'appointments')) {
      return true;
    }
    if ((queueEntity == 'report' || queueEntity == 'reports') &&
        (targetEntity == 'report' || targetEntity == 'reports')) {
      return true;
    }
    if ((queueEntity == 'medicine' || queueEntity == 'medicines') &&
        (targetEntity == 'medicine' || targetEntity == 'medicines')) {
      return true;
    }
    if ((queueEntity == 'measurement' ||
            queueEntity == 'measurements' ||
            queueEntity == 'vitals' ||
            queueEntity == 'vital') &&
        (targetEntity == 'measurement' ||
            targetEntity == 'measurements' ||
            targetEntity == 'vitals' ||
            targetEntity == 'vital')) {
      return true;
    }
    if ((queueEntity == 'profile' ||
            queueEntity == 'profiles' ||
            queueEntity == 'family_members' ||
            queueEntity == 'family_member') &&
        (targetEntity == 'profile' ||
            targetEntity == 'profiles' ||
            targetEntity == 'family_members' ||
            targetEntity == 'family_member')) {
      return true;
    }

    return false;
  }
}
