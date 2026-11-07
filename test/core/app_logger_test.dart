import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/utils/app_logger.dart';

void main() {
  group('AppLogger Tests', () {
    test('AppLogger methods execute without exceptions', () {
      expect(() => AppLogger.debug('Debug test message', 'TEST'), returnsNormally);
      expect(() => AppLogger.info('Info test message', 'TEST'), returnsNormally);
      expect(() => AppLogger.warning('Warning test message', 'TEST'), returnsNormally);
      expect(
        () => AppLogger.error('Error test message', Exception('Test error'), StackTrace.current, 'TEST'),
        returnsNormally,
      );
    });
  });
}
