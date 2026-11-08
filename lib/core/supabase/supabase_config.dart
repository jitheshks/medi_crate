import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when Supabase configuration is missing or invalid.
class SupabaseConfigurationException implements Exception {
  final String message;
  const SupabaseConfigurationException(this.message);

  @override
  String toString() => 'SupabaseConfigurationException: $message';
}

/// SupabaseConfig encapsulates Supabase client initialization,
/// environment variable validation, and test mock client injection.
abstract class SupabaseConfig {
  static const String envUrlKey = 'SUPABASE_URL';
  static const String envAnonKey = 'SUPABASE_ANON_KEY';

  static const String defaultUrl = 'https://wnaflcytkubqmrymbmcn.supabase.co';

  static bool _isInitialized = false;
  static SupabaseClient? _customClient;

  /// Returns true if Supabase has been successfully initialized or a mock client is injected.
  static bool get isInitialized => _isInitialized;

  /// Returns the active SupabaseClient instance.
  /// Throws [StateError] if Supabase has not been initialized.
  static SupabaseClient get client {
    if (_customClient != null) {
      return _customClient!;
    }
    if (!_isInitialized) {
      throw StateError(
        'Supabase has not been initialized. Call SupabaseConfig.initialize() before accessing SupabaseConfig.client.',
      );
    }
    return Supabase.instance.client;
  }

  /// Injects a custom or mock [SupabaseClient] for testing.
  /// Setting this to null resets the mock state.
  static void setMockClient(SupabaseClient? mockClient) {
    _customClient = mockClient;
    _isInitialized = mockClient != null;
  }

  /// Validates Supabase environment configuration.
  /// Returns a record of `(url, anonKey)` if valid, or throws [SupabaseConfigurationException].
  static ({String url, String anonKey}) validateConfig({
    String? url,
    String? anonKey,
  }) {
    final resolvedUrl =
        url ??
        (dotenv.isInitialized ? dotenv.maybeGet(envUrlKey) : null) ??
        const String.fromEnvironment(envUrlKey, defaultValue: defaultUrl);

    final resolvedAnonKey =
        anonKey ??
        (dotenv.isInitialized ? dotenv.maybeGet(envAnonKey) : null) ??
        const String.fromEnvironment(envAnonKey);

    if (resolvedUrl.trim().isEmpty) {
      throw const SupabaseConfigurationException(
        'Missing SUPABASE_URL. Please set SUPABASE_URL in your .env or environment.',
      );
    }

    final uri = Uri.tryParse(resolvedUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw SupabaseConfigurationException(
        'Invalid SUPABASE_URL: "$resolvedUrl". Must be a valid URL with http/https scheme.',
      );
    }

    if (resolvedAnonKey.trim().isEmpty) {
      throw const SupabaseConfigurationException(
        'Missing SUPABASE_ANON_KEY. Please set SUPABASE_ANON_KEY in your .env or environment.',
      );
    }

    return (url: resolvedUrl.trim(), anonKey: resolvedAnonKey.trim());
  }

  /// Initializes the Supabase singleton instance exactly once.
  /// Idempotent: repeated calls when already initialized will return the existing client.
  static Future<SupabaseClient> initialize({
    String? url,
    String? anonKey,
    SupabaseClient? customClient,
  }) async {
    if (customClient != null) {
      _customClient = customClient;
      _isInitialized = true;
      return customClient;
    }

    if (_isInitialized) {
      return client;
    }

    final config = validateConfig(url: url, anonKey: anonKey);

    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.anonKey,
      );
      _isInitialized = true;
      debugPrint(
        '[SupabaseConfig] Initialized successfully with URL: ${config.url}',
      );
      return Supabase.instance.client;
    } catch (e) {
      _isInitialized = false;
      debugPrint('[SupabaseConfig] Initialization failed: $e');
      rethrow;
    }
  }

  /// Resets initialization state (primarily for test tearDown).
  @visibleForTesting
  static void resetForTesting() {
    _customClient = null;
    _isInitialized = false;
  }
}
