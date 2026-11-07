import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SecureStorageService provides hardened encrypted key-value storage for access tokens,
/// refresh tokens, and sensitive authentication credentials backed by Android KeyStore
/// and iOS Keychain.
///
/// Features automated self-healing against KeyStore corruption (e.g. BAD_DECRYPT,
/// AEADBadTagException, or stale restored blobs) with single-retry write semantics
/// and safe, sanitized diagnostic logging.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const AndroidOptions _defaultAndroidOptions = AndroidOptions(
    resetOnError: true,
  );

  static const IOSOptions _defaultIOSOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: _defaultAndroidOptions,
            iOptions: _defaultIOSOptions,
          );

  static const String _accessTokenKey = 'auth_bearer_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  /// Sanitized diagnostic logger that NEVER records sensitive credentials.
  void _logDiagnostic(
    String operation,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    final String errorType = error.runtimeType.toString();
    final String? platformCode = (error is PlatformException)
        ? error.code
        : null;
    final String sanitizedMsg = (error is PlatformException)
        ? (error.message ?? 'Platform error during $operation')
        : 'Storage error during $operation';

    developer.log(
      '🔒 [SecureStorageService] $operation failed ($errorType${platformCode != null ? ' - $platformCode' : ''}): $sanitizedMsg',
      name: 'MediCrate.Storage',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Internal safe deletion that suppresses exceptions so recovery/cleanup never throws.
  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, stackTrace) {
      _logDiagnostic('delete($key)', e, stackTrace);
    }
  }

  /// Safe write with single targeted retry and automatic key recovery.
  ///
  /// If an initial write fails due to hardware KeyStore errors or corrupted entries:
  /// 1. The corrupted key is deleted to purge invalid KeyStore state.
  /// 2. The write operation is retried exactly once.
  /// 3. Returns true on success, false if permanent storage failure occurs.
  Future<bool> _writeWithRetry(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e, stackTrace) {
      _logDiagnostic('write($key) initial attempt', e, stackTrace);

      // Targeted self-healing: purge the corrupted key entry
      await _safeDelete(key);

      // Retry exactly once
      try {
        await _storage.write(key: key, value: value);
        developer.log(
          '🔒 [SecureStorageService] write($key) succeeded on retry after KeyStore recovery',
          name: 'MediCrate.Storage',
        );
        return true;
      } catch (retryError, retryStackTrace) {
        _logDiagnostic(
          'write($key) retry attempt',
          retryError,
          retryStackTrace,
        );
        return false;
      }
    }
  }

  /// Safe read with automatic corrupt-key cleanup.
  Future<String?> _readWithRecovery(String key) async {
    try {
      final value = await _storage.read(key: key);
      return (value != null && value.isNotEmpty) ? value : null;
    } catch (e, stackTrace) {
      _logDiagnostic('read($key)', e, stackTrace);
      // Clean up corrupted key so subsequent writes don't hit the stale KeyStore entry
      await _safeDelete(key);
      return null;
    }
  }

  /// Saves both access token and refresh token safely with automatic single retry on KeyStore failure.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _writeWithRetry(_accessTokenKey, accessToken);
    await _writeWithRetry(_refreshTokenKey, refreshToken);
  }

  /// Saves the primary access token.
  Future<void> saveAuthToken(String token) async {
    await _writeWithRetry(_accessTokenKey, token);
  }

  /// Saves the refresh token.
  Future<void> saveRefreshToken(String token) async {
    await _writeWithRetry(_refreshTokenKey, token);
  }

  /// Retrieves the current access token. Returns null if unreadable or corrupted.
  Future<String?> getAuthToken() async {
    return await _readWithRecovery(_accessTokenKey);
  }

  /// Retrieves the current refresh token. Returns null if unreadable or corrupted.
  Future<String?> getRefreshToken() async {
    return await _readWithRecovery(_refreshTokenKey);
  }

  /// Clears both access and refresh tokens upon sign out or session invalidation.
  Future<void> clearAuthToken() async {
    await _safeDelete(_accessTokenKey);
    await _safeDelete(_refreshTokenKey);
  }

  /// Alias for clearAuthToken() to support clearTokens naming convention.
  Future<void> clearTokens() async {
    await clearAuthToken();
  }

  /// Clears all encrypted entries in secure storage safely.
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, stackTrace) {
      _logDiagnostic('deleteAll()', e, stackTrace);
      // Fallback: individually delete known auth keys
      await _safeDelete(_accessTokenKey);
      await _safeDelete(_refreshTokenKey);
    }
  }
}
