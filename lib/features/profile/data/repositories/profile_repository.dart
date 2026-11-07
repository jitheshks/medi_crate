import 'dart:async';
import 'dart:io';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/attachment_cleanup_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../auth/data/models/user_model.dart';
import '../datasources/local/profile_local_data_source.dart';
import '../datasources/remote/profile_remote_data_source.dart';
import '../datasources/remote/user_remote_data_source.dart';
import '../models/profile_model.dart';

/// ProfileRepository orchestrates offline-first profile management operations.
class ProfileRepository {
  final ProfileLocalDataSource localDataSource;
  final ProfileRemoteDataSource remoteDataSource;
  final ConnectivityService connectivityService;
  final SyncService syncService;
  final HiveService hiveService;
  final UserRemoteDataSource? userRemoteDataSource;
  final Map<String, Future<void>> _inFlightPulls = {};

  ProfileRepository({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.connectivityService,
    required this.syncService,
    required this.hiveService,
    this.userRemoteDataSource,
  });

  /// Fetches all profiles for user immediately from local Hive cache.
  Future<List<ProfileModel>> getProfiles(String ownerUserId) async {
    return await localDataSource.getProfilesForUser(ownerUserId);
  }

  /// Performs background pull-sync for profiles belonging to [ownerUserId]
  /// and merges server records into Hive cache without blocking local reads.
  Future<void> pullProfiles(String ownerUserId) {
    final existing = _inFlightPulls[ownerUserId];
    if (existing != null) {
      return existing;
    }

    final future = _executePullProfiles(ownerUserId);
    _inFlightPulls[ownerUserId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[ownerUserId], future)) {
        _inFlightPulls.remove(ownerUserId);
      }
    });
    return future;
  }

  Future<void> _executePullProfiles(String ownerUserId) async {
    try {
      final isOnline = await connectivityService.checkConnectivity();
      if (!isOnline) return;

      // 1. Refresh Primary Profile from User endpoint (/api/v1/users/me)
      if (userRemoteDataSource != null) {
        try {
          final userProfileData = await userRemoteDataSource!.getProfile();
          if (userProfileData.isNotEmpty) {
            final primaryId = 'prof_primary_$ownerUserId';

            // Guard against overwriting pending local mutations (I2-C2)
            if (!PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'profile',
              profileId: primaryId,
              remoteId: primaryId,
            )) {
              final existing = await localDataSource.getProfileById(primaryId);
              final resolvedServerId =
                  IdUtils.toServerIntId(
                    userProfileData['profile_id'] ??
                        userProfileData['server_profile_id'] ??
                        userProfileData['primary_profile_id'] ??
                        (userProfileData['primary_profile'] is Map
                            ? (userProfileData['primary_profile'] as Map)['id']
                            : null) ??
                        (userProfileData['profile'] is Map
                            ? (userProfileData['profile'] as Map)['id']
                            : null),
                  ) ??
                  existing?.serverProfileId;
              final primaryProfile = ProfileModel(
                profileId: primaryId,
                serverProfileId: resolvedServerId,
                ownerUserId: ownerUserId,
                fullName:
                    (userProfileData['name'] ??
                            userProfileData['full_name'] ??
                            existing?.fullName ??
                            'Primary Profile')
                        .toString(),
                relationship: ProfileRelationships.self,
                gender:
                    userProfileData['gender']?.toString() ??
                    existing?.gender ??
                    'male',
                dateOfBirth:
                    userProfileData['dob']?.toString() ??
                    userProfileData['date_of_birth']?.toString() ??
                    existing?.dateOfBirth ??
                    '',
                bloodGroup:
                    userProfileData['blood_group']?.toString() ??
                    existing?.bloodGroup,
                height:
                    (userProfileData['height'] as num?)?.toDouble() ??
                    existing?.height,
                weight:
                    (userProfileData['weight'] as num?)?.toDouble() ??
                    existing?.weight,
                photo:
                    userProfileData['photo_url']?.toString() ??
                    userProfileData['photo']?.toString() ??
                    existing?.photo,
                isPrimary: true,
                notes: existing?.notes,
                allergies: existing?.allergies ?? const [],
                allergiesConfirmedNone:
                    existing?.allergiesConfirmedNone ?? false,
                chronicConditions: existing?.chronicConditions ?? const [],
                chronicConditionsConfirmedNone:
                    existing?.chronicConditionsConfirmedNone ?? false,
              );
              await localDataSource.saveProfile(primaryProfile);
            }
          }
        } catch (_) {
          // Preflight / user endpoint error handled gracefully
        }
      }

      // 2. Fetch Family Members from Family endpoint (/api/v1/family-members)
      try {
        final remoteProfilesData = await remoteDataSource.fetchFamilyMembers();
        if (remoteProfilesData.isNotEmpty) {
          for (final raw in remoteProfilesData) {
            final rawId = raw['id'];
            final serverId = rawId is int
                ? rawId
                : int.tryParse(rawId?.toString() ?? '');

            final isPrimary =
                raw['is_primary'] == true ||
                raw['is_primary'] == 1 ||
                raw['is_primary'] == '1' ||
                raw['is_primary'] == 'true' ||
                ProfileRelationships.normalize(
                      (raw['relationship'] ?? '').toString(),
                    ) ==
                    ProfileRelationships.self;

            if (isPrimary) {
              // --- Primary / Self Profile Reconciliation ---
              final primaryId = 'prof_primary_$ownerUserId';

              if (PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'profile',
                profileId: primaryId,
                remoteId: serverId?.toString() ?? primaryId,
                clientUuid: raw['client_uuid']?.toString(),
              )) {
                continue;
              }

              final existing = await localDataSource.getProfileById(primaryId);
              final serverModel = ProfileModel.fromMap(raw);

              final reconciledPrimary = ProfileModel(
                profileId: primaryId,
                serverProfileId: serverId ?? existing?.serverProfileId,
                ownerUserId: ownerUserId,
                fullName: serverModel.fullName.isNotEmpty
                    ? serverModel.fullName
                    : (existing?.fullName ?? 'Primary Profile'),
                relationship: ProfileRelationships.self,
                gender: serverModel.gender ?? existing?.gender ?? 'male',
                dateOfBirth: serverModel.dateOfBirth ?? existing?.dateOfBirth,
                bloodGroup: serverModel.bloodGroup ?? existing?.bloodGroup,
                photo: serverModel.photo ?? existing?.photo,
                height: serverModel.height ?? existing?.height,
                weight: serverModel.weight ?? existing?.weight,
                isPrimary: true,
                notes: serverModel.notes ?? existing?.notes,
                allergies: serverModel.allergies.isNotEmpty
                    ? serverModel.allergies
                    : (existing?.allergies ?? const []),
                allergiesConfirmedNone:
                    serverModel.allergiesConfirmedNone ||
                    (existing?.allergiesConfirmedNone ?? false),
                chronicConditions: serverModel.chronicConditions.isNotEmpty
                    ? serverModel.chronicConditions
                    : (existing?.chronicConditions ?? const []),
                chronicConditionsConfirmedNone:
                    serverModel.chronicConditionsConfirmedNone ||
                    (existing?.chronicConditionsConfirmedNone ?? false),
              );

              await localDataSource.saveProfile(reconciledPrimary);

              // Clean up any legacy duplicate entry in profileBox
              if (serverId != null) {
                final legacyKey = serverId.toString();
                if (legacyKey != primaryId) {
                  await localDataSource.deleteProfile(legacyKey);
                }
                final legacyProfKey = 'prof_$serverId';
                if (legacyProfKey != primaryId) {
                  await localDataSource.deleteProfile(legacyProfKey);
                }
              }
              continue;
            }

            // --- Secondary Family Profile Reconciliation ---
            final clientUuid = (raw['client_uuid'] ?? raw['clientUuid'])
                ?.toString()
                .trim();

            // Match against existing local profiles
            ProfileModel? existingLocal;
            if (clientUuid != null && clientUuid.isNotEmpty) {
              existingLocal = await localDataSource.getProfileByClientUuid(
                clientUuid,
                ownerUserId,
              );
            }
            if (existingLocal == null && serverId != null) {
              existingLocal = await localDataSource.getProfileByServerId(
                serverId,
                ownerUserId,
              );
            }
            if (existingLocal == null && serverId != null) {
              existingLocal = await localDataSource.getProfileById(
                serverId.toString(),
              );
            }

            if (existingLocal != null) {
              // Guard against overwriting pending local mutations
              if (PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'profile',
                profileId: existingLocal.profileId,
                remoteId: serverId?.toString() ?? existingLocal.profileId,
                clientUuid: clientUuid ?? existingLocal.clientUuid,
              )) {
                continue;
              }

              final serverModel = ProfileModel.fromMap(raw);
              final merged = existingLocal.copyWith(
                serverProfileId: serverId ?? existingLocal.serverProfileId,
                fullName: serverModel.fullName.isNotEmpty
                    ? serverModel.fullName
                    : existingLocal.fullName,
                relationship: serverModel.relationship.isNotEmpty
                    ? serverModel.relationship
                    : existingLocal.relationship,
                relationshipOther:
                    serverModel.relationshipOther ??
                    existingLocal.relationshipOther,
                clientUuid: existingLocal.clientUuid ?? clientUuid,
                gender: serverModel.gender ?? existingLocal.gender,
                dateOfBirth:
                    serverModel.dateOfBirth ?? existingLocal.dateOfBirth,
                bloodGroup: serverModel.bloodGroup ?? existingLocal.bloodGroup,
                photo: serverModel.photo ?? existingLocal.photo,
                height: serverModel.height ?? existingLocal.height,
                weight: serverModel.weight ?? existingLocal.weight,
                notes: serverModel.notes ?? existingLocal.notes,
                allergies: serverModel.allergies.isNotEmpty
                    ? serverModel.allergies
                    : existingLocal.allergies,
                allergiesConfirmedNone:
                    serverModel.allergiesConfirmedNone ||
                    existingLocal.allergiesConfirmedNone,
                chronicConditions: serverModel.chronicConditions.isNotEmpty
                    ? serverModel.chronicConditions
                    : existingLocal.chronicConditions,
                chronicConditionsConfirmedNone:
                    serverModel.chronicConditionsConfirmedNone ||
                    existingLocal.chronicConditionsConfirmedNone,
              );

              await localDataSource.saveProfile(merged);
            } else {
              // New remote profile not yet seen locally
              if (PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'profile',
                profileId: serverId?.toString() ?? '',
                remoteId: serverId?.toString() ?? '',
                clientUuid: clientUuid,
              )) {
                continue;
              }

              final localId =
                  'prof_${serverId ?? DateTime.now().microsecondsSinceEpoch}';
              final serverModel = ProfileModel.fromMap(raw);
              final newProfile = serverModel.copyWith(
                profileId: localId,
                serverProfileId: serverId,
                ownerUserId: ownerUserId,
                clientUuid: clientUuid,
              );

              await localDataSource.saveProfile(newProfile);
            }
          }
        }
      } catch (_) {
        // Family members error handled gracefully
      }
    } catch (_) {
      // Gracefully catch any unexpected error during pull
    } finally {
      _inFlightPulls.remove(ownerUserId);
    }
  }

  /// Fetches a specific profile by ID.
  Future<ProfileModel?> getProfileById(String profileId) async {
    final local = await localDataSource.getProfileById(profileId);
    if (local != null) return local;

    final isOnline = await connectivityService.checkConnectivity();
    if (isOnline) {
      try {
        final serverId = IdUtils.toServerIntId(profileId);
        if (serverId != null) {
          final remoteData = await remoteDataSource.getFamilyMember(serverId);
          if (remoteData.isNotEmpty) {
            final profile = ProfileModel.fromMap(remoteData);
            await localDataSource.saveProfile(profile);
            return profile;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Creates a new family profile.
  Future<ProfileModel> createProfile(ProfileModel profile) async {
    final isOnline = await connectivityService.checkConnectivity();

    final clientUuid =
        (profile.clientUuid != null && profile.clientUuid!.trim().isNotEmpty)
        ? profile.clientUuid!.trim()
        : UuidUtils.generateV4();
    final localProfileId = profile.profileId.isNotEmpty
        ? profile.profileId
        : 'prof_${DateTime.now().microsecondsSinceEpoch}';
    final profileToSave = profile.copyWith(
      profileId: localProfileId,
      clientUuid: clientUuid,
      clearServerProfileId: true,
    );

    await localDataSource.saveProfile(profileToSave);

    final queueId = 'sync_prof_${DateTime.now().microsecondsSinceEpoch}';
    await syncService.addToQueue(
      SyncQueueItem(
        id: queueId,
        entity: 'profile',
        operation: 'create',
        payload: profileToSave.toMap(),
      ),
    );

    if (isOnline) {
      try {
        final res = await remoteDataSource.addFamilyMember(
          profileToSave.toApiJson(),
        );
        final rawId = res['id'];
        final serverId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        if (serverId != null) {
          final synced = profileToSave.copyWith(serverProfileId: serverId);
          // Retain stable local canonical profileId
          await localDataSource.saveProfile(synced);

          // Remove completed mutation from queue
          await hiveService.syncQueueBox.delete(queueId);
          return synced;
        }
      } catch (_) {
        return profileToSave;
      }
    }

    return profileToSave;
  }

  /// Updates an existing profile.
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    final isOnline = await connectivityService.checkConnectivity();

    await localDataSource.saveProfile(profile);

    if (profile.isPrimary) {
      if (isOnline && userRemoteDataSource != null) {
        try {
          final res = await userRemoteDataSource!.updateProfile({
            'name': profile.fullName,
            if (profile.gender != null) 'gender': profile.gender,
            if (profile.dateOfBirth != null) 'dob': profile.dateOfBirth,
            if (profile.bloodGroup != null) 'blood_group': profile.bloodGroup,
            if (profile.height != null) 'height': profile.height,
            if (profile.weight != null) 'weight': profile.weight,
          });
          final synced = profile.copyWith(
            fullName: res['name']?.toString() ?? profile.fullName,
            gender: res['gender']?.toString() ?? profile.gender,
            dateOfBirth: res['dob']?.toString() ?? profile.dateOfBirth,
            bloodGroup: res['blood_group']?.toString() ?? profile.bloodGroup,
            height: (res['height'] as num?)?.toDouble() ?? profile.height,
            weight: (res['weight'] as num?)?.toDouble() ?? profile.weight,
            photo: res['photo_url']?.toString() ?? profile.photo,
          );
          await localDataSource.saveProfile(synced);
          return synced;
        } catch (_) {}
      }
      await syncService.addToQueue(
        SyncQueueItem(
          id: 'sync_prof_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'profile',
          operation: 'update',
          payload: profile.toMap(),
        ),
      );
      return profile;
    }

    // Secondary profile:
    if (profile.serverProfileId == null) {
      // Find pending create mutation in syncQueueBox and update its payload
      final syncBox = hiveService.syncQueueBox;
      bool updatedPendingCreate = false;
      for (final key in syncBox.keys) {
        final val = syncBox.get(key);
        if (val is Map) {
          final entity = val['entity']?.toString().toLowerCase();
          final op = val['operation']?.toString().toLowerCase();
          final payload = val['payload'];
          if ((entity == 'profile' || entity == 'family_members') &&
              op == 'create' &&
              payload is Map) {
            final pid = payload['profile_id'] ?? payload['id'];
            final cUuid = payload['client_uuid'] ?? payload['clientUuid'];
            if (pid == profile.profileId ||
                (profile.clientUuid != null && cUuid == profile.clientUuid)) {
              val['payload'] = profile.toMap();
              await syncBox.put(key, Map<dynamic, dynamic>.from(val));
              updatedPendingCreate = true;
              break;
            }
          }
        }
      }
      if (!updatedPendingCreate) {
        await syncService.addToQueue(
          SyncQueueItem(
            id: 'sync_prof_${DateTime.now().microsecondsSinceEpoch}',
            entity: 'profile',
            operation: 'create',
            payload: profile.toMap(),
          ),
        );
      }
      return profile;
    }

    // Profile has serverProfileId
    final queueId = 'sync_prof_${DateTime.now().microsecondsSinceEpoch}';
    await syncService.addToQueue(
      SyncQueueItem(
        id: queueId,
        entity: 'profile',
        operation: 'update',
        payload: profile.toMap(),
      ),
    );

    if (isOnline) {
      try {
        final res = await remoteDataSource.updateFamilyMember(
          profile.serverProfileId!,
          profile.toApiJson(),
        );
        final synced = ProfileModel.fromMap(res).copyWith(
          profileId: profile.profileId,
          serverProfileId: profile.serverProfileId,
          clientUuid: profile.clientUuid,
          ownerUserId: profile.ownerUserId,
        );
        await localDataSource.saveProfile(synced);
        await hiveService.syncQueueBox.delete(queueId);
        return synced;
      } catch (_) {
        return profile;
      }
    }

    return profile;
  }

  /// F7: Fetches overview summary across all family profiles with offline fallback.
  Future<List<Map<String, dynamic>>> getFamilyDashboard(
    String ownerUserId,
  ) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (isOnline) {
      try {
        final remoteSummary = await remoteDataSource.fetchFamilyDashboard();
        if (remoteSummary.isNotEmpty) {
          return remoteSummary;
        }
      } catch (_) {}
    }

    final localProfiles = await localDataSource.getProfilesForUser(ownerUserId);
    return localProfiles
        .map(
          (p) => {
            'profile_id': p.profileId,
            'full_name': p.fullName,
            'relationship': p.relationship,
            'photo': p.photo,
            'latest_vitals': [],
            'upcoming_appointments': [],
            'active_medicines_count': 0,
          },
        )
        .toList();
  }

  /// F8: Fetches combined analytics across all family profiles with offline fallback.
  Future<List<Map<String, dynamic>>> getFamilyAnalytics(
    String ownerUserId,
  ) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (isOnline) {
      try {
        final remoteAnalytics = await remoteDataSource.fetchFamilyAnalytics();
        if (remoteAnalytics.isNotEmpty) {
          return remoteAnalytics;
        }
      } catch (_) {}
    }

    final localProfiles = await localDataSource.getProfilesForUser(ownerUserId);
    return localProfiles
        .map(
          (p) => {
            'profile_id': p.profileId,
            'full_name': p.fullName,
            'total_consultations': 0,
            'total_reports': 0,
            'total_expense': 0,
          },
        )
        .toList();
  }

  /// Deletes a family profile. Primary profile cannot be deleted.
  Future<void> deleteProfile(String profileId) async {
    final existing = await localDataSource.getProfileById(profileId);
    if (existing != null && existing.isPrimary) {
      throw StateError('Primary profile cannot be deleted.');
    }

    final isOnline = await connectivityService.checkConnectivity();

    // 1. Delete profile from local storage
    await localDataSource.deleteProfile(profileId);

    // 2. Delete all associated profile medical records from local Hive boxes
    await _clearAssociatedProfileRecords(profileId);

    // 3. Clean up local profile photo if present
    if (existing != null && existing.photo != null) {
      await AttachmentCleanupHelper.safelyDeleteFile(
        hiveService: hiveService,
        filePath: existing.photo,
        exemptRecordId: profileId,
      );
    }

    // 4. Cancel pending offline create/update mutations for this profile
    final syncBox = hiveService.syncQueueBox;
    final keysToDelete = <dynamic>[];
    for (final key in syncBox.keys) {
      final val = syncBox.get(key);
      if (val is Map) {
        final entity = val['entity']?.toString().toLowerCase();
        final payload = val['payload'];
        if ((entity == 'profile' || entity == 'family_members') &&
            payload is Map) {
          final pid = payload['profile_id'] ?? payload['id'];
          final cUuid = payload['client_uuid'] ?? payload['clientUuid'];
          if (pid == profileId ||
              (existing?.clientUuid != null && cUuid == existing!.clientUuid)) {
            keysToDelete.add(key);
          }
        }
      }
    }
    for (final k in keysToDelete) {
      await syncBox.delete(k);
    }

    // 5. Queue delete mutation for sync
    final queueId = 'sync_prof_del_${DateTime.now().millisecondsSinceEpoch}';
    await syncService.addToQueue(
      SyncQueueItem(
        id: queueId,
        entity: 'profile',
        operation: 'delete',
        payload: {
          'profile_id': profileId,
          if (existing?.serverProfileId != null)
            'server_profile_id': existing!.serverProfileId,
        },
      ),
    );

    if (isOnline) {
      final targetServerId =
          existing?.serverProfileId?.toString() ??
          IdUtils.toServerIntId(profileId)?.toString();
      if (targetServerId != null) {
        try {
          await remoteDataSource.deleteFamilyMember(targetServerId);
          await hiveService.syncQueueBox.delete(queueId);
        } catch (_) {}
      }
    }
  }

  /// Uploads avatar photo for a profile.
  Future<ProfileModel> uploadProfilePhoto(
    String profileId,
    File photoFile,
  ) async {
    final existing = await localDataSource.getProfileById(profileId);
    final isOnline = await connectivityService.checkConnectivity();

    // Clean up old local photo if it was a persistent profile file
    if (existing != null &&
        existing.photo != null &&
        existing.photo != photoFile.path) {
      await AttachmentCleanupHelper.safelyDeleteFile(
        hiveService: hiveService,
        filePath: existing.photo,
        exemptRecordId: profileId,
      );
    }

    if (isOnline) {
      try {
        final targetServerId =
            existing?.serverProfileId?.toString() ?? profileId;
        final photoUrl = await remoteDataSource.uploadFamilyMemberPhoto(
          targetServerId,
          photoFile,
        );
        if (photoUrl.isNotEmpty && existing != null) {
          final updated = existing.copyWith(photo: photoUrl);
          await localDataSource.saveProfile(updated);
          return updated;
        }
      } catch (_) {}
    }

    // Offline or fallback: save local file path
    if (existing != null) {
      final updated = existing.copyWith(photo: photoFile.path);
      await localDataSource.saveProfile(updated);
      return updated;
    }

    throw StateError('Profile not found for photo upload.');
  }

  Future<void> setPrimaryProfile(ProfileModel profile) async {
    final updated = profile.copyWith(isPrimary: true);
    await updateProfile(updated);
  }

  Future<ProfileModel> ensureDefaultProfile(UserModel user) async {
    final existing = await localDataSource.getProfilesForUser(user.id);
    if (existing.isNotEmpty) {
      final primary = existing.firstWhere(
        (p) => p.isPrimary,
        orElse: () => existing.first,
      );
      final activeId = await localDataSource.getActiveProfileId();
      if (activeId == null) {
        await localDataSource.setActiveProfileId(primary.profileId);
      }
      return primary;
    }

    final defaultProfile = ProfileModel(
      profileId: 'prof_primary_${user.id}',
      serverProfileId: null,
      ownerUserId: user.id,
      fullName: user.name.isNotEmpty ? user.name : 'Primary Profile',
      relationship: ProfileRelationships.self,
      gender: user.gender ?? 'male',
      dateOfBirth: user.dateOfBirth ?? '',
      bloodGroup: user.bloodGroup,
      isPrimary: true,
      notes: null,
    );

    await localDataSource.saveProfile(defaultProfile);
    await localDataSource.setActiveProfileId(defaultProfile.profileId);
    return defaultProfile;
  }

  Future<String?> getActiveProfileId() async {
    return await localDataSource.getActiveProfileId();
  }

  Future<void> setActiveProfileId(String profileId) async {
    await localDataSource.setActiveProfileId(profileId);
  }

  /// Clears active profile selection and session-specific profile cache upon sign out.
  Future<void> clearSessionProfileData() async {
    await localDataSource.clearActiveProfileId();
  }

  Future<void> _clearAssociatedProfileRecords(String profileId) async {
    try {
      // Scrub profile data from local Hive boxes
      final boxesToClean = [hiveService.userBox, hiveService.settingsBox];

      for (final box in boxesToClean) {
        final keysToDelete = <dynamic>[];
        for (final key in box.keys) {
          final val = box.get(key);
          if (val is Map && val['profile_id'] == profileId) {
            keysToDelete.add(key);
          }
        }
        for (final key in keysToDelete) {
          await box.delete(key);
        }
      }
    } catch (_) {
      // Handled gracefully if Hive boxes are uninitialized in unit test environments
    }
  }
}
