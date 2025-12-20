import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

void main() {
  group('BarrierResult', () {
    test('creates success result', () {
      final result = BarrierResult.success(
        value: 'test-value',
        elapsed: const Duration(milliseconds: 500),
      );

      expect(result.success, isTrue);
      expect(result.value, 'test-value');
      expect(result.elapsed, const Duration(milliseconds: 500));
      expect(result.diagnosticInfo, isNull);
      expect(result.error, isNull);
    });

    test('creates timeout result', () {
      final result = BarrierResult<String>.timeout(
        elapsed: const Duration(seconds: 30),
        diagnosticInfo: 'Device not ready',
      );

      expect(result.success, isFalse);
      expect(result.value, isNull);
      expect(result.elapsed, const Duration(seconds: 30));
      expect(result.diagnosticInfo, 'Device not ready');
    });

    test('timeout result has default diagnostic info', () {
      final result = BarrierResult<String>.timeout(
        elapsed: const Duration(seconds: 30),
      );

      expect(result.diagnosticInfo, 'Barrier timed out');
    });

    test('creates failure result with error', () {
      final error = Exception('Connection failed');
      final result = BarrierResult<String>.failure(
        elapsed: const Duration(seconds: 5),
        error: error,
        diagnosticInfo: 'Failed to connect',
      );

      expect(result.success, isFalse);
      expect(result.error, error);
      expect(result.diagnosticInfo, 'Failed to connect');
    });

    test('failure result uses error toString as default diagnostic', () {
      final error = Exception('Test error');
      final result = BarrierResult<String>.failure(
        elapsed: const Duration(seconds: 5),
        error: error,
      );

      expect(result.diagnosticInfo, contains('Test error'));
    });

    test('toString for success', () {
      final result = BarrierResult.success(
        value: 42,
        elapsed: const Duration(milliseconds: 100),
      );

      expect(result.toString(), contains('success'));
      expect(result.toString(), contains('42'));
    });

    test('toString for failure', () {
      final result = BarrierResult<int>.timeout(
        elapsed: const Duration(seconds: 10),
        diagnosticInfo: 'Timeout info',
      );

      expect(result.toString(), contains('failure'));
      expect(result.toString(), contains('Timeout info'));
    });
  });
}
