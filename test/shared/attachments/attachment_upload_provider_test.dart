import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/data/repositories/profile_repository.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/shared/attachments/presentation/providers/attachment_upload_provider.dart';

import '../../core/storage/supabase_storage_service_test.dart';

class _FakeProfileRepository extends Fake implements ProfileRepository {
  final Map<String, ProfileModel> profiles = {};

  @override
  Future<ProfileModel?> getProfileById(
    String profileId, {
    String? ownerUserId,
  }) async {
    return profiles[profileId];
  }
}

class _TestAuthNotifier extends AuthNotifier {
  UserModel? _mockUser;

  _TestAuthNotifier([this._mockUser]);

  @override
  AuthState build() => AuthState(
        user: _mockUser,
        isAuthenticated: _mockUser != null,
      );

  void setUser(UserModel? u) {
    _mockUser = u;
    state = AuthState(user: u, isAuthenticated: u != null);
  }
}

void main() {
  late Directory tempDir;
  late FakeSupabaseClient fakeClient;
  late SupabaseStorageService storageService;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_provider_test_');
    fakeClient = FakeSupabaseClient();
    storageService = SupabaseStorageService(customClient: fakeClient);

    container = ProviderContainer(
      overrides: [
        supabaseStorageServiceProvider.overrideWithValue(storageService),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AttachmentUploadNotifier Tests', () {
    test('initial state is idle with 0 progress', () {
      final state = container.read(attachmentUploadNotifierProvider);
      expect(state.isIdle, isTrue);
      expect(state.progress, 0.0);
      expect(state.storagePath, isNull);
      expect(state.errorMessage, isNull);
      expect(state.canRetry, isFalse);
    });

    test('valid consultation attachment upload succeeds and updates state', () async {
      final testFile = File('${tempDir.path}/prescription.pdf');
      await testFile.writeAsBytes([1, 2, 3, 4, 5]);

      final notifier = container.read(attachmentUploadNotifierProvider.notifier);
      final confirmedPath = await notifier.uploadConsultationAttachment(
        userId: 'user_123',
        consultationId: 'consultation_456',
        file: testFile,
        attachmentId: 'att_789',
      );

      final state = container.read(attachmentUploadNotifierProvider);
      expect(confirmedPath, 'user_123/consultation_456/att_789_prescription.pdf');
      expect(state.isSuccess, isTrue);
      expect(state.progress, 1.0);
      expect(state.storagePath, confirmedPath);
      expect(state.canRetry, isFalse);
    });

    test('valid report attachment upload succeeds and updates state', () async {
      final testFile = File('${tempDir.path}/lab_scan.png');
      await testFile.writeAsBytes([10, 20, 30]);

      final notifier = container.read(attachmentUploadNotifierProvider.notifier);
      final confirmedPath = await notifier.uploadReportAttachment(
        userId: 'user_123',
        reportId: 'rep_456',
        file: testFile,
        attachmentId: 'att_001',
      );

      final state = container.read(attachmentUploadNotifierProvider);
      expect(confirmedPath, 'user_123/rep_456/att_001_lab_scan.png');
      expect(state.isSuccess, isTrue);
      expect(state.progress, 1.0);
      expect(state.storagePath, confirmedPath);
    });

    test('client validation failure sets error state and rejects retry', () async {
      // 0-byte file fails validation
      final emptyFile = File('${tempDir.path}/empty.pdf');
      await emptyFile.create();

      final notifier = container.read(attachmentUploadNotifierProvider.notifier);
      final result = await notifier.uploadConsultationAttachment(
        userId: 'user_123',
        consultationId: 'c_1',
        file: emptyFile,
      );

      final state = container.read(attachmentUploadNotifierProvider);
      expect(result, isNull);
      expect(state.isError, isTrue);
      expect(state.errorMessage, contains('0 bytes'));
      expect(state.canRetry, isFalse); // Client file error cannot be blindly retried
    });

    test('storage operation failure allows retry without deleting local file', () async {
      final testFile = File('${tempDir.path}/important_scan.jpg');
      await testFile.writeAsBytes([1, 2, 3]);

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.reportsBucket) as FakeStorageFileApi;
      bucketApi.shouldThrowOnUpload = true;

      final notifier = container.read(attachmentUploadNotifierProvider.notifier);
      final result = await notifier.uploadReportAttachment(
        userId: 'user_123',
        reportId: 'rep_1',
        file: testFile,
        attachmentId: 'att_999',
      );

      final state = container.read(attachmentUploadNotifierProvider);
      expect(result, isNull);
      expect(state.isError, isTrue);
      expect(state.canRetry, isTrue);
      expect(testFile.existsSync(), isTrue); // Local file MUST be preserved

      // Resolve transient network problem and test retry
      bucketApi.shouldThrowOnUpload = false;
      final retryResult = await notifier.retry();

      final stateAfterRetry = container.read(attachmentUploadNotifierProvider);
      expect(retryResult, 'user_123/rep_1/att_999_important_scan.jpg');
      expect(stateAfterRetry.isSuccess, isTrue);
      expect(stateAfterRetry.storagePath, retryResult);
      expect(stateAfterRetry.canRetry, isFalse);
    });

    test('reset clears state back to initial idle', () async {
      final testFile = File('${tempDir.path}/doc.pdf');
      await testFile.writeAsBytes([1]);

      final notifier = container.read(attachmentUploadNotifierProvider.notifier);
      await notifier.uploadConsultationAttachment(
        userId: 'u',
        consultationId: 'c',
        file: testFile,
      );

      notifier.reset();
      final state = container.read(attachmentUploadNotifierProvider);
      expect(state.isIdle, isTrue);
      expect(state.progress, 0.0);
      expect(state.storagePath, isNull);
    });

    test('rejects upload when requested userId does not match authenticated user session', () async {
      final testAuthNotifier = _TestAuthNotifier(
        const UserModel(
          id: 'auth_user_1',
          name: 'Active User',
          email: 'user1@example.com',
        ),
      );

      final testContainer = ProviderContainer(
        overrides: [
          supabaseStorageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => testAuthNotifier),
        ],
      );
      addTearDown(testContainer.dispose);

      final testFile = File('${tempDir.path}/doc.pdf');
      await testFile.writeAsBytes([1, 2, 3]);

      final notifier = testContainer.read(attachmentUploadNotifierProvider.notifier);
      final result = await notifier.uploadConsultationAttachment(
        userId: 'different_user_999', // Mismatched user ID
        consultationId: 'c_1',
        file: testFile,
      );

      expect(result, isNull);
      final state = testContainer.read(attachmentUploadNotifierProvider);
      expect(state.isError, isTrue);
      expect(state.errorMessage, contains('User mismatch: cannot upload attachments for another user session'));
      expect(state.canRetry, isFalse);
    });

    test('rejects avatar upload when target profile is archived', () async {
      final fakeProfileRepo = _FakeProfileRepository();
      fakeProfileRepo.profiles['archived_profile_id'] = ProfileModel(
        profileId: 'archived_profile_id',
        ownerUserId: 'user_123',
        fullName: 'Archived Member',
        relationship: 'Grandfather',
        isPrimary: false,
        isArchived: true, // Archived profile!
        archivedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final testContainer = ProviderContainer(
        overrides: [
          supabaseStorageServiceProvider.overrideWithValue(storageService),
          profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
        ],
      );
      addTearDown(testContainer.dispose);

      final testFile = File('${tempDir.path}/avatar.jpg');
      await testFile.writeAsBytes([1, 2, 3]);

      final notifier = testContainer.read(attachmentUploadNotifierProvider.notifier);
      final result = await notifier.uploadAvatar(
        userId: 'user_123',
        profileId: 'archived_profile_id',
        file: testFile,
      );

      expect(result, isNull);
      final state = testContainer.read(attachmentUploadNotifierProvider);
      expect(state.isError, isTrue);
      expect(state.errorMessage, contains('Cannot upload avatar for an archived profile.'));
      expect(state.canRetry, isFalse);
    });

    test('rejects retry when authenticated user changed since initial failure', () async {
      final testAuthNotifier = _TestAuthNotifier(
        const UserModel(
          id: 'user_initial',
          name: 'Initial User',
          email: 'initial@example.com',
        ),
      );

      final testContainer = ProviderContainer(
        overrides: [
          supabaseStorageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => testAuthNotifier),
        ],
      );
      addTearDown(testContainer.dispose);

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      bucketApi.shouldThrowOnUpload = true;

      final testFile = File('${tempDir.path}/prescription.pdf');
      await testFile.writeAsBytes([1, 2, 3]);

      final notifier = testContainer.read(attachmentUploadNotifierProvider.notifier);
      await notifier.uploadConsultationAttachment(
        userId: 'user_initial',
        consultationId: 'c_100',
        file: testFile,
      );

      expect(testContainer.read(attachmentUploadNotifierProvider).canRetry, isTrue);

      // Now session changes to another user
      testAuthNotifier.setUser(
        const UserModel(
          id: 'user_switched',
          name: 'Switched User',
          email: 'switched@example.com',
        ),
      );

      bucketApi.shouldThrowOnUpload = false;
      final retryResult = await notifier.retry();

      expect(retryResult, isNull);
      final stateAfterRetry = testContainer.read(attachmentUploadNotifierProvider);
      expect(stateAfterRetry.isError, isTrue);
      expect(stateAfterRetry.errorMessage, contains('User mismatch: authentication session changed'));
      expect(stateAfterRetry.canRetry, isFalse);
    });
  });
}
