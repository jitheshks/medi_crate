import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/supabase_storage_service_test.dart';

class FakeUser extends Fake implements User {
  final String _id;
  FakeUser(this._id);
  @override
  String get id => _id;
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  User? user;
  @override
  User? get currentUser => user;
}

class FakeSupabaseClientWithAuth extends Fake implements SupabaseClient {
  final FakeSupabaseStorageClient mockStorage = FakeSupabaseStorageClient();
  final FakeGoTrueClient mockAuth = FakeGoTrueClient();

  @override
  SupabaseStorageClient get storage => mockStorage;

  @override
  GoTrueClient get auth => mockAuth;
}

class _TestableProfileRemoteDataSource extends SupabaseProfileRemoteDataSource {
  ProfileModel? profileToReturn;
  bool shouldThrowDbErrorOnUpdate = false;
  Map<String, dynamic>? lastUpdatePayload;

  _TestableProfileRemoteDataSource({
    required super.customClient,
    required super.customStorageService,
  });

  @override
  Future<ProfileModel?> getProfileById({
    required String profileId,
    required String ownerUserId,
  }) async {
    return profileToReturn;
  }

  @override
  Future<Map<String, dynamic>> updateProfilePhotoRow({
    required String profileId,
    required String ownerUserId,
    required String? photoUrl,
  }) async {
    if (shouldThrowDbErrorOnUpdate) {
      throw const ServerException('Simulated database update failure');
    }
    lastUpdatePayload = {
      'id': profileId,
      'user_id': ownerUserId,
      'full_name': profileToReturn?.fullName ?? 'Test Member',
      'relationship': profileToReturn?.relationship ?? 'Sister',
      'is_primary': profileToReturn?.isPrimary ?? false,
      'is_archived': profileToReturn?.isArchived ?? false,
      'photo_url': photoUrl,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    return lastUpdatePayload!;
  }
}

void main() {
  late Directory tempDir;
  late FakeSupabaseClientWithAuth fakeClient;
  late SupabaseStorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('avatar_lifecycle_test_');
    fakeClient = FakeSupabaseClientWithAuth();
    fakeClient.mockAuth.user = FakeUser('user_owner');
    storageService = SupabaseStorageService(customClient: fakeClient);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Avatar Lifecycle Hardening in SupabaseProfileRemoteDataSource', () {
    test('rejects avatar upload if profile is archived', () async {
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_archived_1',
        ownerUserId: 'user_owner',
        fullName: 'Archived Grandpa',
        relationship: 'Grandfather',
        isPrimary: false,
        isArchived: true,
        archivedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final photoFile = File('${tempDir.path}/pic.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      await expectLater(
        dataSource.uploadProfilePhoto(
          profileId: 'prof_archived_1',
          ownerUserId: 'user_owner',
          photoFile: photoFile,
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Cannot upload or replace avatar for an archived profile'),
        )),
      );

      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      expect(avatarBucket.uploadCalls, isEmpty);
    });

    test('rejects avatar removal if profile is archived', () async {
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_archived_1',
        ownerUserId: 'user_owner',
        fullName: 'Archived Grandpa',
        relationship: 'Grandfather',
        isPrimary: false,
        isArchived: true,
        photo: 'user_owner/prof_archived_1/avatar.jpg',
        archivedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await expectLater(
        dataSource.deleteProfilePhoto(
          profileId: 'prof_archived_1',
          ownerUserId: 'user_owner',
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Cannot modify avatar for an archived profile'),
        )),
      );
    });

    test('rejects upload if session user does not match ownerUserId', () async {
      fakeClient.mockAuth.user = FakeUser('attacker_user');
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      final photoFile = File('${tempDir.path}/pic.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      await expectLater(
        dataSource.uploadProfilePhoto(
          profileId: 'prof_1',
          ownerUserId: 'user_owner',
          photoFile: photoFile,
        ),
        throwsA(isA<UnauthorizedException>().having(
          (e) => e.message,
          'message',
          contains('Authenticated user session does not match'),
        )),
      );
    });

    test('rejects removal if session user does not match ownerUserId', () async {
      fakeClient.mockAuth.user = FakeUser('attacker_user');
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      await expectLater(
        dataSource.deleteProfilePhoto(
          profileId: 'prof_1',
          ownerUserId: 'user_owner',
        ),
        throwsA(isA<UnauthorizedException>().having(
          (e) => e.message,
          'message',
          contains('Authenticated user session does not match'),
        )),
      );
    });

    test('uploads primary profile avatar to canonical depth-2 path (ownerUserId/uuid.ext)', () async {
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_primary_123',
        ownerUserId: 'user_owner',
        fullName: 'Self User',
        relationship: 'Self',
        isPrimary: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final photoFile = File('${tempDir.path}/avatar.png');
      await photoFile.writeAsBytes([1, 2, 3]);

      final updated = await dataSource.uploadProfilePhoto(
        profileId: 'prof_primary_123',
        ownerUserId: 'user_owner',
        photoFile: photoFile,
      );

      expect(updated.photo, isNotNull);
      final segments = updated.photo!.split('/');
      // Depth 2: user_owner/<uuid>.png
      expect(segments.length, 2);
      expect(segments[0], 'user_owner');
      expect(segments[1].endsWith('.png'), isTrue);
    });

    test('uploads family profile avatar to canonical depth-3 path (ownerUserId/profileId/uuid.ext)', () async {
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_fam_456',
        ownerUserId: 'user_owner',
        fullName: 'Daughter Anna',
        relationship: 'Daughter',
        isPrimary: false,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final photoFile = File('${tempDir.path}/avatar.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      final updated = await dataSource.uploadProfilePhoto(
        profileId: 'prof_fam_456',
        ownerUserId: 'user_owner',
        photoFile: photoFile,
      );

      expect(updated.photo, isNotNull);
      final segments = updated.photo!.split('/');
      // Depth 3: user_owner/prof_fam_456/<uuid>.jpg
      expect(segments.length, 3);
      expect(segments[0], 'user_owner');
      expect(segments[1], 'prof_fam_456');
      expect(segments[2].endsWith('.jpg'), isTrue);
    });

    test('generates unique UUID-based filenames for successive uploads', () async {
      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_fam_456',
        ownerUserId: 'user_owner',
        fullName: 'Daughter Anna',
        relationship: 'Daughter',
        isPrimary: false,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final photoFile1 = File('${tempDir.path}/pic1.jpg');
      await photoFile1.writeAsBytes([1, 2]);
      final photoFile2 = File('${tempDir.path}/pic2.jpg');
      await photoFile2.writeAsBytes([3, 4]);

      final updated1 = await dataSource.uploadProfilePhoto(
        profileId: 'prof_fam_456',
        ownerUserId: 'user_owner',
        photoFile: photoFile1,
      );
      final updated2 = await dataSource.uploadProfilePhoto(
        profileId: 'prof_fam_456',
        ownerUserId: 'user_owner',
        photoFile: photoFile2,
      );

      expect(updated1.photo, isNot(equals(updated2.photo)));
    });

    test('replaces avatar: deletes old avatar only after DB update succeeds', () async {
      final oldPath = 'user_owner/prof_active_1/avatar_old.jpg';
      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarBucket.storedFiles[oldPath] = Uint8List.fromList([99, 98]);

      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        fullName: 'Active Sister',
        relationship: 'Sister',
        isPrimary: false,
        isArchived: false,
        photo: oldPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final photoFile = File('${tempDir.path}/pic_new.jpg');
      await photoFile.writeAsBytes([1, 2, 3, 4]);

      final updated = await dataSource.uploadProfilePhoto(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        photoFile: photoFile,
      );

      expect(updated.profileId, 'prof_active_1');
      expect(avatarBucket.uploadCalls.length, 1);
      final newUploadedPath = avatarBucket.uploadCalls.first;

      // Old avatar was deleted from storage
      expect(avatarBucket.removeCalls, contains(oldPath));
      // New avatar is stored
      expect(avatarBucket.storedFiles.containsKey(newUploadedPath), isTrue);
    });

    test('replacement succeeds even if old avatar cleanup fails', () async {
      final oldPath = 'user_owner/prof_active_1/avatar_old.jpg';
      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarBucket.storedFiles[oldPath] = Uint8List.fromList([99, 98]);
      avatarBucket.shouldThrowOnRemove = true; // Simulating old object cleanup failure

      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        fullName: 'Active Sister',
        relationship: 'Sister',
        isPrimary: false,
        isArchived: false,
        photo: oldPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final photoFile = File('${tempDir.path}/pic_new.jpg');
      await photoFile.writeAsBytes([1, 2, 3, 4]);

      // Should still succeed and return the updated profile with new photo
      final updated = await dataSource.uploadProfilePhoto(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        photoFile: photoFile,
      );

      expect(updated.photo, isNotNull);
      expect(updated.photo, isNot(equals(oldPath)));
    });

    test('cleans up newly uploaded avatar if DB update fails to avoid orphan', () async {
      final oldPath = 'user_owner/prof_active_1/avatar_old.jpg';
      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarBucket.storedFiles[oldPath] = Uint8List.fromList([99, 98]);

      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        fullName: 'Active Sister',
        relationship: 'Sister',
        isPrimary: false,
        isArchived: false,
        photo: oldPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      dataSource.shouldThrowDbErrorOnUpdate = true; // DB update failure!

      final photoFile = File('${tempDir.path}/pic_orphan_test.jpg');
      await photoFile.writeAsBytes([1, 2, 3]);

      await expectLater(
        dataSource.uploadProfilePhoto(
          profileId: 'prof_active_1',
          ownerUserId: 'user_owner',
          photoFile: photoFile,
        ),
        throwsA(isA<ServerException>()),
      );

      // Verify new avatar was uploaded then removed (cleaned up) from storage
      expect(avatarBucket.uploadCalls.length, 1);
      final newUploadedPath = avatarBucket.uploadCalls.last;
      expect(avatarBucket.removeCalls, contains(newUploadedPath));

      // Old avatar was NOT deleted
      expect(avatarBucket.removeCalls, isNot(contains(oldPath)));
      expect(avatarBucket.storedFiles.containsKey(oldPath), isTrue);
    });

    test('successfully removes avatar: updates DB photo_url to null and deletes storage object', () async {
      final oldPath = 'user_owner/prof_active_1/avatar_old.jpg';
      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarBucket.storedFiles[oldPath] = Uint8List.fromList([99, 98]);

      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        fullName: 'Active Sister',
        relationship: 'Sister',
        isPrimary: false,
        isArchived: false,
        photo: oldPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = await dataSource.deleteProfilePhoto(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
      );

      expect(updated.photo, isNull);
      expect(avatarBucket.removeCalls, contains(oldPath));
      expect(avatarBucket.storedFiles.containsKey(oldPath), isFalse);
    });

    test('avatar removal DB failure preserves old storage object', () async {
      final oldPath = 'user_owner/prof_active_1/avatar_old.jpg';
      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarBucket.storedFiles[oldPath] = Uint8List.fromList([99, 98]);

      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        fullName: 'Active Sister',
        relationship: 'Sister',
        isPrimary: false,
        isArchived: false,
        photo: oldPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      dataSource.shouldThrowDbErrorOnUpdate = true; // DB update failure

      await expectLater(
        dataSource.deleteProfilePhoto(
          profileId: 'prof_active_1',
          ownerUserId: 'user_owner',
        ),
        throwsA(isA<ServerException>()),
      );

      // Old avatar was NOT removed from storage
      expect(avatarBucket.removeCalls, isEmpty);
      expect(avatarBucket.storedFiles.containsKey(oldPath), isTrue);
    });

    test('avatar removal storage deletion failure retains cleared DB reference', () async {
      final oldPath = 'user_owner/prof_active_1/avatar_old.jpg';
      final avatarBucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarBucket.storedFiles[oldPath] = Uint8List.fromList([99, 98]);
      avatarBucket.shouldThrowOnRemove = true; // Storage delete fails

      final dataSource = _TestableProfileRemoteDataSource(
        customClient: fakeClient,
        customStorageService: storageService,
      );

      dataSource.profileToReturn = ProfileModel(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
        fullName: 'Active Sister',
        relationship: 'Sister',
        isPrimary: false,
        isArchived: false,
        photo: oldPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Deleting photo still returns the profile with photo == null
      final updated = await dataSource.deleteProfilePhoto(
        profileId: 'prof_active_1',
        ownerUserId: 'user_owner',
      );

      expect(updated.photo, isNull);
    });
  });
}
