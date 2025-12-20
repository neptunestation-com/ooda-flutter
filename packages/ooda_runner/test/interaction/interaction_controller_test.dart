import 'package:mocktail/mocktail.dart';
import 'package:ooda_runner/src/adb/adb_client.dart';
import 'package:ooda_runner/src/interaction/interaction_controller.dart';
import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

class MockAdbClient extends Mock implements AdbClient {}

void main() {
  group('InteractionController', () {
    late MockAdbClient mockAdb;
    late InteractionController controller;
    const deviceId = 'emulator-5554';

    setUp(() {
      mockAdb = MockAdbClient();
      controller = InteractionController(
        adb: mockAdb,
        deviceId: deviceId,
        interactionDelay: Duration.zero, // No delay for tests
      );
    });

    group('tap', () {
      test('executes tap via ADB', () async {
        when(() => mockAdb.tap(deviceId, 100, 200)).thenAnswer((_) async => {});

        final result = await controller.tap(100, 200);

        expect(result.success, isTrue);
        expect(result.interaction, isA<TapInteraction>());
        verify(() => mockAdb.tap(deviceId, 100, 200)).called(1);
      });

      test('returns failure on ADB error', () async {
        when(
          () => mockAdb.tap(deviceId, 100, 200),
        ).thenThrow(AdbException('tap failed'));

        final result = await controller.tap(100, 200);

        expect(result.success, isFalse);
        expect(result.error, contains('tap failed'));
      });
    });

    group('inputText', () {
      test('executes text input via ADB', () async {
        when(
          () => mockAdb.inputText(deviceId, 'hello'),
        ).thenAnswer((_) async => {});

        final result = await controller.inputText('hello');

        expect(result.success, isTrue);
        expect(result.interaction, isA<TextInputInteraction>());
        verify(() => mockAdb.inputText(deviceId, 'hello')).called(1);
      });

      test('returns failure on ADB error', () async {
        when(
          () => mockAdb.inputText(deviceId, 'test'),
        ).thenThrow(AdbException('input failed'));

        final result = await controller.inputText('test');

        expect(result.success, isFalse);
        expect(result.error, contains('input failed'));
      });
    });

    group('keyEvent', () {
      test('executes key event via ADB', () async {
        when(() => mockAdb.keyEvent(deviceId, 66)).thenAnswer((_) async => {});

        final result = await controller.keyEvent(66);

        expect(result.success, isTrue);
        expect(result.interaction, isA<KeyEventInteraction>());
        verify(() => mockAdb.keyEvent(deviceId, 66)).called(1);
      });

      test('returns failure on ADB error', () async {
        when(
          () => mockAdb.keyEvent(deviceId, 4),
        ).thenThrow(AdbException('key event failed'));

        final result = await controller.keyEvent(4);

        expect(result.success, isFalse);
        expect(result.error, contains('key event failed'));
      });
    });

    group('swipe', () {
      test('executes swipe via ADB', () async {
        when(
          () => mockAdb.swipe(
            deviceId,
            startX: 540,
            startY: 1500,
            endX: 540,
            endY: 500,
            durationMs: 300,
          ),
        ).thenAnswer((_) async => {});

        final result = await controller.swipe(
          startX: 540,
          startY: 1500,
          endX: 540,
          endY: 500,
          durationMs: 300,
        );

        expect(result.success, isTrue);
        expect(result.interaction, isA<SwipeInteraction>());
        verify(
          () => mockAdb.swipe(
            deviceId,
            startX: 540,
            startY: 1500,
            endX: 540,
            endY: 500,
            durationMs: 300,
          ),
        ).called(1);
      });
    });

    group('convenience methods', () {
      test('back() sends back key event', () async {
        when(
          () => mockAdb.keyEvent(deviceId, KeyEventInteraction.keyBack),
        ).thenAnswer((_) async => {});

        final result = await controller.back();

        expect(result.success, isTrue);
        verify(
          () => mockAdb.keyEvent(deviceId, KeyEventInteraction.keyBack),
        ).called(1);
      });

      test('enter() sends enter key event', () async {
        when(
          () => mockAdb.keyEvent(deviceId, KeyEventInteraction.keyEnter),
        ).thenAnswer((_) async => {});

        final result = await controller.enter();

        expect(result.success, isTrue);
        verify(
          () => mockAdb.keyEvent(deviceId, KeyEventInteraction.keyEnter),
        ).called(1);
      });

      test('home() sends home key event', () async {
        when(
          () => mockAdb.keyEvent(deviceId, KeyEventInteraction.keyHome),
        ).thenAnswer((_) async => {});

        final result = await controller.home();

        expect(result.success, isTrue);
        verify(
          () => mockAdb.keyEvent(deviceId, KeyEventInteraction.keyHome),
        ).called(1);
      });

      test('scrollUp() performs upward swipe', () async {
        when(
          () => mockAdb.swipe(
            deviceId,
            startX: 540,
            startY: 1500,
            endX: 540,
            endY: 500,
            durationMs: 300,
          ),
        ).thenAnswer((_) async => {});

        final result = await controller.scrollUp();

        expect(result.success, isTrue);
        verify(
          () => mockAdb.swipe(
            deviceId,
            startX: 540,
            startY: 1500,
            endX: 540,
            endY: 500,
            durationMs: 300,
          ),
        ).called(1);
      });

      test('scrollDown() performs downward swipe', () async {
        when(
          () => mockAdb.swipe(
            deviceId,
            startX: 540,
            startY: 500,
            endX: 540,
            endY: 1500,
            durationMs: 300,
          ),
        ).thenAnswer((_) async => {});

        final result = await controller.scrollDown();

        expect(result.success, isTrue);
        verify(
          () => mockAdb.swipe(
            deviceId,
            startX: 540,
            startY: 500,
            endX: 540,
            endY: 1500,
            durationMs: 300,
          ),
        ).called(1);
      });
    });

    group('execute', () {
      test('handles WaitInteraction by doing nothing', () async {
        const wait = WaitInteraction(barrierType: 'visual_stability');

        final result = await controller.execute(wait);

        expect(result.success, isTrue);
        expect(result.interaction, wait);
        verifyNever(() => mockAdb.tap(any(), any(), any()));
      });

      test('tracks elapsed time', () async {
        when(() => mockAdb.tap(deviceId, 100, 200)).thenAnswer((_) async => {});

        final result = await controller.tap(100, 200);

        expect(result.elapsed.inMicroseconds, greaterThan(0));
      });
    });
  });

  group('InteractionResult', () {
    test('success toString format', () {
      final result = InteractionResult(
        success: true,
        interaction: const TapInteraction(x: 100, y: 200),
        elapsed: const Duration(milliseconds: 50),
      );

      expect(result.toString(), contains('success'));
      expect(result.toString(), contains('50ms'));
    });

    test('failure toString format', () {
      final result = InteractionResult(
        success: false,
        interaction: const TapInteraction(x: 100, y: 200),
        elapsed: const Duration(milliseconds: 50),
        error: 'tap failed',
      );

      expect(result.toString(), contains('failure'));
      expect(result.toString(), contains('tap failed'));
    });
  });
}
