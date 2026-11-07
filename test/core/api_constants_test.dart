import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/api/api_constants.dart';

void main() {
  group('ApiConstants Tests', () {
    test('default constants and headers are configured for MediCrate', () {
      expect(ApiConstants.apiKeyHeader, equals('x-api-key'));
      expect(ApiConstants.envApiKeyName, equals('MEDICRATE_API_KEY'));
      expect(ApiConstants.legacyEnvApiKeyName, equals('MEDIVAULT_API_KEY'));
      expect(ApiConstants.baseUrl, isNotEmpty);
      expect(ApiConstants.syncPullBatchLimit, equals(200));
    });

    test('apiKey getter returns empty string safely when dotenv is uninitialized', () {
      // In tests where dotenv.load() hasn't run, apiKey should return '' safely without throwing
      expect(ApiConstants.apiKey, equals(''));
    });
  });
}
