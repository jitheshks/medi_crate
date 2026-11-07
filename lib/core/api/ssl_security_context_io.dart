import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// IO implementation of SslSecurityContext that safely augments the Dart BoringSSL trust store
/// with the SSL.com TLS RSA Root CA 2022 certificate while retaining system trusted roots.
class SslSecurityContext {
  static const String rootCertAssetPath =
      'assets/certs/ssl_com_root_ca_2022.pem';

  static SecurityContext? _securityContext;
  static bool _initialized = false;
  static String? _lastError;

  static bool get isInitialized => _initialized;
  static SecurityContext? get context => _securityContext;
  static String? get lastError => _lastError;

  /// Loads and registers the SSL.com Root CA certificate into a SecurityContext.
  /// Retains normal system root certificates via [withTrustedRoots: true].
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final context = SecurityContext(withTrustedRoots: true);
      final certData = await rootBundle.load(rootCertAssetPath);
      final bytes = certData.buffer.asUint8List();

      context.setTrustedCertificatesBytes(bytes);
      _securityContext = context;
      _initialized = true;
      _lastError = null;
      debugPrint(
        '🔒 [SslSecurityContext] SSL.com Root CA 2022 registered successfully.',
      );
    } catch (e, stack) {
      _initialized = false;
      _lastError = e.toString();
      debugPrint(
        '⚠️ [SslSecurityContext] Failed to load Root CA asset: $e\n$stack',
      );
    }
  }

  /// Synchronous fallback helper for isolates or tests where certificate bytes are directly available.
  static void initializeFromBytes(List<int> certBytes) {
    try {
      final context = SecurityContext(withTrustedRoots: true);
      context.setTrustedCertificatesBytes(certBytes);
      _securityContext = context;
      _initialized = true;
      _lastError = null;
    } catch (e) {
      _initialized = false;
      _lastError = e.toString();
      debugPrint('⚠️ [SslSecurityContext] initializeFromBytes error: $e');
    }
  }
}
