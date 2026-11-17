import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/supabase_storage_service.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/profile/presentation/providers/profile_providers.dart';

/// Status representing the lifecycle of a cloud attachment upload.
enum AttachmentUploadStatus {
  idle,
  validating,
  uploading,
  success,
  error,
}

/// Immutable state for tracking file attachment upload operations.
class AttachmentUploadState {
  final AttachmentUploadStatus status;
  final double progress;
  final String? storagePath;
  final String? errorMessage;
  final bool canRetry;

  const AttachmentUploadState({
    this.status = AttachmentUploadStatus.idle,
    this.progress = 0.0,
    this.storagePath,
    this.errorMessage,
    this.canRetry = false,
  });

  bool get isIdle => status == AttachmentUploadStatus.idle;
  bool get isValidating => status == AttachmentUploadStatus.validating;
  bool get isUploading => status == AttachmentUploadStatus.uploading;
  bool get isSuccess => status == AttachmentUploadStatus.success;
  bool get isError => status == AttachmentUploadStatus.error;

  AttachmentUploadState copyWith({
    AttachmentUploadStatus? status,
    double? progress,
    String? storagePath,
    String? errorMessage,
    bool? canRetry,
  }) {
    return AttachmentUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      storagePath: storagePath ?? this.storagePath,
      errorMessage: errorMessage ?? this.errorMessage,
      canRetry: canRetry ?? this.canRetry,
    );
  }
}

/// Riverpod provider for the singleton [SupabaseStorageService].
final Provider<SupabaseStorageService> supabaseStorageServiceProvider =
    Provider<SupabaseStorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseStorageService(customClient: client);
});

/// Riverpod Notifier managing attachment upload state, validation, and retry.
class AttachmentUploadNotifier extends Notifier<AttachmentUploadState> {
  final SupabaseStorageService? _customStorageService;

  // Cached parameters for retry capability
  _UploadParams? _lastUploadParams;

  AttachmentUploadNotifier([this._customStorageService]);

  @override
  AttachmentUploadState build() => const AttachmentUploadState();

  SupabaseStorageService get _storageService =>
      _customStorageService ?? ref.read(supabaseStorageServiceProvider);

  String? get _currentAuthUserId {
    try {
      final user = ref.read(authControllerProvider).user;
      if (user != null && user.id.trim().isNotEmpty) return user.id.trim();
    } catch (_) {}
    try {
      final sbClient = ref.read(supabaseClientProvider);
      final sbUser = sbClient.auth.currentUser;
      if (sbUser != null && sbUser.id.trim().isNotEmpty) return sbUser.id.trim();
    } catch (_) {}
    return null;
  }

  bool _validateUserSession(String userId) {
    final activeUserId = _currentAuthUserId;
    if (activeUserId != null &&
        activeUserId.isNotEmpty &&
        userId.trim() != activeUserId) {
      state = state.copyWith(
        status: AttachmentUploadStatus.error,
        errorMessage: 'User mismatch: cannot upload attachments for another user session.',
        canRetry: false,
      );
      return false;
    }
    return true;
  }

  /// Uploads a consultation attachment file to the private 'consultations' bucket.
  Future<String?> uploadConsultationAttachment({
    required String userId,
    required String consultationId,
    required File file,
    String? attachmentId,
    String? customFileName,
  }) async {
    final trimmedUserId = userId.trim();
    if (!_validateUserSession(trimmedUserId)) {
      return null;
    }

    final fileName = customFileName ?? file.path.split(Platform.pathSeparator).last;
    final storagePath = SupabaseStorageService.buildObjectPath(
      userId: trimmedUserId,
      parentId: consultationId.trim(),
      fileName: fileName,
      attachmentId: attachmentId,
    );

    _lastUploadParams = _UploadParams(
      userId: trimmedUserId,
      bucket: SupabaseStorageService.consultationsBucket,
      storagePath: storagePath,
      file: file,
    );

    return _executeUpload(
      bucket: SupabaseStorageService.consultationsBucket,
      storagePath: storagePath,
      file: file,
    );
  }

  /// Uploads a diagnostic report attachment file to the private 'reports' bucket.
  Future<String?> uploadReportAttachment({
    required String userId,
    required String reportId,
    required File file,
    String? attachmentId,
    String? customFileName,
  }) async {
    final trimmedUserId = userId.trim();
    if (!_validateUserSession(trimmedUserId)) {
      return null;
    }

    final fileName = customFileName ?? file.path.split(Platform.pathSeparator).last;
    final storagePath = SupabaseStorageService.buildObjectPath(
      userId: trimmedUserId,
      parentId: reportId.trim(),
      fileName: fileName,
      attachmentId: attachmentId,
    );

    _lastUploadParams = _UploadParams(
      userId: trimmedUserId,
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: storagePath,
      file: file,
    );

    return _executeUpload(
      bucket: SupabaseStorageService.reportsBucket,
      storagePath: storagePath,
      file: file,
    );
  }

  /// Uploads a profile avatar photo to the private 'avatars' bucket.
  Future<String?> uploadAvatar({
    required String userId,
    required String profileId,
    required File file,
    String? customFileName,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedProfileId = profileId.trim();

    if (!_validateUserSession(trimmedUserId)) {
      return null;
    }

    // Verify whether the target profile is archived before initiating upload
    try {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.getProfileById(
        trimmedProfileId,
        ownerUserId: trimmedUserId,
      );
      if (profile != null && profile.isArchived) {
        state = state.copyWith(
          status: AttachmentUploadStatus.error,
          errorMessage: 'Cannot upload avatar for an archived profile.',
          canRetry: false,
        );
        return null;
      }
    } catch (_) {
      // If profile lookup is unavailable or fails, allow storage service and DB to enforce
    }

    final fileName = customFileName ?? file.path.split(Platform.pathSeparator).last;
    final storagePath = SupabaseStorageService.buildObjectPath(
      userId: trimmedUserId,
      parentId: trimmedProfileId,
      fileName: fileName,
    );

    _lastUploadParams = _UploadParams(
      userId: trimmedUserId,
      bucket: SupabaseStorageService.avatarsBucket,
      storagePath: storagePath,
      file: file,
    );

    return _executeUpload(
      bucket: SupabaseStorageService.avatarsBucket,
      storagePath: storagePath,
      file: file,
    );
  }

  /// Retries the most recent failed upload operation using preserved parameters.
  Future<String?> retry() async {
    final params = _lastUploadParams;
    if (params == null) return null;

    final activeUserId = _currentAuthUserId;
    if (activeUserId != null &&
        activeUserId.isNotEmpty &&
        params.userId != activeUserId) {
      state = state.copyWith(
        status: AttachmentUploadStatus.error,
        errorMessage: 'User mismatch: authentication session changed since upload attempt.',
        canRetry: false,
      );
      _lastUploadParams = null;
      return null;
    }

    return _executeUpload(
      bucket: params.bucket,
      storagePath: params.storagePath,
      file: params.file,
    );
  }

  /// Resets state back to idle.
  void reset() {
    _lastUploadParams = null;
    state = const AttachmentUploadState();
  }

  Future<String?> _executeUpload({
    required String bucket,
    required String storagePath,
    required File file,
  }) async {
    // 1. Validation phase
    state = state.copyWith(
      status: AttachmentUploadStatus.validating,
      progress: 0.1,
      errorMessage: null,
      canRetry: false,
    );

    try {
      _storageService.validateFile(file, bucket: bucket);
    } on StorageValidationException catch (e) {
      state = state.copyWith(
        status: AttachmentUploadStatus.error,
        errorMessage: e.message,
        canRetry: false,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        status: AttachmentUploadStatus.error,
        errorMessage: 'Invalid file: $e',
        canRetry: false,
      );
      return null;
    }

    // 2. Upload phase
    state = state.copyWith(
      status: AttachmentUploadStatus.uploading,
      progress: 0.5,
    );

    try {
      final confirmedPath = await _storageService.uploadFile(
        bucket: bucket,
        storagePath: storagePath,
        file: file,
      );

      state = state.copyWith(
        status: AttachmentUploadStatus.success,
        progress: 1.0,
        storagePath: confirmedPath,
        errorMessage: null,
        canRetry: false,
      );
      return confirmedPath;
    } on StorageOperationException catch (e) {
      state = state.copyWith(
        status: AttachmentUploadStatus.error,
        errorMessage: e.message,
        canRetry: true,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        status: AttachmentUploadStatus.error,
        errorMessage: 'Upload failed: $e',
        canRetry: true,
      );
      return null;
    }
  }
}

class _UploadParams {
  final String userId;
  final String bucket;
  final String storagePath;
  final File file;

  const _UploadParams({
    required this.userId,
    required this.bucket,
    required this.storagePath,
    required this.file,
  });
}

/// NotifierProvider for [AttachmentUploadNotifier].
final NotifierProvider<AttachmentUploadNotifier, AttachmentUploadState>
    attachmentUploadNotifierProvider =
    NotifierProvider<AttachmentUploadNotifier, AttachmentUploadState>(
  AttachmentUploadNotifier.new,
);
