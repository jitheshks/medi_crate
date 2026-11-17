import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_storage_service.dart';

/// Represents a cached signed URL for private avatar rendering with expiration timestamp.
class CachedSignedUrl {
  final String signedUrl;
  final DateTime expiresAt;

  const CachedSignedUrl({
    required this.signedUrl,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// AvatarUrlResolver provides authenticated signed URL resolution and caching for private
/// Supabase Storage avatars, with support for local files, HTTP URLs, and in-flight request coalescing.
class AvatarUrlResolver {
  final SupabaseStorageService storageService;

  static final Map<String, CachedSignedUrl> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};

  /// Cache TTL of 50 minutes for signed URLs that expire in 1 hour (3600 seconds).
  static const Duration cacheTtl = Duration(minutes: 50);

  AvatarUrlResolver({required this.storageService});

  /// Visible for testing: clears all cached and in-flight requests.
  @visibleForTesting
  static void clearAll() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Clears all cached and in-flight requests.
  void clearCache() => clearAll();

  /// Visible for testing: inspects current cache state.
  @visibleForTesting
  static Map<String, CachedSignedUrl> get cacheSnapshot =>
      Map.unmodifiable(_cache);

  /// Returns the current number of cached entries.
  int get cachedEntryCount => _cache.length;

  /// Invalidates the cached signed URL for [storagePath], or clears all if omitted.
  void invalidate([String? storagePath]) {
    if (storagePath == null) {
      clearAll();
      return;
    }
    final trimmed = storagePath.trim();
    _cache.remove(trimmed);
    _inFlight.remove(trimmed);
  }

  /// Alias for invalidate.
  void invalidateCache([String? storagePath]) => invalidate(storagePath);

  /// Resolves [rawPath] (local file path, HTTP URL, or Supabase Storage object path)
  /// to an immediately renderable image URI.
  Future<String?> resolveAvatarUrl(String? rawPath) => resolveUrl(rawPath);

  /// Resolves [rawPath] (local file path, HTTP URL, or Supabase Storage object path)
  /// to an immediately renderable image URI.
  Future<String?> resolveUrl(String? rawPath) async {
    if (rawPath == null) return null;
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;

    // 1. Direct HTTP/HTTPS URLs (e.g. legacy avatars or external provider URLs)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 2. Local filesystem paths
    if (trimmed.startsWith('/') || trimmed.startsWith('file://')) {
      final cleanPath = trimmed.replaceFirst('file://', '');
      if (File(cleanPath).existsSync()) {
        return cleanPath;
      }
    }

    // 3. Supabase Storage object path (e.g. '{userId}/{profileId}/{fileName}' or '{userId}/{fileName}')
    final cached = _cache[trimmed];
    if (cached != null && !cached.isExpired) {
      return cached.signedUrl;
    }

    // Coalesce duplicate in-flight requests to avoid redundant signed URL calls during widget rebuilds
    final existingFuture = _inFlight[trimmed];
    if (existingFuture != null) {
      return await existingFuture;
    }

    final future = _fetchAndCacheSignedUrl(trimmed);
    _inFlight[trimmed] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(trimmed);
    }
  }

  Future<String?> _fetchAndCacheSignedUrl(String storagePath) async {
    try {
      final signedUrl = await storageService.createSignedUrl(
        bucket: SupabaseStorageService.avatarsBucket,
        storagePath: storagePath,
        expiresInSeconds: 3600,
      );

      _cache[storagePath] = CachedSignedUrl(
        signedUrl: signedUrl,
        expiresAt: DateTime.now().add(cacheTtl),
      );

      return signedUrl;
    } catch (e) {
      debugPrint('[AvatarUrlResolver] Failed to generate signed URL for "$storagePath": $e');
      return null;
    }
  }


}

/// Provider for [AvatarUrlResolver].
final avatarUrlResolverProvider = Provider<AvatarUrlResolver>((ref) {
  final storage = SupabaseStorageService();
  return AvatarUrlResolver(storageService: storage);
});

/// Riverpod family provider for resolving avatar paths asynchronously with caching.
final avatarSignedUrlProvider =
    FutureProvider.family<String?, String?>((ref, photoPath) async {
  if (photoPath == null || photoPath.trim().isEmpty) return null;
  final resolver = ref.watch(avatarUrlResolverProvider);
  return await resolver.resolveUrl(photoPath);
});
