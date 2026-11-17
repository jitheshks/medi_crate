import 'dart:async';
import 'dart:io';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../datasources/local/profile_local_data_source.dart';
import '../datasources/remote/supabase_profile_remote_data_source.dart';
import '../models/profile_model.dart';

/// ProfileRepository orchestrates offline-first profile management operations
/// backed by Hive local storage and Supabase remote synchronization.
class ProfileRepository {
  final ProfileLocalDataSource localDataSource;
  final SupabaseProfileRemoteDataSource remoteDataSource;
  final ConnectivityService connectivityService;
  final SyncService syncService;
  final HiveService hiveService;
  final Map<String, Future<void>> _inFlightPulls = {};

  ProfileRepository({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.connectivityService,
    required this.syncService,
    required this.hiveService,
    dynamic userRemoteDataSource,
    dynamic legacyRemoteDataSource,
  });

  /// Fetches profiles for [ownerUserId] immediately from local Hive cache.
  /// If [includeArchived] is false (default), only active profiles are returned.
  Future<List<ProfileModel>> getProfiles(
    String ownerUserId, {
    bool includeArchived = false,
  }) async {
    return await localDataSource.getProfilesForUser(
      ownerUserId,
      includeArchived: includeArchived,
    );
  }

  /// Performs background pull from Supabase for profiles belonging to [ownerUserId]
  /// and updates Hive cache without blocking local reads.
  /// If [force] is true, ignores any currently in-flight pull and starts a fresh pull.
  Future<void> pullProfiles(String ownerUserId, {bool force = false}) {
    if (!force) {
      final existing = _inFlightPulls[ownerUserId];
      if (existing != null) {
        return existing;
      }
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

      final remoteProfiles = await remoteDataSource.fetchProfiles(
        ownerUserId: ownerUserId,
        includeArchived: true,
      );

      if (remoteProfiles.isNotEmpty) {
        final existingProfiles = await localDataSource.getProfilesForUser(
          ownerUserId,
          includeArchived: true,
        );
        final existingById = {for (final p in existingProfiles) p.profileId: p};

        final mergedProfiles = remoteProfiles.map((remote) {
          final existing = existingById[remote.profileId];
          if (existing != null) {
            final shouldPreserveDob =
                (remote.dateOfBirth == null || remote.dateOfBirth!.isEmpty) &&
                (existing.dateOfBirth != null &&
                    existing.dateOfBirth!.isNotEmpty);
            final shouldPreserveGender =
                (remote.gender == null || remote.gender!.isEmpty) &&
                (existing.gender != null && existing.gender!.isNotEmpty);
            if (shouldPreserveDob || shouldPreserveGender) {
              return remote.copyWith(
                dateOfBirth: shouldPreserveDob
                    ? existing.dateOfBirth
                    : remote.dateOfBirth,
                gender: shouldPreserveGender ? existing.gender : remote.gender,
              );
            }
          }
          return remote;
        }).toList();

        // Save remote profiles to Hive
        await localDataSource.saveProfiles(mergedProfiles);

        // If an authoritative primary profile was retrieved from Supabase,
        // clean up any legacy provisional primary key in Hive
        final primary = remoteProfiles.where((p) => p.isPrimary).firstOrNull;
        if (primary != null && primary.profileId != 'prof_primary_$ownerUserId') {
          await localDataSource.deleteProfile('prof_primary_$ownerUserId');
        }
      }
    } catch (_) {
      // Background pull failure handled gracefully - local data remains accessible
    } finally {
      _inFlightPulls.remove(ownerUserId);
    }
  }

  /// Fetches a specific profile by ID from Hive first, then Supabase if online.
  Future<ProfileModel?> getProfileById(
    String profileId, {
    required String ownerUserId,
  }) async {
    final local = await localDataSource.getProfileById(
      profileId,
      ownerUserId: ownerUserId,
    );
    if (local != null) return local;

    if (ownerUserId.trim().isNotEmpty) {
      final isOnline = await connectivityService.checkConnectivity();
      if (isOnline) {
        try {
          final remote = await remoteDataSource.getProfileById(
            profileId: profileId,
            ownerUserId: ownerUserId,
          );
          if (remote != null) {
            await localDataSource.saveProfile(remote);
            return remote;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Creates a new family profile.
  ///
  /// Online: creates in Supabase and persists to Hive on success.
  /// Offline: throws [NetworkException] to prevent un-synchronized clinical mutations.
  Future<ProfileModel> createProfile(ProfileModel profile) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to create a family profile. Please check your connection and try again.',
      );
    }

    final created = await remoteDataSource.createFamilyProfile(
      profile: profile,
      ownerUserId: profile.ownerUserId,
    );

    await localDataSource.saveProfile(created);
    return created;
  }

  /// Updates an existing profile.
  ///
  /// Online: updates in Supabase and persists to Hive on success.
  /// Offline: throws [NetworkException] to prevent conflicting local state.
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to update family profile. Please check your connection and try again.',
      );
    }

    final updated = await remoteDataSource.updateProfile(
      profile: profile,
      ownerUserId: profile.ownerUserId,
    );

    await localDataSource.saveProfile(updated);
    return updated;
  }

  /// Uploads avatar photo for a profile to Supabase Storage.
  Future<ProfileModel> uploadProfilePhoto(
    String profileId,
    File photoFile, {
    required String ownerUserId,
  }) async {
    final existing = await localDataSource.getProfileById(
      profileId,
      ownerUserId: ownerUserId,
    );
    if (existing != null && existing.isArchived) {
      throw StateError('Cannot modify avatar for an archived profile.');
    }

    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to update profile avatar.',
      );
    }

    final updated = await remoteDataSource.uploadProfilePhoto(
      profileId: profileId,
      ownerUserId: ownerUserId,
      photoFile: photoFile,
    );

    await localDataSource.saveProfile(updated);

    // If an authoritative primary profile was updated, clean up any provisional key
    if (profileId.startsWith('prof_primary_') &&
        updated.profileId != profileId) {
      await localDataSource.deleteProfile(profileId);
      final activeId = await localDataSource.getActiveProfileId(ownerUserId);
      if (activeId == profileId) {
        await localDataSource.setActiveProfileId(
          profileId: updated.profileId,
          ownerUserId: ownerUserId,
        );
      }
    }

    return updated;
  }

  /// Removes avatar photo for a profile from Supabase Storage and database.
  Future<ProfileModel> deleteProfilePhoto(
    String profileId, {
    required String ownerUserId,
  }) async {
    final existing = await localDataSource.getProfileById(
      profileId,
      ownerUserId: ownerUserId,
    );
    if (existing != null && existing.isArchived) {
      throw StateError('Cannot modify avatar for an archived profile.');
    }

    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to remove profile avatar.',
      );
    }

    final updated = await remoteDataSource.deleteProfilePhoto(
      profileId: profileId,
      ownerUserId: ownerUserId,
    );

    await localDataSource.saveProfile(updated);
    return updated;
  }

  /// Returns archived profiles belonging to [ownerUserId] from local Hive storage.
  Future<List<ProfileModel>> getArchivedProfiles(String ownerUserId) async {
    final all = await localDataSource.getProfilesForUser(
      ownerUserId,
      includeArchived: true,
    );
    return all.where((p) => p.isArchived).toList();
  }

  /// Archives a non-primary family profile.
  ///
  /// Online: updates Supabase and updates Hive cache on success.
  /// Offline: throws [NetworkException] to guarantee transactional consistency with remote.
  Future<ProfileModel> archiveProfile(
    String profileId, {
    required String ownerUserId,
  }) async {
    final existing = await localDataSource.getProfileById(
      profileId,
      ownerUserId: ownerUserId,
    );
    if (existing != null && existing.isPrimary) {
      throw StateError('Primary profile cannot be archived.');
    }

    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to archive family profile. Please check your connection and try again.',
      );
    }

    final archived = await remoteDataSource.archiveProfile(
      profileId: profileId,
      ownerUserId: ownerUserId,
    );

    await localDataSource.saveProfile(archived);
    return archived;
  }

  /// Restores an archived non-primary family profile.
  ///
  /// Online: updates Supabase and updates Hive cache on success.
  /// Offline: throws [NetworkException] to guarantee transactional consistency with remote.
  Future<ProfileModel> restoreProfile(
    String profileId, {
    required String ownerUserId,
  }) async {
    final existing = await localDataSource.getProfileById(
      profileId,
      ownerUserId: ownerUserId,
    );
    if (existing != null && existing.isPrimary) {
      throw StateError('Primary profile cannot be restored.');
    }

    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to restore family profile. Please check your connection and try again.',
      );
    }

    final restored = await remoteDataSource.restoreProfile(
      profileId: profileId,
      ownerUserId: ownerUserId,
    );

    await localDataSource.saveProfile(restored);
    return restored;
  }

  /// Deleting primary profile is strictly forbidden by database invariant.
  /// Permanent family profile deletion is disabled to prevent accidental loss
  /// of clinical records and medical history. Use [archiveProfile] instead.
  Future<void> deleteProfile(
    String profileId, {
    String? ownerUserId,
  }) async {
    if (profileId.startsWith('prof_primary_')) {
      throw StateError('Primary profile cannot be deleted.');
    }

    if (hiveService.profileBox.isOpen) {
      final raw = hiveService.profileBox.get(profileId);
      if (raw is Map) {
        final profile = ProfileModel.fromMap(Map<String, dynamic>.from(raw));
        if (profile.isPrimary) {
          throw StateError('Primary profile cannot be deleted.');
        }
      }
    }

    throw UnsupportedError(
      'Permanent profile deletion is disabled to prevent accidental loss of clinical history. Use profile archival to archive inactive profiles.',
    );
  }

  /// Primary designation is immutable under Supabase schema invariant.
  Future<void> setPrimaryProfile(ProfileModel profile) async {
    throw UnsupportedError(
      'The account owner Self profile is the permanent primary profile and cannot be changed.',
    );
  }

  /// Ensures a default primary profile exists for [user].
  Future<ProfileModel> ensureDefaultProfile(UserModel user) async {
    final existing = await localDataSource.getProfilesForUser(user.id);
    if (existing.isNotEmpty) {
      var primary = existing.firstWhere(
        (p) => p.isPrimary,
        orElse: () => existing.first,
      );
      final hasNoDob =
          primary.dateOfBirth == null || primary.dateOfBirth!.trim().isEmpty;
      final userHasDob =
          user.dateOfBirth != null && user.dateOfBirth!.trim().isNotEmpty;
      final hasNoGender =
          primary.gender == null || primary.gender!.trim().isEmpty;
      final userHasGender =
          user.gender != null && user.gender!.trim().isNotEmpty;

      if ((hasNoDob && userHasDob) || (hasNoGender && userHasGender)) {
        primary = primary.copyWith(
          dateOfBirth: (hasNoDob && userHasDob)
              ? user.dateOfBirth!.trim()
              : primary.dateOfBirth,
          gender: (hasNoGender && userHasGender)
              ? user.gender!.trim()
              : primary.gender,
        );
        await localDataSource.saveProfile(primary);
        if (await connectivityService.checkConnectivity()) {
          try {
            await remoteDataSource.updateProfile(
              profile: primary,
              ownerUserId: user.id,
            );
          } catch (_) {}
        }
      }

      final activeId = await localDataSource.getActiveProfileId(user.id);
      if (activeId == null) {
        await localDataSource.setActiveProfileId(
          profileId: primary.profileId,
          ownerUserId: user.id,
        );
      }
      return primary;
    }

    // Try pulling from Supabase in case handle_new_user() trigger created it
    final isOnline = await connectivityService.checkConnectivity();
    if (isOnline) {
      try {
        final remoteProfiles = await remoteDataSource.fetchProfiles(
          ownerUserId: user.id,
        );
        if (remoteProfiles.isNotEmpty) {
          var primary = remoteProfiles.firstWhere(
            (p) => p.isPrimary,
            orElse: () => remoteProfiles.first,
          );
          final hasNoDob = primary.dateOfBirth == null ||
              primary.dateOfBirth!.trim().isEmpty;
          final userHasDob =
              user.dateOfBirth != null && user.dateOfBirth!.trim().isNotEmpty;
          final hasNoGender =
              primary.gender == null || primary.gender!.trim().isEmpty;
          final userHasGender =
              user.gender != null && user.gender!.trim().isNotEmpty;

          if ((hasNoDob && userHasDob) || (hasNoGender && userHasGender)) {
            primary = primary.copyWith(
              dateOfBirth: (hasNoDob && userHasDob)
                  ? user.dateOfBirth!.trim()
                  : primary.dateOfBirth,
              gender: (hasNoGender && userHasGender)
                  ? user.gender!.trim()
                  : primary.gender,
            );
            try {
              await remoteDataSource.updateProfile(
                profile: primary,
                ownerUserId: user.id,
              );
            } catch (_) {}
          }

          final updatedRemoteProfiles = remoteProfiles
              .map((p) => p.profileId == primary.profileId ? primary : p)
              .toList();
          await localDataSource.saveProfiles(updatedRemoteProfiles);
          await localDataSource.setActiveProfileId(
            profileId: primary.profileId,
            ownerUserId: user.id,
          );
          return primary;
        }
      } catch (_) {}
    }

    // Fallback: create local Self profile with user.id as canonical profile ID
    final defaultProfile = ProfileModel(
      profileId: user.id,
      serverProfileId: null,
      ownerUserId: user.id,
      fullName: user.name.isNotEmpty ? user.name : 'Primary Profile',
      relationship: ProfileRelationships.self,
      gender: user.gender ?? 'Male',
      dateOfBirth: user.dateOfBirth ?? '',
      bloodGroup: user.bloodGroup,
      isPrimary: true,
      notes: null,
    );

    await localDataSource.saveProfile(defaultProfile);
    await localDataSource.setActiveProfileId(
      profileId: defaultProfile.profileId,
      ownerUserId: user.id,
    );
    return defaultProfile;
  }

  /// Returns the stored active profile ID from local Hive storage for [ownerUserId].
  Future<String?> getActiveProfileId(String ownerUserId) async {
    return await localDataSource.getActiveProfileId(ownerUserId);
  }

  /// Persists the active profile ID into local Hive storage for [ownerUserId].
  Future<void> setActiveProfileId({
    required String profileId,
    required String ownerUserId,
  }) async {
    await localDataSource.setActiveProfileId(
      profileId: profileId,
      ownerUserId: ownerUserId,
    );
  }

  /// Clears active profile selection and session-specific profile cache upon sign out.
  Future<void> clearSessionProfileData([String? ownerUserId]) async {
    await localDataSource.clearActiveProfileId(ownerUserId);
  }

  /// Summary overview across family profiles with offline fallback.
  Future<List<Map<String, dynamic>>> getFamilyDashboard(
    String ownerUserId,
  ) async {
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

  /// Combined analytics across family profiles with offline fallback.
  Future<List<Map<String, dynamic>>> getFamilyAnalytics(
    String ownerUserId,
  ) async {
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
}
