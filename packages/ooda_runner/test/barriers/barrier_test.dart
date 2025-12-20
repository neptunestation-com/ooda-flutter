import 'dart:async';

import 'package:ooda_runner/src/barriers/barrier.dart';
import 'package:test/test.dart';

/// Test implementation of a polling barrier.
class TestPollingBarrier extends PollingBarrier<int> {
  TestPollingBarrier({
    required this.checkResults,
    super.timeout,
    super.pollingInterval,
  });

  final List<bool> checkResults;
  int checkIndex = 0;
  int _value = 0;

  @override
  String get name => 'TestBarrier';

  @override
  Future<bool> check() async {
    if (checkIndex >= checkResults.length) {
      return checkResults.last;
    }
    return checkResults[checkIndex++];
  }

  @override
  Future<int?> getValue() async => ++_value;

  @override
  Future<String> collectDiagnostics() async {
    return 'Test diagnostics: checked $checkIndex times';
  }
}

/// Test implementation of an event barrier.
class TestEventBarrier extends EventBarrier<String> {
  TestEventBarrier({super.timeout});

  final StreamController<String> _controller = StreamController<String>();

  @override
  String get name => 'TestEventBarrier';

  @override
  Stream<dynamic> get eventStream => _controller.stream;

  @override
  bool matchesEvent(dynamic event) {
    return event is String && event.startsWith('match:');
  }

  @override
  String? extractValue(dynamic event) {
    return (event as String).substring('match:'.length);
  }

  @override
  Future<String> collectDiagnostics() async {
    return 'Event barrier diagnostics';
  }

  void emit(String event) {
    _controller.add(event);
  }

  void close() {
    _controller.close();
  }
}

void main() {
  group('PollingBarrier', () {
    test('succeeds on first check', () async {
      final barrier = TestPollingBarrier(
        checkResults: [true],
        timeout: const Duration(seconds: 5),
        pollingInterval: const Duration(milliseconds: 10),
      );

      final result = await barrier.wait();

      expect(result.success, isTrue);
      expect(result.value, 1);
    });

    test('succeeds after multiple failed checks', () async {
      final barrier = TestPollingBarrier(
        checkResults: [false, false, false, true],
        timeout: const Duration(seconds: 5),
        pollingInterval: const Duration(milliseconds: 10),
      );

      final result = await barrier.wait();

      expect(result.success, isTrue);
      expect(barrier.checkIndex, 4);
    });

    test('times out when condition never met', () async {
      final barrier = TestPollingBarrier(
        checkResults: [false],
        timeout: const Duration(milliseconds: 50),
        pollingInterval: const Duration(milliseconds: 10),
      );

      final result = await barrier.wait();

      expect(result.success, isFalse);
      expect(result.diagnosticInfo, contains('Test diagnostics'));
    });

    test('records elapsed time', () async {
      final barrier = TestPollingBarrier(
        checkResults: [false, false, true],
        timeout: const Duration(seconds: 5),
        pollingInterval: const Duration(milliseconds: 20),
      );

      final result = await barrier.wait();

      expect(result.elapsed.inMilliseconds, greaterThanOrEqualTo(40));
    });
  });

  group('EventBarrier', () {
    test('succeeds when matching event received', () async {
      final barrier = TestEventBarrier(
        timeout: const Duration(seconds: 5),
      );

      // Emit after a short delay
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        barrier.emit('match:success');
      });

      final result = await barrier.wait();

      expect(result.success, isTrue);
      expect(result.value, 'success');

      barrier.close();
    });

    test('ignores non-matching events', () async {
      final barrier = TestEventBarrier(
        timeout: const Duration(seconds: 5),
      );

      // Emit non-matching then matching events
      Future<void>.delayed(const Duration(milliseconds: 20), () {
        barrier.emit('ignore:this');
      });
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        barrier.emit('ignore:that');
      });
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        barrier.emit('match:found');
      });

      final result = await barrier.wait();

      expect(result.success, isTrue);
      expect(result.value, 'found');

      barrier.close();
    });

    test('times out when no matching event', () async {
      final barrier = TestEventBarrier(
        timeout: const Duration(milliseconds: 50),
      );

      // Only emit non-matching events
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        barrier.emit('ignore:this');
      });

      final result = await barrier.wait();

      expect(result.success, isFalse);
      expect(result.diagnosticInfo, contains('Event barrier diagnostics'));

      barrier.close();
    });

    test('check returns false for event barriers', () async {
      final barrier = TestEventBarrier();
      expect(await barrier.check(), isFalse);
      barrier.close();
    });
  });
}
