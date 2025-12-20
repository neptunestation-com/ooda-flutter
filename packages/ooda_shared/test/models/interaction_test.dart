import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Interaction types', () {
    group('TapInteraction', () {
      test('creates with coordinates', () {
        const tap = TapInteraction(x: 100, y: 200);
        expect(tap.x, 100);
        expect(tap.y, 200);
      });

      test('serializes to JSON', () {
        const tap = TapInteraction(x: 100, y: 200);
        final json = tap.toJson();

        expect(json['type'], 'tap');
        expect(json['x'], 100);
        expect(json['y'], 200);
      });
    });

    group('TextInputInteraction', () {
      test('creates with text', () {
        const input = TextInputInteraction(text: 'hello world');
        expect(input.text, 'hello world');
      });

      test('serializes to JSON', () {
        const input = TextInputInteraction(text: 'test@example.com');
        final json = input.toJson();

        expect(json['type'], 'text_input');
        expect(json['text'], 'test@example.com');
      });
    });

    group('KeyEventInteraction', () {
      test('creates with key code', () {
        const keyEvent = KeyEventInteraction(keyCode: 66);
        expect(keyEvent.keyCode, 66);
      });

      test('creates back key', () {
        const backKey = KeyEventInteraction.back();
        expect(backKey.keyCode, KeyEventInteraction.keyBack);
        expect(backKey.keyCode, 4);
      });

      test('creates enter key', () {
        const enterKey = KeyEventInteraction.enter();
        expect(enterKey.keyCode, KeyEventInteraction.keyEnter);
        expect(enterKey.keyCode, 66);
      });

      test('creates home key', () {
        const homeKey = KeyEventInteraction.home();
        expect(homeKey.keyCode, KeyEventInteraction.keyHome);
        expect(homeKey.keyCode, 3);
      });

      test('serializes to JSON', () {
        const keyEvent = KeyEventInteraction.enter();
        final json = keyEvent.toJson();

        expect(json['type'], 'key_event');
        expect(json['key_code'], 66);
      });
    });

    group('SwipeInteraction', () {
      test('creates with coordinates', () {
        const swipe = SwipeInteraction(
          startX: 100,
          startY: 500,
          endX: 100,
          endY: 200,
        );

        expect(swipe.startX, 100);
        expect(swipe.startY, 500);
        expect(swipe.endX, 100);
        expect(swipe.endY, 200);
        expect(swipe.durationMs, 300); // default
      });

      test('creates with custom duration', () {
        const swipe = SwipeInteraction(
          startX: 0,
          startY: 0,
          endX: 100,
          endY: 100,
          durationMs: 500,
        );

        expect(swipe.durationMs, 500);
      });

      test('serializes to JSON', () {
        const swipe = SwipeInteraction(
          startX: 100,
          startY: 500,
          endX: 100,
          endY: 200,
          durationMs: 400,
        );
        final json = swipe.toJson();

        expect(json['type'], 'swipe');
        expect(json['start_x'], 100);
        expect(json['start_y'], 500);
        expect(json['end_x'], 100);
        expect(json['end_y'], 200);
        expect(json['duration_ms'], 400);
      });
    });

    group('WaitInteraction', () {
      test('creates with barrier type', () {
        const wait = WaitInteraction(barrierType: 'visual_stability');
        expect(wait.barrierType, 'visual_stability');
        expect(wait.timeoutMs, isNull);
      });

      test('creates with custom timeout', () {
        const wait = WaitInteraction(
          barrierType: 'visual_stability',
          timeoutMs: 10000,
        );
        expect(wait.timeoutMs, 10000);
      });

      test('serializes to JSON without timeout', () {
        const wait = WaitInteraction(barrierType: 'visual_stability');
        final json = wait.toJson();

        expect(json['type'], 'wait');
        expect(json['barrier'], 'visual_stability');
        expect(json.containsKey('timeout_ms'), isFalse);
      });

      test('serializes to JSON with timeout', () {
        const wait = WaitInteraction(
          barrierType: 'visual_stability',
          timeoutMs: 5000,
        );
        final json = wait.toJson();

        expect(json['timeout_ms'], 5000);
      });
    });
  });
}
