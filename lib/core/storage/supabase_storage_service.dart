import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Exception thrown when file validation fails before attempting a storage operation.
class StorageValidationException implements Exception {
  final String message;
  const StorageValidationException(this.message);

  @override
  String toString() => 'StorageValidationException: $message';
}

/// Exception thrown when a Supabase Storage network or server operation fails.
class StorageOperationException implements Exception {
  final String message;
  final dynamic originalError;
  const StorageOperationException(this.message, [this.originalError]);

  @override
  String toString() =>
      'StorageOperationException: $message${originalError != null ? " ($originalError)" : ""}';
}

/// SupabaseStorageService manages secure file uploads, downloads, signed URL generation,
/// and file deletion across MediCrate's private Supabase Storage buckets.
///
/// Follows strict clinical isolation principles:
/// 1. All clinical attachments are stored in private buckets ('consultations', 'reports', 'avatars').
/// 2. Tenant isolation is enforced via object path conventions:
///    - Consultations/Reports: `{userId}/{parentId}/{fileName}`
///    - Avatars: `{userId}/{profileId}/{fileName}` or `{userId}/{fileName}`
/// 3. File extensions and MIME types are strictly validated before upload.
/// 4. Size limits (25MB for clinical documents, 5MB for avatars) are strictly enforced.
class SupabaseStorageService {
  static const String consultationsBucket = 'consultations';
  static const String reportsBucket = 'reports';
  static const String avatarsBucket = 'avatars';

  /// Default page size for paginated Storage listing queries.
  static const int defaultListPageSize = 100;

  /// Default batch size for bounded Storage remove operations.
  static const int defaultDeleteBatchSize = 100;

  /// Maximum allowed purge rounds to protect against runaway or infinite purge loops.
  static const int maxPurgeRounds = 5;

  /// Maximum page iterations per folder to prevent infinite listing loops.
  static const int maxPagesPerFolder = 1000;

  /// Explicitly supported private buckets.
  static const Set<String> validBuckets = {
    consultationsBucket,
    reportsBucket,
    avatarsBucket,
  };

  /// Maximum file size for consultation attachments: 25 MB (26,214,400 bytes).
  static const int maxConsultationSizeBytes = 26214400;

  /// Maximum file size for report attachments: 25 MB (26,214,400 bytes).
  static const int maxReportSizeBytes = 26214400;

  /// Maximum file size for user profile avatars: 5 MB (5,242,880 bytes).
  static const int maxAvatarSizeBytes = 5242880;

  /// Allowed file extensions for medical documents (Consultations & Reports).
  static const Set<String> allowedDocumentExtensions = {
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Allowed file extensions for profile photos (Avatars).
  static const Set<String> allowedAvatarExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Mapping from file extension to canonical MIME type.
  static const Map<String, String> extensionToCanonicalMime = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  final SupabaseClient? customClient;

  const SupabaseStorageService({this.customClient});

  SupabaseClient get _client {
    if (customClient != null) return customClient!;
    return SupabaseConfig.client;
  }

  String? get _currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Validates that [bucket] is one of the explicitly supported buckets.
  void validateBucket(String bucket) {
    if (!validBuckets.contains(bucket)) {
      throw StorageValidationException(
        'Unsupported storage bucket "$bucket". Supported buckets are: ${validBuckets.join(', ')}.',
      );
    }
  }

  /// Sanitizes a file name for safe cloud storage object paths.
  static String sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'attachment_${DateTime.now().millisecondsSinceEpoch}.dat';
    }
    // Remove directory traversal tokens and non-alphanumeric/period/underscore/hyphen characters
    final baseName = p.basename(trimmed);
    return baseName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Resolves the canonical MIME type based on file extension.
  static String resolveMimeType(String fileName, {String? fallback}) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    return extensionToCanonicalMime[ext] ?? fallback ?? 'application/octet-stream';
  }

  /// Validates that an explicitly provided [mimeType] or [contentType] matches the canonical MIME type
  /// for the [fileName] or [storagePath] extension. Throws [StorageValidationException] on mismatch.
  void validateMimeTypeConsistency({
    String? fileName,
    String? storagePath,
    String? mimeType,
    String? contentType,
  }) {
    final target = fileName ?? storagePath ?? '';
    final type = mimeType ?? contentType ?? '';
    final ext = p.extension(target).toLowerCase().replaceAll('.', '');
    final canonical = extensionToCanonicalMime[ext];
    if (canonical != null && type.isNotEmpty) {
      final normalized = type.trim().toLowerCase();
      if (normalized != canonical) {
        throw StorageValidationException(
          'MIME type mismatch: extension ".$ext" expects "$canonical", but received "$type" which contradicts the file extension.',
        );
      }
    }
  }

  /// Validates that [storagePath] adheres to security and depth constraints for [bucket].
  void validateStoragePath({
    required String bucket,
    required String storagePath,
    String? expectedUserId,
  }) {
    validateBucket(bucket);

    final trimmed = storagePath.trim();
    if (trimmed.isEmpty) {
      throw const StorageValidationException('Storage path cannot be empty.');
    }

    if (trimmed.startsWith('/') || trimmed.endsWith('/')) {
      throw StorageValidationException(
        'Storage path cannot have leading or trailing slashes: "$storagePath".',
      );
    }

    if (trimmed.contains('\\')) {
      throw StorageValidationException(
        'Storage path cannot contain backslashes: "$storagePath".',
      );
    }

    if (trimmed.contains('//')) {
      throw StorageValidationException(
        'Storage path cannot contain empty path segments ("//"): "$storagePath".',
      );
    }

    final segments = trimmed.split('/');
    for (final seg in segments) {
      final segTrimmed = seg.trim();
      if (segTrimmed.isEmpty) {
        throw StorageValidationException(
          'Storage path contains empty segment: "$storagePath".',
        );
      }
      if (segTrimmed == '..' || segTrimmed == '.') {
        throw StorageValidationException(
          'Storage path contains directory traversal tokens ("$segTrimmed"): "$storagePath".',
        );
      }
    }

    // Validate expected user ownership
    final pathUserId = segments[0];
    final authUserId = _currentUserId;
    if (authUserId != null && authUserId.isNotEmpty) {
      if (expectedUserId != null &&
          expectedUserId.trim().isNotEmpty &&
          expectedUserId.trim() != authUserId) {
        throw StorageValidationException(
          'Caller-provided expectedUserId ("$expectedUserId") does not match authenticated user session ("$authUserId").',
        );
      }
      if (pathUserId != authUserId) {
        throw StorageValidationException(
          'Storage path user ID ("$pathUserId") does not match authenticated user session ("$authUserId").',
        );
      }
    } else if (expectedUserId != null && expectedUserId.trim().isNotEmpty) {
      if (pathUserId != expectedUserId.trim()) {
        throw StorageValidationException(
          'Storage path user ID ("$pathUserId") does not match expected user ("$expectedUserId").',
        );
      }
    }

    if (bucket == consultationsBucket || bucket == reportsBucket) {
      // Format: {user_id}/{parent_id}/{filename} (depth 3)
      if (segments.length != 3) {
        throw StorageValidationException(
          'Invalid path depth for bucket "$bucket". Expected format: {userId}/{parentId}/{fileName}, received: "$storagePath".',
        );
      }

      final parentId = segments[1];
      if (parentId.trim().isEmpty) {
        throw StorageValidationException('Parent ID segment cannot be empty: "$storagePath".');
      }
    } else if (bucket == avatarsBucket) {
      // Format: {user_id}/{profile_id}/{avatar_filename} (depth 3) or {user_id}/{avatar_filename} (depth 2)
      if (segments.length != 2 && segments.length != 3) {
        throw StorageValidationException(
          'Invalid path depth for bucket "$bucket". Expected format: {userId}/{profileId}/{fileName} or {userId}/{fileName}, received: "$storagePath".',
        );
      }

      if (segments.length == 3) {
        final profileId = segments[1];
        if (profileId.trim().isEmpty) {
          throw StorageValidationException('Profile ID segment cannot be empty: "$storagePath".');
        }
      }
    }

    // Validate file extension on the filename segment
    final fileName = segments.last;
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    if (ext.isEmpty) {
      throw StorageValidationException(
        'Storage path file name has no extension: "$fileName".',
      );
    }

    final allowedExts = (bucket == avatarsBucket)
        ? allowedAvatarExtensions
        : allowedDocumentExtensions;
    if (!allowedExts.contains(ext)) {
      throw StorageValidationException(
        'File extension ".$ext" is not supported for bucket "$bucket". Allowed formats: ${allowedExts.join(', ')}.',
      );
    }
  }

  /// Validates a local [file] against bucket constraints before upload.
  /// Throws [StorageValidationException] on validation failure.
  void validateFile(File file, {required String bucket}) {
    validateBucket(bucket);

    if (!file.existsSync()) {
      throw StorageValidationException('The local file does not exist: ${file.path}');
    }

    final sizeBytes = file.lengthSync();
    if (sizeBytes <= 0) {
      throw const StorageValidationException('Attachment file cannot be empty (0 bytes).');
    }

    final maxAllowed = (bucket == avatarsBucket)
        ? maxAvatarSizeBytes
        : maxConsultationSizeBytes;

    if (sizeBytes > maxAllowed) {
      final maxMb = (maxAllowed / (1024 * 1024)).toStringAsFixed(0);
      final actualMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      throw StorageValidationException(
        'File size ($actualMb MB) exceeds the maximum allowed limit of $maxMb MB.',
      );
    }

    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final allowedExts = (bucket == avatarsBucket)
        ? allowedAvatarExtensions
        : allowedDocumentExtensions;

    if (!allowedExts.contains(ext)) {
      throw StorageValidationException(
        'File extension ".$ext" is not supported. Allowed formats: ${allowedExts.join(', ')}.',
      );
    }
  }

  /// Validates raw binary [bytes] against bucket constraints before upload.
  void validateBytes(
    Uint8List bytes, {
    required String fileName,
    required String bucket,
  }) {
    validateBucket(bucket);

    if (bytes.isEmpty) {
      throw const StorageValidationException('Attachment data cannot be empty (0 bytes).');
    }

    final maxAllowed = (bucket == avatarsBucket)
        ? maxAvatarSizeBytes
        : maxConsultationSizeBytes;

    if (bytes.length > maxAllowed) {
      final maxMb = (maxAllowed / (1024 * 1024)).toStringAsFixed(0);
      final actualMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw StorageValidationException(
        'File size ($actualMb MB) exceeds the maximum allowed limit of $maxMb MB.',
      );
    }

    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    final allowedExts = (bucket == avatarsBucket)
        ? allowedAvatarExtensions
        : allowedDocumentExtensions;

    if (!allowedExts.contains(ext)) {
      throw StorageValidationException(
        'File extension ".$ext" is not supported. Allowed formats: ${allowedExts.join(', ')}.',
      );
    }
  }

  /// Constructs a standardized, tenant-isolated object path:
  /// `{userId}/{parentId}/{attachmentId}_{sanitizedFileName}`
  static String buildObjectPath({
    required String userId,
    required String parentId,
    required String fileName,
    String? attachmentId,
  }) {
    final cleanName = sanitizeFileName(fileName);
    final prefix = (attachmentId != null && attachmentId.isNotEmpty)
        ? '${attachmentId}_'
        : '';
    return '$userId/$parentId/$prefix$cleanName';
  }

  /// Uploads a local [file] to [bucket] at [storagePath].
  ///
  /// Preserves the local file on disk regardless of upload outcome.
  /// Clinical attachments default to [upsert: false] to prevent accidental overwrites.
  /// Avatars default to [upsert: true] for intentional photo replacements.
  /// Returns the confirmed [storagePath] on success.
  Future<String> uploadFile({
    required String bucket,
    required String storagePath,
    required File file,
    String? mimeType,
    bool? upsert,
    String? expectedUserId,
  }) async {
    validateBucket(bucket);
    validateStoragePath(
      bucket: bucket,
      storagePath: storagePath,
      expectedUserId: expectedUserId,
    );
    validateFile(file, bucket: bucket);

    final resolvedMime = mimeType ?? resolveMimeType(file.path);
    validateMimeTypeConsistency(fileName: file.path, mimeType: resolvedMime);

    // Validate source file extension matches destination object path extension
    final sourceExt = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final destExt = p.extension(storagePath).toLowerCase().replaceAll('.', '');
    final normSource = (sourceExt == 'jpeg') ? 'jpg' : sourceExt;
    final normDest = (destExt == 'jpeg') ? 'jpg' : destExt;
    if (sourceExt.isNotEmpty && destExt.isNotEmpty && normSource != normDest) {
      throw StorageValidationException(
        'Source file extension (".$sourceExt") does not match destination path extension (".$destExt").',
      );
    }

    final effectiveUpsert = upsert ?? (bucket == avatarsBucket);

    try {
      await _client.storage.from(bucket).upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: resolvedMime,
              upsert: effectiveUpsert,
            ),
          );
      return storagePath;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Upload failed for $storagePath: $e');
      throw StorageOperationException('Failed to upload file to storage', e);
    }
  }

  /// Uploads raw binary [bytes] to [bucket] at [storagePath].
  Future<String> uploadBytes({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    bool? upsert,
    String? expectedUserId,
  }) async {
    validateBucket(bucket);
    validateStoragePath(
      bucket: bucket,
      storagePath: storagePath,
      expectedUserId: expectedUserId,
    );
    validateBytes(bytes, fileName: fileName, bucket: bucket);

    final resolvedMime = mimeType ?? resolveMimeType(fileName);
    validateMimeTypeConsistency(fileName: fileName, mimeType: resolvedMime);

    // Validate source file name extension matches destination object path extension
    final sourceExt = p.extension(fileName).toLowerCase().replaceAll('.', '');
    final destExt = p.extension(storagePath).toLowerCase().replaceAll('.', '');
    final normSource = (sourceExt == 'jpeg') ? 'jpg' : sourceExt;
    final normDest = (destExt == 'jpeg') ? 'jpg' : destExt;
    if (sourceExt.isNotEmpty && destExt.isNotEmpty && normSource != normDest) {
      throw StorageValidationException(
        'Source file name extension (".$sourceExt") does not match destination path extension (".$destExt").',
      );
    }

    final effectiveUpsert = upsert ?? (bucket == avatarsBucket);

    try {
      await _client.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: resolvedMime,
              upsert: effectiveUpsert,
            ),
          );
      return storagePath;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Binary upload failed for $storagePath: $e');
      throw StorageOperationException('Failed to upload binary data to storage', e);
    }
  }

  /// Generates a time-limited signed URL for viewing or downloading a private attachment.
  ///
  /// Defaults to 1 hour (3600 seconds) validity.
  Future<String> createSignedUrl({
    required String bucket,
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    validateBucket(bucket);
    validateStoragePath(bucket: bucket, storagePath: storagePath);

    try {
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(storagePath, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Signed URL generation failed for $storagePath: $e');
      throw StorageOperationException('Failed to generate signed URL', e);
    }
  }

  /// Downloads binary bytes of an attachment from [bucket].
  Future<Uint8List> downloadBytes({
    required String bucket,
    required String storagePath,
  }) async {
    validateBucket(bucket);
    validateStoragePath(bucket: bucket, storagePath: storagePath);

    try {
      final bytes = await _client.storage.from(bucket).download(storagePath);
      return bytes;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Download failed for $storagePath: $e');
      throw StorageOperationException('Failed to download attachment', e);
    }
  }

  /// Downloads an attachment and saves it to a persistent local [destinationFilePath].
  Future<File> downloadToFile({
    required String bucket,
    required String storagePath,
    required String destinationFilePath,
  }) async {
    validateBucket(bucket);
    validateStoragePath(bucket: bucket, storagePath: storagePath);

    final bytes = await downloadBytes(bucket: bucket, storagePath: storagePath);

    final destFile = File(destinationFilePath);
    final parentDir = destFile.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    await destFile.writeAsBytes(bytes, flush: true);
    return destFile;
  }

  /// Deletes a remote attachment object from [bucket].
  Future<void> deleteFile({
    required String bucket,
    required String storagePath,
  }) async {
    validateBucket(bucket);
    validateStoragePath(bucket: bucket, storagePath: storagePath);

    try {
      await _client.storage.from(bucket).remove([storagePath]);
    } catch (e) {
      debugPrint('[SupabaseStorageService] Delete failed for $storagePath: $e');
      throw StorageOperationException('Failed to delete attachment from storage', e);
    }
  }

  /// Lists and deletes all files inside `{userId}/{parentId}` in [bucket].
  ///
  /// Guarantees complete enumeration through pagination and recursive traversal of subfolders.
  Future<void> deleteParentFolder({
    required String bucket,
    required String parentId,
    required String userId,
  }) async {
    validateBucket(bucket);
    final cleanUserId = userId.trim();
    final cleanParentId = parentId.trim();
    if (cleanUserId.isEmpty || cleanParentId.isEmpty) {
      throw const StorageValidationException('User ID and Parent ID cannot be empty.');
    }
    if (cleanUserId.contains('..') || cleanUserId.contains('/') || cleanUserId.contains('\\')) {
      throw StorageValidationException('Invalid User ID: "$userId".');
    }
    if (cleanParentId.contains('..') || cleanParentId.contains('/') || cleanParentId.contains('\\')) {
      throw StorageValidationException('Invalid Parent ID: "$parentId".');
    }

    final folderPath = '$cleanUserId/$cleanParentId';
    try {
      final pathsToDelete = await _collectUserFilePathsRecursively(
        bucket: bucket,
        rootFolder: folderPath,
        userId: cleanUserId,
      );

      if (pathsToDelete.isNotEmpty) {
        for (int i = 0; i < pathsToDelete.length; i += defaultDeleteBatchSize) {
          final end = (i + defaultDeleteBatchSize < pathsToDelete.length)
              ? i + defaultDeleteBatchSize
              : pathsToDelete.length;
          final chunk = pathsToDelete.sublist(i, end);
          await _client.storage.from(bucket).remove(chunk);
        }
        debugPrint(
          '[SupabaseStorageService] Cleaned up ${pathsToDelete.length} files from folder $folderPath in $bucket',
        );
      }
    } catch (e) {
      debugPrint(
        '[SupabaseStorageService] Failed to clean up folder $folderPath in $bucket: $e',
      );
      if (e is StorageOperationException) rethrow;
      throw StorageOperationException(
        'Failed to clean up storage folder $folderPath: $e',
      );
    }
  }

  /// Lists and purges all storage files belonging to [userId] across all private
  /// buckets (`avatars`, `consultations`, `reports`) using the Supabase Storage API.
  ///
  /// Features:
  /// - Explicit limit/offset pagination to enumerate arbitrarily large directories.
  /// - Recursive subfolder traversal.
  /// - Bounded batch deletion supported by the Storage API.
  /// - Repeat enumeration until verified zero objects remain.
  /// - Strict user isolation (never deletes other users' files).
  /// - Full error propagation without silent fallbacks.
  Future<void> deleteAllUserFiles({required String userId}) async {
    final cleanUserId = userId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (cleanUserId.isEmpty) {
      throw const StorageValidationException('User ID cannot be empty.');
    }
    if (cleanUserId.contains('..') || cleanUserId.contains('/') || cleanUserId.contains('\\')) {
      throw StorageValidationException('Invalid User ID: "$userId".');
    }

    for (final bucket in [avatarsBucket, consultationsBucket, reportsBucket]) {
      await _deleteBucketFilesForUser(
        bucket: bucket,
        userId: cleanUserId,
      );
    }
  }

  /// Configurable version of [deleteAllUserFiles] allowing custom [pageSize] and [batchSize] for testing.
  @visibleForTesting
  Future<void> deleteAllUserFilesWithConfig({
    required String userId,
    int pageSize = defaultListPageSize,
    int batchSize = defaultDeleteBatchSize,
  }) async {
    final cleanUserId = userId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (cleanUserId.isEmpty) {
      throw const StorageValidationException('User ID cannot be empty.');
    }
    if (cleanUserId.contains('..') || cleanUserId.contains('/') || cleanUserId.contains('\\')) {
      throw StorageValidationException('Invalid User ID: "$userId".');
    }

    for (final bucket in [avatarsBucket, consultationsBucket, reportsBucket]) {
      await _deleteBucketFilesForUser(
        bucket: bucket,
        userId: cleanUserId,
        pageSize: pageSize,
        batchSize: batchSize,
      );
    }
  }

  /// Lists all direct items in [folderPath] within [bucket] using explicit limit/offset pagination.
  ///
  /// Guarantees complete enumeration beyond the default 100-item page limit.
  /// Detects and throws [StorageOperationException] if duplicate pages indicate an infinite pagination loop.
  Future<List<FileObject>> _listFolderPaginated({
    required String bucket,
    required String folderPath,
    int pageSize = defaultListPageSize,
  }) async {
    final List<FileObject> allItems = [];
    final Set<String> seenKeys = {};
    int offset = 0;
    int pageIndex = 0;

    while (true) {
      pageIndex++;
      if (pageIndex > maxPagesPerFolder) {
        throw StorageOperationException(
          'Storage enumeration exceeded maximum page depth ($maxPagesPerFolder pages) for "$folderPath" in "$bucket". Possible infinite loop.',
        );
      }

      final List<FileObject> page;
      try {
        page = await _client.storage.from(bucket).list(
          path: folderPath,
          searchOptions: SearchOptions(
            limit: pageSize,
            offset: offset,
            sortBy: const SortBy(column: 'name', order: 'asc'),
          ),
        );
      } catch (e) {
        debugPrint(
          '[SupabaseStorageService] Error listing "$folderPath" in "$bucket" (offset: $offset): $e',
        );
        if (e is StorageOperationException) rethrow;
        throw StorageOperationException(
          'Failed listing storage folder "$folderPath" at offset $offset in "$bucket": $e',
          e,
        );
      }

      if (page.isEmpty) {
        break;
      }

      bool hasNewItems = false;
      for (final item in page) {
        final key = '${item.name}::${item.id ?? "dir"}';
        if (seenKeys.add(key)) {
          hasNewItems = true;
          allItems.add(item);
        }
      }

      if (!hasNewItems) {
        throw StorageOperationException(
          'Infinite loop detected: pagination returned duplicate page at offset $offset for folder "$folderPath" in "$bucket".',
        );
      }

      if (page.length < pageSize) {
        break;
      }

      offset += page.length;
    }

    return allItems;
  }

  /// Recursively traverses [rootFolder] and its nested subfolders within [bucket],
  /// collecting all file object paths belonging to [userId].
  Future<List<String>> _collectUserFilePathsRecursively({
    required String bucket,
    required String rootFolder,
    required String userId,
    int pageSize = defaultListPageSize,
  }) async {
    final List<String> filePaths = [];
    final List<String> foldersToVisit = [rootFolder];
    final Set<String> visitedFolders = {};

    while (foldersToVisit.isNotEmpty) {
      final currentFolder = foldersToVisit.removeAt(0);
      if (!visitedFolders.add(currentFolder)) {
        continue;
      }

      // Security Invariant: Traversed folders must strictly be under userId
      if (currentFolder != userId && !currentFolder.startsWith('$userId/')) {
        continue;
      }

      final items = await _listFolderPaginated(
        bucket: bucket,
        folderPath: currentFolder,
        pageSize: pageSize,
      );

      for (final item in items) {
        final cleanName = item.name.trim().replaceAll(RegExp(r'^/+|/+$'), '');
        if (cleanName.isEmpty || cleanName == '.' || cleanName == '..') {
          continue;
        }

        final itemPath = '$currentFolder/$cleanName';

        // Security Invariant: Item path must strictly belong under userId
        if (!itemPath.startsWith('$userId/')) {
          continue;
        }

        final isFolder = item.id == null || item.metadata == null;
        if (isFolder) {
          foldersToVisit.add(itemPath);
        } else {
          // Ownership verification: If owner is present, it must match userId
          if (item.owner != null &&
              item.owner!.isNotEmpty &&
              item.owner != userId) {
            // Belongs to another user, strictly ignore
            continue;
          }
          filePaths.add(itemPath);
        }
      }
    }

    return filePaths;
  }

  Future<void> _deleteBucketFilesForUser({
    required String bucket,
    required String userId,
    int pageSize = defaultListPageSize,
    int batchSize = defaultDeleteBatchSize,
  }) async {
    validateBucket(bucket);

    final authUserId = _currentUserId;
    if (authUserId != null && authUserId.isNotEmpty && authUserId != userId) {
      throw StorageValidationException(
        'Storage purge user ID ("$userId") does not match authenticated user session ("$authUserId").',
      );
    }

    Set<String>? previousRoundPaths;
    int round = 0;

    while (true) {
      round++;
      final pathsToDelete = await _collectUserFilePathsRecursively(
        bucket: bucket,
        rootFolder: userId,
        userId: userId,
        pageSize: pageSize,
      );

      if (pathsToDelete.isEmpty) {
        // Complete enumeration confirms no owned objects remain in this bucket.
        break;
      }

      if (round > maxPurgeRounds) {
        throw StorageOperationException(
          'Failed to completely purge user storage files in "$bucket": ${pathsToDelete.length} objects still remain after $maxPurgeRounds purge rounds.',
        );
      }

      final currentPathSet = pathsToDelete.toSet();
      // Infinite loop / stall protection:
      // If the current round finds the exact same set of files as the previous round,
      // deletion made zero progress (e.g. backend failed to remove them or permission denied).
      if (previousRoundPaths != null &&
          previousRoundPaths.isNotEmpty &&
          currentPathSet.length == previousRoundPaths.length &&
          currentPathSet.containsAll(previousRoundPaths)) {
        throw StorageOperationException(
          'Storage deletion stalled in "$bucket" for user "$userId": ${pathsToDelete.length} persistent objects could not be removed.',
        );
      }
      previousRoundPaths = currentPathSet;

      // Delete in bounded batches
      for (int i = 0; i < pathsToDelete.length; i += batchSize) {
        final end = (i + batchSize < pathsToDelete.length)
            ? i + batchSize
            : pathsToDelete.length;
        final chunk = pathsToDelete.sublist(i, end);

        try {
          await _client.storage.from(bucket).remove(chunk);
          debugPrint(
            '[SupabaseStorageService] Cleaned up batch of ${chunk.length} files from $bucket for user $userId (round $round)',
          );
        } catch (e) {
          debugPrint(
            '[SupabaseStorageService] Failed removing batch (${chunk.length} items) from $bucket for $userId: $e',
          );
          if (e is StorageOperationException) rethrow;
          throw StorageOperationException(
            'Failed to delete storage batch in "$bucket": $e',
            e,
          );
        }
      }
    }
  }

  @visibleForTesting
  Future<void> deleteBucketFilesForUser({
    required String bucket,
    required String userId,
    int pageSize = defaultListPageSize,
    int batchSize = defaultDeleteBatchSize,
  }) =>
      _deleteBucketFilesForUser(
        bucket: bucket,
        userId: userId,
        pageSize: pageSize,
        batchSize: batchSize,
      );

  @visibleForTesting
  Future<List<String>> collectUserFilePaths({
    required String bucket,
    required String userId,
    int pageSize = defaultListPageSize,
  }) =>
      _collectUserFilePathsRecursively(
        bucket: bucket,
        rootFolder: userId,
        userId: userId,
        pageSize: pageSize,
      );
}
