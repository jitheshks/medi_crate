import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/profile_remote_data_source.dart';
import '../datasources/remote/user_remote_data_source.dart';
import '../models/profile_model.dart';

/// ProfileSyncHandler manages the synchronization of primary user profiles (/users/me)
/// and secondary family member profiles (/api/v1/family-members).
class ProfileSyncHandler {
  ProfileSyncHandler._();

  /// Determines if a profile mutation corresponds to the primary user account.
  static bool isPrimaryProfile({
    required String localProfileId,
    required Map<String, dynamic> payload,
  }) {
    return localProfileId.startsWith('prof_primary_') ||
        payload['is_primary'] == true ||
        payload['relationship']?.toString().toLowerCase() == 'self';
  }

  /// Handles synchronization of a single profile mutation with the remote API
  /// (primary user profile update or family member CRUD) and updates local Hive storage.
  static Future<bool> process({
    required SyncQueueItem item,
    required ProfileRemoteDataSource remoteDataSource,
    UserRemoteDataSource? userRemoteDataSource,
    required Box profileBox,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(item.payload);
      final operation = item.operation.toLowerCase();
      final rawProfileId = payload['profile_id'] ?? payload['id'] ?? item.id;
      final localProfileId = rawProfileId.toString();
      final isPrimary = isPrimaryProfile(
        localProfileId: localProfileId,
        payload: payload,
      );

      // 1. Handle DELETE operation
      if (operation == 'delete') {
        if (isPrimary) {
          debugPrint('[ProfileSyncHandler] Primary profile delete rejected.');
          return true;
        }
        final serverProfileId = payload['server_profile_id'] != null
            ? int.tryParse(payload['server_profile_id'].toString())
            : IdUtils.resolveServerProfileId(
                profileBox: profileBox,
                profileId: localProfileId,
              );
        if (serverProfileId != null) {
          await remoteDataSource.deleteFamilyMember(serverProfileId.toString());
        }
        await profileBox.delete(localProfileId);
        return true;
      }

      // 2. Handle Primary Profile UPDATE
      if (isPrimary) {
        if (operation == 'update') {
          final userRemote = userRemoteDataSource;
          if (userRemote != null) {
            final res = await userRemote.updateProfile({
              if (payload['full_name'] != null || payload['name'] != null)
                'name': payload['full_name'] ?? payload['name'],
              if (payload['gender'] != null) 'gender': payload['gender'],
              if (payload['dob'] != null || payload['date_of_birth'] != null)
                'dob': payload['dob'] ?? payload['date_of_birth'],
              if (payload['blood_group'] != null)
                'blood_group': payload['blood_group'],
              if (payload['height'] != null) 'height': payload['height'],
              if (payload['weight'] != null) 'weight': payload['weight'],
            });
            final existingLocal = profileBox.get(localProfileId);
            if (existingLocal is Map) {
              final model = ProfileModel.fromMap(
                Map<String, dynamic>.from(existingLocal),
              );
              final updated = model.copyWith(
                fullName: res['name']?.toString() ?? model.fullName,
                gender: res['gender']?.toString() ?? model.gender,
                dateOfBirth: res['dob']?.toString() ?? model.dateOfBirth,
                bloodGroup: res['blood_group']?.toString() ?? model.bloodGroup,
                height: (res['height'] as num?)?.toDouble() ?? model.height,
                weight: (res['weight'] as num?)?.toDouble() ?? model.weight,
                photo: res['photo_url']?.toString() ?? model.photo,
              );
              await profileBox.put(localProfileId, updated.toMap());
            }
          }
        }
        return true;
      }

      // 3. Handle Secondary / Family Profile CREATE & UPDATE
      // Ensure client_uuid is preserved
      final existingLocalRaw = profileBox.get(localProfileId);
      ProfileModel? existingLocalModel;
      if (existingLocalRaw is Map) {
        existingLocalModel = ProfileModel.fromMap(
          Map<String, dynamic>.from(existingLocalRaw),
        );
      }

      final clientUuid =
          payload['client_uuid']?.toString() ??
          payload['clientUuid']?.toString() ??
          existingLocalModel?.clientUuid ??
          UuidUtils.generateV4();
      payload['client_uuid'] = clientUuid;

      final model = ProfileModel.fromMap(payload);
      final apiPayload = model.toApiJson();

      int? serverProfileId =
          model.serverProfileId ??
          existingLocalModel?.serverProfileId ??
          (payload['server_profile_id'] != null
              ? int.tryParse(payload['server_profile_id'].toString())
              : null);

      Map<String, dynamic> responseData;

      if (operation == 'update' && serverProfileId != null) {
        responseData = await remoteDataSource.updateFamilyMember(
          serverProfileId,
          apiPayload,
        );
      } else {
        responseData = await remoteDataSource.addFamilyMember(apiPayload);
      }

      // 4. Server ID Reconciliation without re-keying or deleting local ID
      final returnedServerId = responseData['id'] != null
          ? int.tryParse(responseData['id'].toString())
          : (responseData['profile_id'] != null
                ? int.tryParse(responseData['profile_id'].toString())
                : null);

      final resolvedServerProfileId = returnedServerId ?? serverProfileId;

      final serverModel = ProfileModel.fromMap(responseData);
      final synchronized = (existingLocalModel ?? model).copyWith(
        fullName: serverModel.fullName.isNotEmpty
            ? serverModel.fullName
            : (existingLocalModel?.fullName ?? model.fullName),
        relationship: serverModel.relationship.isNotEmpty
            ? serverModel.relationship
            : (existingLocalModel?.relationship ?? model.relationship),
        gender: serverModel.gender,
        dateOfBirth: serverModel.dateOfBirth,
        bloodGroup: serverModel.bloodGroup ?? existingLocalModel?.bloodGroup,
        height: serverModel.height ?? existingLocalModel?.height,
        weight: serverModel.weight ?? existingLocalModel?.weight,
        photo: serverModel.photo ?? existingLocalModel?.photo,
        serverProfileId: resolvedServerProfileId,
        clientUuid: clientUuid,
        ownerUserId: model.ownerUserId.isNotEmpty
            ? model.ownerUserId
            : (existingLocalModel?.ownerUserId ?? serverModel.ownerUserId),
      );

      // Save locally under the immutable localProfileId
      await profileBox.put(localProfileId, synchronized.toMap());

      return true;
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      debugPrint(
        '[ProfileSyncHandler] Profile sync DioException: HTTP $statusCode - ${dioErr.message}',
      );

      // Classify error:
      // 400, 404, 422 are permanent client/validation errors (dead-letter)
      if (statusCode != null &&
          (statusCode == 400 || statusCode == 404 || statusCode == 422)) {
        item.status = 'failed';
        item.retryCount = 99; // Mark dead-letter; do not retry automatically
        item.errorMessage =
            'Validation/Client error ($statusCode): ${dioErr.response?.data}';
      } else if (statusCode == 401) {
        // 401 Unauthorized: Recoverable authentication failure
        item.status = 'auth_required';
        item.errorMessage =
            'Authentication required ($statusCode): Session unauthenticated';
      } else if (statusCode == 403) {
        // 403 Forbidden: Authorization issue
        item.status = 'failed';
        item.errorMessage = 'Forbidden ($statusCode): ${dioErr.response?.data}';
      } else {
        item.errorMessage = 'Network error ($statusCode): ${dioErr.message}';
      }
      return false;
    } catch (err) {
      debugPrint('[ProfileSyncHandler] Error processing profile sync: $err');
      item.errorMessage = err.toString();
      return false;
    }
  }
}
