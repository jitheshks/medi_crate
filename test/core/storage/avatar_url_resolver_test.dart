import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/storage/avatar_url_resolver.dart';
import 'package:medi_crate/core/storage/supabase_storage_service.dart';

import 'supabase_storage_service_test.dart';

void main() {
  late Directory tempDir;
  late FakeSupabaseClient fakeClient;
  late SupabaseStorageService storageService;
  late AvatarUrlResolver resolver;

  setUp(() async {
    AvatarUrlResolver.clearAll();
    tempDir = await Directory.systemTemp.createTemp('avatar_resolver_test_');
    fakeClient = FakeSupabaseClient();
    storageService = SupabaseStorageService(customClient: fakeClient);
    resolver = AvatarUrlResolver(storageService: storageService);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AvatarUrlResolver', () {
    test('returns null for null, empty or blank photo path', () async {
      expect(await resolver.resolveAvatarUrl(null), isNull);
      expect(await resolver.resolveAvatarUrl(''), isNull);
      expect(await resolver.resolveAvatarUrl('   '), isNull);
    });

    test('resolves existing local file path directly without network call', () async {
      final localFile = File('${tempDir.path}/local_avatar.png');
      await localFile.writeAsBytes([1, 2, 3]);

      final resolved = await resolver.resolveAvatarUrl(localFile.path);
      expect(resolved, localFile.path);

      // Verify no storage signed URL calls were made
      final bucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      expect(bucket.uploadCalls, isEmpty);
    });

    test('resolves file:// URI path to clean local path', () async {
      final localFile = File('${tempDir.path}/local_uri.png');
      await localFile.writeAsBytes([1, 2, 3]);

      final resolved = await resolver.resolveAvatarUrl('file://${localFile.path}');
      expect(resolved, localFile.path);
    });

    test('resolves direct http:// and https:// URLs directly', () async {
      final httpsUrl = 'https://example.com/avatar.jpg';
      final httpUrl = 'http://example.com/avatar.png';

      expect(await resolver.resolveAvatarUrl(httpsUrl), httpsUrl);
      expect(await resolver.resolveAvatarUrl(httpUrl), httpUrl);
    });

    test('generates and caches signed URL for private Supabase Storage object path', () async {
      const storagePath = 'user_123/prof_456/avatar_abc.jpg';

      final signedUrl1 = await resolver.resolveAvatarUrl(storagePath);
      expect(signedUrl1, isNotNull);
      expect(signedUrl1, contains('sign/$storagePath'));
      expect(resolver.cachedEntryCount, 1);

      // Second call should return cached URL without creating a new one
      final signedUrl2 = await resolver.resolveAvatarUrl(storagePath);
      expect(signedUrl2, equals(signedUrl1));
      expect(resolver.cachedEntryCount, 1);
    });

    test('coalesces concurrent in-flight requests for the same storage path', () async {
      const storagePath = 'user_123/avatar_coalesce.jpg';

      // Fire 3 concurrent resolutions for identical path
      final results = await Future.wait([
        resolver.resolveAvatarUrl(storagePath),
        resolver.resolveAvatarUrl(storagePath),
        resolver.resolveAvatarUrl(storagePath),
      ]);

      expect(results[0], isNotNull);
      expect(results[0], equals(results[1]));
      expect(results[1], equals(results[2]));
      expect(resolver.cachedEntryCount, 1);
    });

    test('refreshes expired cached signed URLs after TTL expires', () async {
      const storagePath = 'user_123/avatar_ttl.jpg';

      // Generate initial signed URL
      final initialUrl = await resolver.resolveAvatarUrl(storagePath);
      expect(initialUrl, isNotNull);

      // Invalidate the cache to simulate expiration
      resolver.invalidateCache(storagePath);
      expect(resolver.cachedEntryCount, 0);

      // Resolving again generates a fresh signed URL
      final refreshedUrl = await resolver.resolveAvatarUrl(storagePath);
      expect(refreshedUrl, isNotNull);
      expect(resolver.cachedEntryCount, 1);
    });

    test('clearCache clears all entries', () async {
      await resolver.resolveAvatarUrl('user_1/avatar1.jpg');
      await resolver.resolveAvatarUrl('user_2/avatar2.jpg');
      expect(resolver.cachedEntryCount, 2);

      resolver.clearCache();
      expect(resolver.cachedEntryCount, 0);
    });

    test('returns null when storage service throws exception (e.g. inaccessible object)', () async {
      final bucket = fakeClient.mockStorage.from(SupabaseStorageService.avatarsBucket) as FakeStorageFileApi;
      bucket.shouldThrowOnSignedUrl = true;

      final result = await resolver.resolveAvatarUrl('user_error/avatar_fail.jpg');
      expect(result, isNull);
    });
  });
}
