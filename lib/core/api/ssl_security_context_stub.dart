/// Stub implementation of SslSecurityContext for non-supported platforms.
class SslSecurityContext {
  static const String rootCertAssetPath =
      'assets/certs/ssl_com_root_ca_2022.pem';

  static dynamic get context => null;
  static bool get isInitialized => false;

  static Future<void> initialize() async {}

  static void initializeFromBytes(List<int> certBytes) {}
}
