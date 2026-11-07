/// Web implementation of SslSecurityContext.
/// On Flutter Web, TLS handshakes and trust stores are managed directly by the browser.
class SslSecurityContext {
  static const String rootCertAssetPath =
      'assets/certs/ssl_com_root_ca_2022.pem';

  static dynamic get context => null;
  static bool get isInitialized => true;
  static String? get lastError => null;

  static Future<void> initialize() async {}

  static void initializeFromBytes(List<int> certBytes) {}
}
