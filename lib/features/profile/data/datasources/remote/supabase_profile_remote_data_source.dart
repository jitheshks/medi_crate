import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/storage/supabase_storage_service.dart';
import '../../../../../core/supabase/supabase_config.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../models/profile_model.dart';

/// SupabaseProfileRemoteDataSource handles direct authenticated CRUD operations
/// for user and family health profiles in `public.profiles` via Supabase PostgREST.
class SupabaseProfileRemoteDataSource {
  final SupabaseClient? customClient;
  final SupabaseStorageService? customStorageService;

  SupabaseProfileRemoteDataSource({
    this.customClient,
    this.customStorageService,
  });

  SupabaseClient get _client {
    if (customClient != null) return customClient!;
    return SupabaseConfig.client;
  }

  SupabaseStorageService get _storageService {
    if (customStorageService != null) return customStorageService!;
    return SupabaseStorageService(customClient: _client);
  }

  /// Fetches all profiles belonging to [ownerUserId] ordered with the primary profile first.
  /// If [includeArchived] is false, only active (non-archived) profiles are retrieved.
  Future<List<ProfileModel>> fetchProfiles({
    required String ownerUserId,
    bool includeArchived = false,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot fetch profiles without a valid authenticated user ID.',
      );
    }

    try {
      var query = _client
          .from('profiles')
          .select()
          .eq('user_id', trimmedOwnerId);

      if (!includeArchived) {
        query = query.eq('is_archived', false);
      }

      final response = await query
          .order('is_primary', ascending: false)
          .order('created_at', ascending: true);

      return (response as List)
          .map(
            (item) => ProfileModel.fromSupabaseJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to load profiles.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch profiles: $e');
    }
  }

  /// Fetches a single profile by [profileId] strictly verifying [ownerUserId] ownership.
  Future<ProfileModel?> getProfileById({
    required String profileId,
    required String ownerUserId,
  }) async {
    final trimmedProfileId = profileId.trim();
    final trimmedOwnerId = ownerUserId.trim();
    if (trimmedProfileId.isEmpty || trimmedOwnerId.isEmpty) {
      return null;
    }

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', trimmedProfileId)
          .eq('user_id', trimmedOwnerId)
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromSupabaseJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to load profile details.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to fetch profile: $e');
    }
  }

  /// Creates a non-primary family sub-profile owned by [ownerUserId].
  ///
  /// Strictly enforces:
  /// - `user_id` is set to [ownerUserId].
  /// - `is_primary` is always FALSE (Self is the permanent primary profile).
  /// - `relationship` cannot be 'Self'.
  Future<ProfileModel> createFamilyProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot create a family profile without an active authenticated session.',
      );
    }

    if (profile.relationship == ProfileRelationships.self) {
      throw const ValidationException(
        'Cannot create a family profile with relationship "Self". The account owner is already the primary Self profile.',
      );
    }

    final payload = profile.toSupabaseJson(includeId: false);
    payload['user_id'] = trimmedOwnerId;
    payload['is_primary'] = false; // Strictly non-primary for family sub-profiles
    payload['is_archived'] = false; // Explicitly ensure newly created profiles are active

    try {
      final response = await _client
          .from('profiles')
          .insert(payload)
          .select()
          .single();

      return ProfileModel.fromSupabaseJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to create family profiles.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to create family profile: $e');
    }
  }

  /// Updates an existing profile row owned by [ownerUserId].
  ///
  /// Strictly uses an explicit whitelist of demographic and medical history fields
  /// ([ProfileModel.toOrdinaryUpdateSupabaseJson]), guaranteeing that server-managed,
  /// immutable, or lifecycle columns (`id`, `user_id`, `is_primary`, `is_archived`,
  /// `archived_at`, `created_at`, `updated_at`, `photo_url`, `client_uuid`) are never modified.
  Future<ProfileModel> updateProfile({
    required ProfileModel profile,
    required String ownerUserId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedProfileId = profile.profileId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot update profile without an active authenticated session.',
      );
    }
    if (trimmedProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty when updating.');
    }

    // Build update payload using strict whitelist for ordinary updates
    final payload = profile.toOrdinaryUpdateSupabaseJson();

    try {
      final response = await _client
          .from('profiles')
          .update(payload)
          .eq('id', trimmedProfileId)
          .eq('user_id', trimmedOwnerId)
          .select()
          .single();

      return ProfileModel.fromSupabaseJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to update family profiles.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update profile: $e');
    }
  }

  /// Archives an existing family profile owned by [ownerUserId].
  ///
  /// Invariants:
  /// - Only non-primary family sub-profiles can be archived.
  /// - Archiving preserves the profile's UUID and linked clinical records.
  /// - Transitions `is_archived` to `true`.
  /// - The database trigger automatically assigns `archived_at`.
  Future<ProfileModel> archiveProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedProfileId = profileId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot archive profile without an active authenticated session.',
      );
    }
    if (trimmedProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty when archiving.');
    }

    final existing = await getProfileById(
      profileId: trimmedProfileId,
      ownerUserId: trimmedOwnerId,
    );
    if (existing == null) {
      throw const NotFoundException('Profile not found.');
    }
    if (existing.isPrimary) {
      throw const ValidationException('Primary profile cannot be archived.');
    }
    if (existing.isArchived) {
      return existing; // idempotent
    }

    try {
      final response = await _client
          .from('profiles')
          .update({'is_archived': true})
          .eq('id', trimmedProfileId)
          .eq('user_id', trimmedOwnerId)
          .select()
          .single();

      return ProfileModel.fromSupabaseJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to archive family profile.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to archive family profile: $e');
    }
  }

  /// Restores an archived family profile owned by [ownerUserId].
  ///
  /// Invariants:
  /// - Transitions `is_archived` to `false`.
  /// - The database trigger automatically clears `archived_at` to `null`.
  /// - Preserves the profile's UUID and historical clinical records.
  Future<ProfileModel> restoreProfile({
    required String profileId,
    required String ownerUserId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedProfileId = profileId.trim();

    if (trimmedOwnerId.isEmpty) {
      throw const UnauthorizedException(
        'Cannot restore profile without an active authenticated session.',
      );
    }
    if (trimmedProfileId.isEmpty) {
      throw const ValidationException('Profile ID cannot be empty when restoring.');
    }

    final existing = await getProfileById(
      profileId: trimmedProfileId,
      ownerUserId: trimmedOwnerId,
    );
    if (existing == null) {
      throw const NotFoundException('Profile not found.');
    }
    if (existing.isPrimary) {
      throw const ValidationException('Primary profile cannot be restored.');
    }
    if (!existing.isArchived) {
      return existing; // idempotent
    }

    try {
      final response = await _client
          .from('profiles')
          .update({'is_archived': false})
          .eq('id', trimmedProfileId)
          .eq('user_id', trimmedOwnerId)
          .select()
          .single();

      return ProfileModel.fromSupabaseJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to restore family profile.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to restore family profile: $e');
    }
  }

  /// Uploads a photo to Supabase Storage bucket `'avatars'` and updates `photo_url`
  /// with the canonical storage object path:
  /// - Family profile: `{ownerUserId}/{profileId}/{uuidFileName}`
  /// - Primary profile: `{ownerUserId}/{uuidFileName}`
  Future<ProfileModel> uploadProfilePhoto({
    required String profileId,
    required String ownerUserId,
    required File photoFile,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedProfileId = profileId.trim();

    if (trimmedOwnerId.isEmpty || trimmedProfileId.isEmpty) {
      throw const ValidationException('User ID and Profile ID are required to upload photo.');
    }

    final currentAuthUser = _client.auth.currentUser;
    if (currentAuthUser != null && currentAuthUser.id != trimmedOwnerId) {
      throw const UnauthorizedException(
        'Authenticated user session does not match the profile owner ID.',
      );
    }

    // 1. Verify the profile exists and is active (!is_archived)
    final existing = await getProfileById(
      profileId: trimmedProfileId,
      ownerUserId: trimmedOwnerId,
    );
    if (existing == null) {
      throw const NotFoundException('Profile not found.');
    }
    if (existing.isArchived) {
      throw const ValidationException(
        'Cannot upload or replace avatar for an archived profile.',
      );
    }

    final oldPhotoPath = existing.photo?.trim();

    final ext = p.extension(photoFile.path).toLowerCase().replaceAll('.', '');
    final cleanExt = ext.isEmpty ? 'jpg' : (ext == 'jpeg' ? 'jpg' : ext);
    final fileName = '${UuidUtils.generateV4()}.$cleanExt';

    // Canonical path depth: depth 2 for primary Self profile, depth 3 for family sub-profiles
    final storagePath = existing.isPrimary
        ? '$trimmedOwnerId/$fileName'
        : '$trimmedOwnerId/${existing.profileId}/$fileName';

    // 2. Upload to Supabase Storage avatars bucket
    final uploadedPath = await _storageService.uploadFile(
      bucket: SupabaseStorageService.avatarsBucket,
      storagePath: storagePath,
      file: photoFile,
      expectedUserId: trimmedOwnerId,
      upsert: false,
    );

    // 3. Persist the stable object path in public.profiles.photo_url
    try {
      final response = await updateProfilePhotoRow(
        profileId: existing.profileId,
        ownerUserId: trimmedOwnerId,
        photoUrl: uploadedPath,
      );

      final updatedProfile = ProfileModel.fromSupabaseJson(response);

      // 4. Safely delete the old avatar only after the database update succeeds
      if (oldPhotoPath != null &&
          oldPhotoPath.isNotEmpty &&
          oldPhotoPath != uploadedPath &&
          !oldPhotoPath.startsWith('http://') &&
          !oldPhotoPath.startsWith('https://')) {
        try {
          await _storageService.deleteFile(
            bucket: SupabaseStorageService.avatarsBucket,
            storagePath: oldPhotoPath,
          );
        } catch (cleanupErr) {
          debugPrint(
            '[SupabaseProfileRemoteDataSource] Old avatar cleanup failed for $oldPhotoPath: $cleanupErr',
          );
        }
      }

      return updatedProfile;
    } on PostgrestException catch (e) {
      // 5. Clean up newly uploaded file to avoid orphaned storage objects
      try {
        await _storageService.deleteFile(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: uploadedPath,
        );
      } catch (_) {}
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      try {
        await _storageService.deleteFile(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: uploadedPath,
        );
      } catch (_) {}
      throw const NetworkException('Internet connection required to update avatar.');
    } catch (e) {
      try {
        await _storageService.deleteFile(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: uploadedPath,
        );
      } catch (_) {}
      if (e is AppException) rethrow;
      throw ServerException('Failed to update avatar photo: $e');
    }
  }

  /// Removes the avatar photo for a profile:
  /// 1. Verifies profile ownership and active status (!is_archived).
  /// 2. Clears `photo_url` in `public.profiles` (`photo_url = null`).
  /// 3. Confirms database update success.
  /// 4. Deletes remote avatar object from Supabase Storage avatars bucket.
  /// 5. Returns updated profile without avatar.
  Future<ProfileModel> deleteProfilePhoto({
    required String profileId,
    required String ownerUserId,
  }) async {
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedProfileId = profileId.trim();

    if (trimmedOwnerId.isEmpty || trimmedProfileId.isEmpty) {
      throw const ValidationException('User ID and Profile ID are required to remove photo.');
    }

    final currentAuthUser = _client.auth.currentUser;
    if (currentAuthUser != null && currentAuthUser.id != trimmedOwnerId) {
      throw const UnauthorizedException(
        'Authenticated user session does not match the profile owner ID.',
      );
    }

    final existing = await getProfileById(
      profileId: trimmedProfileId,
      ownerUserId: trimmedOwnerId,
    );
    if (existing == null) {
      throw const NotFoundException('Profile not found.');
    }
    if (existing.isArchived) {
      throw const ValidationException(
        'Cannot modify avatar for an archived profile.',
      );
    }

    final oldPhotoPath = existing.photo?.trim();
    if (oldPhotoPath == null || oldPhotoPath.isEmpty) {
      return existing; // Already has no photo
    }

    try {
      final response = await updateProfilePhotoRow(
        profileId: existing.profileId,
        ownerUserId: trimmedOwnerId,
        photoUrl: null,
      );

      final updatedProfile = ProfileModel.fromSupabaseJson(response);

      if (!oldPhotoPath.startsWith('http://') && !oldPhotoPath.startsWith('https://')) {
        try {
          await _storageService.deleteFile(
            bucket: SupabaseStorageService.avatarsBucket,
            storagePath: oldPhotoPath,
          );
        } catch (storageErr) {
          debugPrint(
            '[SupabaseProfileRemoteDataSource] Storage deletion failed after photo_url cleared: $storageErr',
          );
        }
      }

      return updatedProfile;
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on SocketException {
      throw const NetworkException('Internet connection required to remove avatar.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to remove avatar photo: $e');
    }
  }

  /// Persists the updated avatar object path in public.profiles.photo_url.
  Future<Map<String, dynamic>> updateProfilePhotoRow({
    required String profileId,
    required String ownerUserId,
    required String? photoUrl,
  }) async {
    var query = _client.from('profiles').update({'photo_url': photoUrl});
    if (profileId.startsWith('prof_primary_')) {
      query = query.eq('user_id', ownerUserId).eq('is_primary', true);
    } else {
      query = query.eq('id', profileId).eq('user_id', ownerUserId);
    }
    final response = await query.select().single();
    return Map<String, dynamic>.from(response);
  }
}
