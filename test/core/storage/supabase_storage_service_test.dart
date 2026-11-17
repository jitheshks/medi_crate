import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';
import 'package:medi_crate/core/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Test Doubles
// ---------------------------------------------------------------------------

class FakeStorageFileApi extends Fake implements StorageFileApi {
  final Map<String, Uint8List> storedFiles = {};
  final List<String> uploadCalls = [];
  final List<String> removeCalls = [];
  final List<FileOptions> lastFileOptions = [];
  bool shouldThrowOnUpload = false;
  bool shouldThrowOnDownload = false;
  bool shouldThrowOnSignedUrl = false;
  bool shouldThrowOnRemove = false;
  bool shouldThrowOnList = false;
  List<FileObject> Function(String? path, SearchOptions searchOptions)? customListHandler;

  @override
  Future<List<FileObject>> list({
    String? path,
    SearchOptions searchOptions = const SearchOptions(),
  }) async {
    if (shouldThrowOnList) {
      throw const StorageException('Simulated list failure');
    }
    if (customListHandler != null) {
      return customListHandler!(path, searchOptions);
    }
    return [];
  }

  @override
  Future<String> upload(
    String path,
    dynamic file, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    uploadCalls.add(path);
    lastFileOptions.add(fileOptions);
    if (shouldThrowOnUpload) {
      throw const StorageException('Simulated storage upload failure');
    }
    if (file is File) {
      storedFiles[path] = await file.readAsBytes();
    } else if (file is Uint8List) {
      storedFiles[path] = file;
    }
    return path;
  }

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    uploadCalls.add(path);
    lastFileOptions.add(fileOptions);
    if (shouldThrowOnUpload) {
      throw const StorageException('Simulated storage binary upload failure');
    }
    storedFiles[path] = data;
    return path;
  }

  @override
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    TransformOptions? transform,
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    if (shouldThrowOnSignedUrl) {
      throw const StorageException('Simulated signed URL failure');
    }
    return 'https://supabase.local/storage/v1/object/sign/$path?token=test_token&expires=$expiresIn';
  }

  @override
  Future<Uint8List> download(
    String path, {
    TransformOptions? transform,
    Map<String, String>? queryParams,
    String? cacheNonce,
  }) async {
    if (shouldThrowOnDownload) {
      throw const StorageException('Simulated download failure');
    }
    final data = storedFiles[path];
    if (data == null) {
      return Uint8List.fromList([1, 2, 3, 4, 5]);
    }
    return data;
  }

  @override
  Future<List<FileObject>> remove(List<String> paths) async {
    if (shouldThrowOnRemove) {
      throw const StorageException('Simulated remove failure');
    }
    removeCalls.addAll(paths);
    for (final p in paths) {
      storedFiles.remove(p);
    }
    return [];
  }
}

class FakeSupabaseStorageClient extends Fake implements SupabaseStorageClient {
  final Map<String, FakeStorageFileApi> buckets = {};

  @override
  StorageFileApi from(String id) {
    return buckets.putIfAbsent(id, () => FakeStorageFileApi());
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeSupabaseStorageClient mockStorage = FakeSupabaseStorageClient();

  @override
  SupabaseStorageClient get storage => mockStorage;
}

void main() {
  late Directory tempDir;
  late FakeSupabaseClient fakeClient;
  late SupabaseStorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_test_');
    fakeClient = FakeSupabaseClient();
    storageService = SupabaseStorageService(customClient: fakeClient);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1. File Type and Extension Validation', () {
    test('accepts valid PDF and image documents for consultations and reports', () async {
      for (final ext in ['pdf', 'jpg', 'jpeg', 'png', 'webp']) {
        final testFile = File('${tempDir.path}/test_valid.$ext');
        await testFile.writeAsBytes([1, 2, 3, 4]);

        expect(
          () => storageService.validateFile(
            testFile,
            bucket: SupabaseStorageService.consultationsBucket,
          ),
          returnsNormally,
        );
        expect(
          () => storageService.validateFile(
            testFile,
            bucket: SupabaseStorageService.reportsBucket,
          ),
          returnsNormally,
        );
      }
    });

    test('rejects unauthorized executable, script, and foreign file extensions', () async {
      for (final ext in ['exe', 'sh', 'apk', 'zip', 'doc', 'docx', 'mp4']) {
        final testFile = File('${tempDir.path}/malicious.$ext');
        await testFile.writeAsBytes([1, 2, 3, 4]);

        expect(
          () => storageService.validateFile(
            testFile,
            bucket: SupabaseStorageService.consultationsBucket,
          ),
          throwsA(isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('is not supported'),
          )),
        );
      }
    });

    test('rejects PDF documents for avatar profile photos', () async {
      final testFile = File('${tempDir.path}/avatar.pdf');
      await testFile.writeAsBytes([1, 2, 3, 4]);

      expect(
        () => storageService.validateFile(
          testFile,
          bucket: SupabaseStorageService.avatarsBucket,
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('2. File Size Limit Enforcement', () {
    test('rejects 0-byte empty files', () async {
      final emptyFile = File('${tempDir.path}/empty.pdf');
      await emptyFile.create();

      expect(
        () => storageService.validateFile(
          emptyFile,
          bucket: SupabaseStorageService.consultationsBucket,
        ),
        throwsA(isA<StorageValidationException>().having(
          (e) => e.message,
          'message',
          contains('0 bytes'),
        )),
      );
    });

    test('rejects files exceeding 25 MB for consultations and reports', () async {
      // 26,214,401 bytes (> 25 MB)
      final largeBytes = Uint8List(SupabaseStorageService.maxConsultationSizeBytes + 1);

      expect(
        () => storageService.validateBytes(
          largeBytes,
          fileName: 'large.pdf',
          bucket: SupabaseStorageService.consultationsBucket,
        ),
        throwsA(isA<StorageValidationException>().having(
          (e) => e.message,
          'message',
          contains('exceeds the maximum allowed limit'),
        )),
      );
    });

    test('rejects avatar photos exceeding 5 MB', () async {
      // 5,242,881 bytes (> 5 MB)
      final largeBytes = Uint8List(SupabaseStorageService.maxAvatarSizeBytes + 1);

      expect(
        () => storageService.validateBytes(
          largeBytes,
          fileName: 'large_avatar.jpg',
          bucket: SupabaseStorageService.avatarsBucket,
        ),
        throwsA(isA<StorageValidationException>().having(
          (e) => e.message,
          'message',
          contains('exceeds the maximum allowed limit'),
        )),
      );
    });
  });

  group('3. Tenant Ownership & Object Path Building', () {
    test('constructs standardized tenant-isolated path format', () {
      final path = SupabaseStorageService.buildObjectPath(
        userId: 'user_123',
        parentId: 'consultation_456',
        fileName: 'prescription.pdf',
        attachmentId: 'att_789',
      );

      expect(path, 'user_123/consultation_456/att_789_prescription.pdf');
    });

    test('sanitizes dangerous path traversal and special characters', () {
      final path = SupabaseStorageService.buildObjectPath(
        userId: 'user_123',
        parentId: 'report_456',
        fileName: '../../etc/passwd%20hack.pdf',
        attachmentId: 'att_001',
      );

      // Traversal tokens are stripped, special characters replaced with underscore
      expect(path, isNot(contains('../')));
      expect(path, isNot(contains(' ')));
      expect(path, startsWith('user_123/report_456/'));
    });
  });

  group('4. Upload and Download Operations', () {
    test('uploads consultation attachment to private bucket and returns path', () async {
      final testFile = File('${tempDir.path}/rx.pdf');
      await testFile.writeAsBytes([10, 20, 30, 40]);

      final storagePath = 'user_1/consultation_1/att_1_rx.pdf';
      final result = await storageService.uploadFile(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: storagePath,
        file: testFile,
      );

      expect(result, storagePath);
      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket);
      expect((bucketApi as FakeStorageFileApi).uploadCalls, contains(storagePath));
    });

    test('uploads report attachment to private bucket', () async {
      final testFile = File('${tempDir.path}/scan.png');
      await testFile.writeAsBytes([1, 2, 3]);

      final storagePath = 'user_1/report_1/att_2_scan.png';
      final result = await storageService.uploadFile(
        bucket: SupabaseStorageService.reportsBucket,
        storagePath: storagePath,
        file: testFile,
      );

      expect(result, storagePath);
    });

    test('downloads file and writes to target local destination', () async {
      final remotePath = 'user_1/consultation_1/att_1_rx.pdf';
      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      bucketApi.storedFiles[remotePath] = Uint8List.fromList([100, 101, 102]);

      final destPath = '${tempDir.path}/downloaded_rx.pdf';
      final downloadedFile = await storageService.downloadToFile(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: remotePath,
        destinationFilePath: destPath,
      );

      expect(downloadedFile.existsSync(), isTrue);
      expect(await downloadedFile.readAsBytes(), [100, 101, 102]);
    });
  });

  group('5. Signed URL Generation and Expiration', () {
    test('generates valid signed URL with configurable expiration', () async {
      final signedUrl = await storageService.createSignedUrl(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: 'user_1/c_1/file.pdf',
        expiresInSeconds: 1800,
      );

      expect(signedUrl, contains('https://supabase.local'));
      expect(signedUrl, contains('expires=1800'));
      expect(signedUrl, contains('token=test_token'));
    });
  });

  group('6. Failure Handling & Local Attachment Preservation', () {
    test('preserves local file on disk when upload fails', () async {
      final testFile = File('${tempDir.path}/vital_doc.pdf');
      await testFile.writeAsBytes([5, 4, 3, 2, 1]);

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      bucketApi.shouldThrowOnUpload = true;

      expect(
        () => storageService.uploadFile(
          bucket: SupabaseStorageService.consultationsBucket,
          storagePath: 'user_1/c_1/vital_doc.pdf',
          file: testFile,
        ),
        throwsA(isA<StorageOperationException>()),
      );

      // Local file MUST NOT be deleted
      expect(testFile.existsSync(), isTrue);
      expect(await testFile.readAsBytes(), [5, 4, 3, 2, 1]);
    });

    test('deletes remote file when requested', () async {
      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.reportsBucket) as FakeStorageFileApi;
      final path = 'user_1/rep_1/att_old.pdf';
      bucketApi.storedFiles[path] = Uint8List.fromList([1]);

      await storageService.deleteFile(
        bucket: SupabaseStorageService.reportsBucket,
        storagePath: path,
      );

      expect(bucketApi.removeCalls, contains(path));
      expect(bucketApi.storedFiles.containsKey(path), isFalse);
    });
  });

  group('7. Bucket Validation Enforcement', () {
    test('validates and accepts valid buckets: consultations, reports, avatars', () {
      expect(() => storageService.validateBucket(SupabaseStorageService.consultationsBucket), returnsNormally);
      expect(() => storageService.validateBucket(SupabaseStorageService.reportsBucket), returnsNormally);
      expect(() => storageService.validateBucket(SupabaseStorageService.avatarsBucket), returnsNormally);
    });

    test('rejects arbitrary or unknown bucket names', () async {
      for (final invalid in ['malicious', 'users', 'public', 'temp', '']) {
        expect(
          () => storageService.validateBucket(invalid),
          throwsA(isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported storage bucket'),
          )),
        );

        final testFile = File('${tempDir.path}/test.pdf');
        await testFile.writeAsBytes([1, 2, 3]);

        expect(
          () => storageService.uploadFile(
            bucket: invalid,
            storagePath: 'user_1/c_1/test.pdf',
            file: testFile,
          ),
          throwsA(isA<StorageValidationException>()),
        );

        expect(
          () => storageService.uploadBytes(
            bucket: invalid,
            storagePath: 'user_1/c_1/test.pdf',
            bytes: Uint8List.fromList([1, 2, 3]),
            fileName: 'test.pdf',
          ),
          throwsA(isA<StorageValidationException>()),
        );

        expect(
          () => storageService.createSignedUrl(
            bucket: invalid,
            storagePath: 'user_1/c_1/test.pdf',
          ),
          throwsA(isA<StorageValidationException>()),
        );

        expect(
          () => storageService.downloadBytes(
            bucket: invalid,
            storagePath: 'user_1/c_1/test.pdf',
          ),
          throwsA(isA<StorageValidationException>()),
        );

        expect(
          () => storageService.downloadToFile(
            bucket: invalid,
            storagePath: 'user_1/c_1/test.pdf',
            destinationFilePath: '${tempDir.path}/dest.pdf',
          ),
          throwsA(isA<StorageValidationException>()),
        );

        expect(
          () => storageService.deleteFile(
            bucket: invalid,
            storagePath: 'user_1/c_1/test.pdf',
          ),
          throwsA(isA<StorageValidationException>()),
        );
      }
    });
  });

  group('8. Storage Path Structure and Depth Validation', () {
    test('enforces exact 3-segment depth for clinical attachments', () {
      // Valid 3-segment paths
      expect(
        () => storageService.validateStoragePath(
          bucket: SupabaseStorageService.consultationsBucket,
          storagePath: 'u1/c1/doc.pdf',
        ),
        returnsNormally,
      );
      expect(
        () => storageService.validateStoragePath(
          bucket: SupabaseStorageService.reportsBucket,
          storagePath: 'u1/r1/scan.png',
        ),
        returnsNormally,
      );

      // Invalid depths (1, 2, 4 segments)
      for (final invalidPath in [
        'doc.pdf',
        'u1/doc.pdf',
        'u1/c1/sub/doc.pdf',
        'u1/c1/sub/extra/doc.pdf',
      ]) {
        expect(
          () => storageService.validateStoragePath(
            bucket: SupabaseStorageService.consultationsBucket,
            storagePath: invalidPath,
          ),
          throwsA(isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('Expected format: {userId}/{parentId}/{fileName}'),
          )),
        );
      }
    });

    test('enforces 2 or 3 segments depth for avatar photos', () {
      // Valid: 2 segments (primary) or 3 segments (family member)
      expect(
        () => storageService.validateStoragePath(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: 'u1/avatar.jpg',
        ),
        returnsNormally,
      );
      expect(
        () => storageService.validateStoragePath(
          bucket: SupabaseStorageService.avatarsBucket,
          storagePath: 'u1/p1/avatar.jpg',
        ),
        returnsNormally,
      );

      // Invalid depths
      for (final invalidPath in [
        'avatar.jpg',
        'u1/p1/sub/avatar.jpg',
      ]) {
        expect(
          () => storageService.validateStoragePath(
            bucket: SupabaseStorageService.avatarsBucket,
            storagePath: invalidPath,
          ),
          throwsA(isA<StorageValidationException>()),
        );
      }
    });

    test('rejects path traversal tokens, backslashes, double slashes, and leading/trailing slashes', () {
      for (final badPath in [
        '../u1/c1/file.pdf',
        'u1/../c1/file.pdf',
        'u1/c1/../../file.pdf',
        'u1\\c1\\file.pdf',
        '/u1/c1/file.pdf',
        'u1/c1/file.pdf/',
        'u1//c1/file.pdf',
        'u1/c1//file.pdf',
      ]) {
        expect(
          () => storageService.validateStoragePath(
            bucket: SupabaseStorageService.consultationsBucket,
            storagePath: badPath,
          ),
          throwsA(isA<StorageValidationException>()),
        );
      }
    });

    test('enforces expectedUserId matching against the first path segment', () {
      expect(
        () => storageService.validateStoragePath(
          bucket: SupabaseStorageService.consultationsBucket,
          storagePath: 'target_user/c1/file.pdf',
          expectedUserId: 'target_user',
        ),
        returnsNormally,
      );

      expect(
        () => storageService.validateStoragePath(
          bucket: SupabaseStorageService.consultationsBucket,
          storagePath: 'target_user/c1/file.pdf',
          expectedUserId: 'different_user',
        ),
        throwsA(isA<StorageValidationException>().having(
          (e) => e.message,
          'message',
          contains('does not match'),
        )),
      );
    });
  });

  group('9. MIME Type Consistency Enforcement', () {
    test('accepts compatible explicit MIME types for given file extension', () {
      expect(
        () => storageService.validateMimeTypeConsistency(
          storagePath: 'u1/c1/doc.pdf',
          contentType: 'application/pdf',
        ),
        returnsNormally,
      );
      expect(
        () => storageService.validateMimeTypeConsistency(
          storagePath: 'u1/c1/pic.jpg',
          contentType: 'image/jpeg',
        ),
        returnsNormally,
      );
      expect(
        () => storageService.validateMimeTypeConsistency(
          storagePath: 'u1/c1/pic.png',
          contentType: 'image/png',
        ),
        returnsNormally,
      );
      expect(
        () => storageService.validateMimeTypeConsistency(
          storagePath: 'u1/c1/pic.webp',
          contentType: 'image/webp',
        ),
        returnsNormally,
      );
    });

    test('rejects contradictory explicit MIME types', () {
      expect(
        () => storageService.validateMimeTypeConsistency(
          storagePath: 'u1/c1/doc.pdf',
          contentType: 'image/png',
        ),
        throwsA(isA<StorageValidationException>().having(
          (e) => e.message,
          'message',
          contains('contradicts the file extension'),
        )),
      );

      expect(
        () => storageService.validateMimeTypeConsistency(
          storagePath: 'u1/c1/pic.png',
          contentType: 'application/pdf',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('10. Default Upsert Behavior by Bucket', () {
    test('clinical attachments default to upsert: false', () async {
      final testFile = File('${tempDir.path}/clinical_doc.pdf');
      await testFile.writeAsBytes([1, 2, 3]);

      await storageService.uploadFile(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: 'u1/c1/clinical_doc.pdf',
        file: testFile,
      );

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      expect(bucketApi.lastFileOptions.last.upsert, isFalse);
    });

    test('avatar uploads default to upsert: true', () async {
      final testFile = File('${tempDir.path}/avatar_pic.jpg');
      await testFile.writeAsBytes([1, 2, 3]);

      await storageService.uploadFile(
        bucket: SupabaseStorageService.avatarsBucket,
        storagePath: 'u1/p1/avatar_pic.jpg',
        file: testFile,
      );

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      expect(bucketApi.lastFileOptions.last.upsert, isTrue);
    });

    test('explicit upsert parameter overrides defaults', () async {
      final testFile = File('${tempDir.path}/override.pdf');
      await testFile.writeAsBytes([1, 2, 3]);

      await storageService.uploadFile(
        bucket: SupabaseStorageService.consultationsBucket,
        storagePath: 'u1/c1/override.pdf',
        file: testFile,
        upsert: true, // explicit override
      );

      final bucketApi = fakeClient.mockStorage.from(SupabaseStorageService.consultationsBucket) as FakeStorageFileApi;
      expect(bucketApi.lastFileOptions.last.upsert, isTrue);
    });
  });

  group('11. Synchronization Isolation Boundary', () {
    test('isRemoteSyncEnabled defaults to false to protect offline mutations', () {
      expect(SyncService.isRemoteSyncEnabled, isFalse);
    });
  });

  group('12. Complete Storage Enumeration & Purge Safety Invariants', () {
    test('rejects empty, traversal, or invalid user IDs', () async {
      expect(
        () => storageService.deleteAllUserFiles(userId: ''),
        throwsA(isA<StorageValidationException>()),
      );
      expect(
        () => storageService.deleteAllUserFiles(userId: '   '),
        throwsA(isA<StorageValidationException>()),
      );
      expect(
        () => storageService.deleteAllUserFiles(userId: '../evil_user'),
        throwsA(isA<StorageValidationException>()),
      );
      expect(
        () => storageService.deleteAllUserFiles(userId: 'user/nested'),
        throwsA(isA<StorageValidationException>()),
      );
      expect(
        () => storageService.deleteAllUserFiles(userId: 'user\\nested'),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('infinite loop detection triggers when pagination returns duplicate entries', () async {
      final avatarsApi = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarsApi.customListHandler = (path, searchOptions) {
        // Always returns the exact same 2 items regardless of offset
        return [
          const FileObject(
            name: 'dup1.jpg',
            bucketId: 'avatars',
            owner: 'u1',
            id: 'id1',
            updatedAt: '2026-11-15',
            createdAt: '2026-11-15',
            lastAccessedAt: null,
            metadata: {'size': 100},
            buckets: null,
          ),
          const FileObject(
            name: 'dup2.jpg',
            bucketId: 'avatars',
            owner: 'u1',
            id: 'id2',
            updatedAt: '2026-11-15',
            createdAt: '2026-11-15',
            lastAccessedAt: null,
            metadata: {'size': 100},
            buckets: null,
          ),
        ];
      };

      expect(
        () => storageService.deleteAllUserFilesWithConfig(
          userId: 'u1',
          pageSize: 2, // limit is 2, so offset would advance, but server returns same items
        ),
        throwsA(isA<StorageOperationException>().having(
          (e) => e.message,
          'message',
          contains('Infinite loop detected'),
        )),
      );
    });

    test('stalled purge triggers error when objects cannot be removed across rounds', () async {
      final avatarsApi = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      // Pretend remove does nothing so the same object persists
      avatarsApi.customListHandler = (path, searchOptions) {
        if (searchOptions.offset == 0) {
          return [
            const FileObject(
              name: 'stuck.jpg',
              bucketId: 'avatars',
              owner: 'u1',
              id: 'id_stuck',
              updatedAt: '2026-11-15',
              createdAt: '2026-11-15',
              lastAccessedAt: null,
              metadata: {'size': 100},
              buckets: null,
            ),
          ];
        }
        return [];
      };

      expect(
        () => storageService.deleteAllUserFilesWithConfig(userId: 'u1'),
        throwsA(isA<StorageOperationException>().having(
          (e) => e.message,
          'message',
          contains('Storage deletion stalled'),
        )),
      );
    });

    test('objects belonging to other users are excluded from collection and deletion', () async {
      final avatarsApi = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarsApi.customListHandler = (path, searchOptions) {
        if (searchOptions.offset == 0) {
          return [
            const FileObject(
              name: 'my_photo.jpg',
              bucketId: 'avatars',
              owner: 'u1',
              id: 'id_my',
              updatedAt: '2026-11-15',
              createdAt: '2026-11-15',
              lastAccessedAt: null,
              metadata: {'size': 100},
              buckets: null,
            ),
            const FileObject(
              name: 'other_photo.jpg',
              bucketId: 'avatars',
              owner: 'different_user_999',
              id: 'id_other',
              updatedAt: '2026-11-15',
              createdAt: '2026-11-15',
              lastAccessedAt: null,
              metadata: {'size': 100},
              buckets: null,
            ),
          ];
        }
        return [];
      };

      final collected = await storageService.collectUserFilePaths(
        bucket: SupabaseStorageService.avatarsBucket,
        userId: 'u1',
      );

      expect(collected, contains('u1/my_photo.jpg'));
      expect(collected, isNot(contains('u1/other_photo.jpg')));
    });

    test('propagates listing errors immediately without swallowing', () async {
      final avatarsApi = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      avatarsApi.shouldThrowOnList = true;

      expect(
        () => storageService.deleteAllUserFiles(userId: 'u1'),
        throwsA(isA<StorageOperationException>().having(
          (e) => e.message,
          'message',
          contains('Failed listing storage folder'),
        )),
      );
    });
  });
}
