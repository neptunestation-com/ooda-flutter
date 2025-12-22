import 'package:ooda_runner/src/scenes/scene_parser.dart';
import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SceneParser', () {
    test('parses minimal scene', () {
      const yaml = '''
name: test_scene
steps: []
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.name, 'test_scene');
      expect(scene.description, isNull);
      expect(scene.steps, isEmpty);
    });

    test('parses scene with description', () {
      const yaml = '''
name: login_test
description: Tests login functionality
steps: []
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.name, 'login_test');
      expect(scene.description, 'Tests login functionality');
    });

    test('parses setup configuration', () {
      const yaml = '''
name: test_scene
setup:
  hot_restart: true
  navigate_to: /login
  setup_delay_ms: 500
steps: []
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.setup.hotRestart, isTrue);
      expect(scene.setup.navigateTo, '/login');
      expect(scene.setup.setupDelayMs, 500);
    });

    test('parses checkpoint step', () {
      const yaml = '''
name: test_scene
steps:
  - checkpoint: initial_view
    description: The initial view of the app
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.steps.length, 1);
      expect(scene.steps[0], isA<CheckpointStep>());

      final step = scene.steps[0] as CheckpointStep;
      expect(step.checkpoint.name, 'initial_view');
      expect(step.checkpoint.description, 'The initial view of the app');
    });

    test('parses checkpoint with capture options', () {
      const yaml = '''
name: test_scene
steps:
  - checkpoint: minimal_capture
    capture_flutter_screenshot: false
    capture_widget_tree: false
    capture_semantics_tree: false
    capture_logs: false
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as CheckpointStep;

      expect(step.checkpoint.captureFlutterScreenshot, isFalse);
      expect(step.checkpoint.captureWidgetTree, isFalse);
      expect(step.checkpoint.captureSemanticsTree, isFalse);
      expect(step.checkpoint.captureLogs, isFalse);
      expect(step.checkpoint.captureDeviceScreenshot, isTrue); // default
    });

    test('parses tap step', () {
      const yaml = '''
name: test_scene
steps:
  - tap:
      x: 100
      y: 200
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.steps.length, 1);
      expect(scene.steps[0], isA<InteractionStep>());

      final step = scene.steps[0] as InteractionStep;
      expect(step.interaction, isA<TapInteraction>());

      final tap = step.interaction as TapInteraction;
      expect(tap.x, 100);
      expect(tap.y, 200);
    });

    test('parses input_text step', () {
      const yaml = '''
name: test_scene
steps:
  - input_text: "test@example.com"
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as InteractionStep;
      final input = step.interaction as TextInputInteraction;

      expect(input.text, 'test@example.com');
    });

    test('parses key_event step with name', () {
      const yaml = '''
name: test_scene
steps:
  - key_event: enter
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as InteractionStep;
      final keyEvent = step.interaction as KeyEventInteraction;

      expect(keyEvent.keyCode, KeyEventInteraction.keyEnter);
    });

    test('parses key_event step with code', () {
      const yaml = '''
name: test_scene
steps:
  - key_event: 67
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as InteractionStep;
      final keyEvent = step.interaction as KeyEventInteraction;

      expect(keyEvent.keyCode, 67);
    });

    test('parses all key event names', () {
      const yaml = '''
name: test_scene
steps:
  - key_event: back
  - key_event: enter
  - key_event: home
  - key_event: tab
  - key_event: escape
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.steps.length, 5);

      final keyCodes = scene.steps.map((s) {
        final step = s as InteractionStep;
        final keyEvent = step.interaction as KeyEventInteraction;
        return keyEvent.keyCode;
      }).toList();

      expect(keyCodes, [
        KeyEventInteraction.keyBack,
        KeyEventInteraction.keyEnter,
        KeyEventInteraction.keyHome,
        KeyEventInteraction.keyTab,
        KeyEventInteraction.keyEscape,
      ]);
    });

    test('parses swipe step', () {
      const yaml = '''
name: test_scene
steps:
  - swipe:
      start_x: 540
      start_y: 1500
      end_x: 540
      end_y: 500
      duration_ms: 300
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as InteractionStep;
      final swipe = step.interaction as SwipeInteraction;

      expect(swipe.startX, 540);
      expect(swipe.startY, 1500);
      expect(swipe.endX, 540);
      expect(swipe.endY, 500);
      expect(swipe.durationMs, 300);
    });

    test('parses wait step with string barrier', () {
      const yaml = '''
name: test_scene
steps:
  - wait: visual_stability
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as InteractionStep;
      final wait = step.interaction as WaitInteraction;

      expect(wait.barrierType, 'visual_stability');
      expect(wait.timeoutMs, isNull);
    });

    test('parses wait step with map barrier', () {
      const yaml = '''
name: test_scene
steps:
  - wait:
      barrier: visual_stability
      timeout_ms: 10000
''';

      final scene = SceneParser.parse(yaml);
      final step = scene.steps[0] as InteractionStep;
      final wait = step.interaction as WaitInteraction;

      expect(wait.barrierType, 'visual_stability');
      expect(wait.timeoutMs, 10000);
    });

    group('tap_label (strict semantic ID)', () {
      test('parses tap_label with namespaced ID (contains dot)', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label: "auth.login_button"
''';

        final scene = SceneParser.parse(yaml);

        expect(scene.steps.length, 1);
        expect(scene.steps[0], isA<InteractionStep>());

        final step = scene.steps[0] as InteractionStep;
        expect(step.interaction, isA<TapByLabelInteraction>());

        final tapLabel = step.interaction as TapByLabelInteraction;
        expect(tapLabel.label, 'auth.login_button');
        expect(tapLabel.occurrence, 0);
        expect(tapLabel.within, isNull);
      });

      test('parses tap_label with screen: prefix', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label: "screen:login"
''';

        final scene = SceneParser.parse(yaml);
        final step = scene.steps[0] as InteractionStep;
        final tapLabel = step.interaction as TapByLabelInteraction;

        expect(tapLabel.label, 'screen:login');
      });

      test('parses tap_label with occurrence (new field)', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label:
      label: "form.submit"
      occurrence: 2
''';

        final scene = SceneParser.parse(yaml);
        final step = scene.steps[0] as InteractionStep;
        final tapLabel = step.interaction as TapByLabelInteraction;

        expect(tapLabel.label, 'form.submit');
        expect(tapLabel.occurrence, 2);
      });

      test('parses tap_label with legacy match_index (backward compat)', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label:
      label: "form.submit"
      match_index: 1
''';

        final scene = SceneParser.parse(yaml);
        final step = scene.steps[0] as InteractionStep;
        final tapLabel = step.interaction as TapByLabelInteraction;

        expect(tapLabel.label, 'form.submit');
        expect(tapLabel.occurrence, 1);
      });

      test('parses tap_label with within constraint', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label:
      label: "widget.button"
      within: "screen:auth.login"
''';

        final scene = SceneParser.parse(yaml);
        final step = scene.steps[0] as InteractionStep;
        final tapLabel = step.interaction as TapByLabelInteraction;

        expect(tapLabel.label, 'widget.button');
        expect(tapLabel.within, 'screen:auth.login');
      });

      test('throws for non-namespaced label (plain text like "Email")', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label: "Email"
''';

        expect(
          () => SceneParser.parse(yaml),
          throwsA(
            isA<SceneParseException>().having(
              (e) => e.message,
              'message',
              contains('tap_label requires a semantic ID'),
            ),
          ),
        );
      });

      test('throws for non-namespaced label (plain text like "Login")', () {
        const yaml = '''
name: test_scene
steps:
  - tap_label: "Login"
''';

        expect(
          () => SceneParser.parse(yaml),
          throwsA(
            isA<SceneParseException>().having(
              (e) => e.message,
              'message',
              contains('Use tap_text for visible text matching'),
            ),
          ),
        );
      });
    });

    group('tap_text (visible text matching)', () {
      test('parses tap_text with string text', () {
        const yaml = '''
name: test_scene
steps:
  - tap_text: "Login"
''';

        final scene = SceneParser.parse(yaml);

        expect(scene.steps.length, 1);
        expect(scene.steps[0], isA<InteractionStep>());

        final step = scene.steps[0] as InteractionStep;
        expect(step.interaction, isA<TapByTextInteraction>());

        final tapText = step.interaction as TapByTextInteraction;
        expect(tapText.text, 'Login');
        expect(tapText.occurrence, 0);
        expect(tapText.within, isNull);
      });

      test('parses tap_text with extended form', () {
        const yaml = '''
name: test_scene
steps:
  - tap_text:
      text: "Submit"
      occurrence: 1
      within: "screen:auth.login"
''';

        final scene = SceneParser.parse(yaml);
        final step = scene.steps[0] as InteractionStep;
        final tapText = step.interaction as TapByTextInteraction;

        expect(tapText.text, 'Submit');
        expect(tapText.occurrence, 1);
        expect(tapText.within, 'screen:auth.login');
      });

      test('allows any text string (no namespace requirement)', () {
        const yaml = '''
name: test_scene
steps:
  - tap_text: "Email"
  - tap_text: "Click here to continue"
  - tap_text: "OK"
''';

        final scene = SceneParser.parse(yaml);
        expect(scene.steps.length, 3);

        final texts = scene.steps.map((s) {
          final step = s as InteractionStep;
          final tapText = step.interaction as TapByTextInteraction;
          return tapText.text;
        }).toList();

        expect(texts, ['Email', 'Click here to continue', 'OK']);
      });
    });

    test('parses barriers configuration', () {
      const yaml = '''
name: test_scene
steps: []
barriers:
  visual_stability:
    timeout_ms: 5000
    consecutive_matches: 3
    polling_interval_ms: 200
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.barriers.containsKey('visual_stability'), isTrue);

      final config = scene.barriers['visual_stability']!;
      expect(config.timeoutMs, 5000);
      expect(config.consecutiveMatches, 3);
      expect(config.pollingIntervalMs, 200);
    });

    test('parses complete scene', () {
      const yaml = '''
name: login_flow
description: Test login form UI

setup:
  hot_restart: true
  navigate_to: /login

steps:
  - checkpoint: initial_view
  - tap:
      x: 540
      y: 400
  - wait: visual_stability
  - checkpoint: keyboard_up
  - input_text: "test@example.com"
  - key_event: enter
  - checkpoint: after_submit

barriers:
  visual_stability:
    timeout_ms: 5000
''';

      final scene = SceneParser.parse(yaml);

      expect(scene.name, 'login_flow');
      expect(scene.description, 'Test login form UI');
      expect(scene.setup.hotRestart, isTrue);
      expect(scene.setup.navigateTo, '/login');
      expect(scene.steps.length, 7);
      expect(scene.checkpoints.length, 3);
    });

    test('throws on unknown step type', () {
      const yaml = '''
name: test_scene
steps:
  - unknown_step: value
''';

      expect(
        () => SceneParser.parse(yaml),
        throwsA(isA<SceneParseException>()),
      );
    });

    test('throws on invalid step format', () {
      const yaml = '''
name: test_scene
steps:
  - just_a_string
''';

      expect(
        () => SceneParser.parse(yaml),
        throwsA(isA<SceneParseException>()),
      );
    });

    test('throws on unknown key name', () {
      const yaml = '''
name: test_scene
steps:
  - key_event: unknown_key
''';

      expect(
        () => SceneParser.parse(yaml),
        throwsA(isA<SceneParseException>()),
      );
    });
  });
}
