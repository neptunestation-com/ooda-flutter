import 'dart:io';

import 'package:ooda_shared/ooda_shared.dart';
import 'package:yaml/yaml.dart';

/// Parses scene definitions from YAML files.
///
/// Scene YAML format:
/// ```yaml
/// name: login_flow
/// description: Test login form UI and keyboard interaction
///
/// setup:
///   hot_restart: true
///   navigate_to: /login
///
/// steps:
///   - checkpoint: initial_view
///     description: Login form before interaction
///
///   - tap:
///       x: 200
///       y: 300
///
///   - wait: visual_stability
///
///   - checkpoint: keyboard_up
///     description: Keyboard visible after focusing email
///
///   - input_text: "test@example.com"
///
///   - key_event: enter
///
///   - checkpoint: after_submit
///
/// barriers:
///   visual_stability:
///     timeout: 5s
///     consecutive_matches: 3
/// ```
class SceneParser {
  /// Parse a scene from a YAML file.
  static Future<SceneDefinition> parseFile(File file) async {
    final content = await file.readAsString();
    return parse(content);
  }

  /// Parse a scene from a YAML string.
  static SceneDefinition parse(String yamlContent) {
    final yaml = loadYaml(yamlContent) as YamlMap;
    return _parseScene(yaml);
  }

  static SceneDefinition _parseScene(YamlMap yaml) {
    final name = yaml['name'] as String? ?? 'unnamed';
    final description = yaml['description'] as String?;

    // Parse setup
    final setupYaml = yaml['setup'] as YamlMap?;
    final setup = setupYaml != null
        ? _parseSetup(setupYaml)
        : const SceneSetup();

    // Parse steps
    final stepsYaml = yaml['steps'] as YamlList? ?? YamlList();
    final steps = stepsYaml.map(_parseStep).toList();

    // Parse barriers
    final barriersYaml = yaml['barriers'] as YamlMap?;
    final barriers = <String, BarrierConfig>{};
    if (barriersYaml != null) {
      for (final entry in barriersYaml.entries) {
        final name = entry.key as String;
        final config = entry.value as YamlMap;
        barriers[name] = BarrierConfig.fromMap(_yamlMapToMap(config));
      }
    }

    return SceneDefinition(
      name: name,
      description: description,
      setup: setup,
      steps: steps,
      barriers: barriers,
    );
  }

  static SceneSetup _parseSetup(YamlMap yaml) {
    return SceneSetup(
      hotRestart: yaml['hot_restart'] as bool? ?? false,
      navigateTo: yaml['navigate_to'] as String?,
      setupDelayMs: yaml['setup_delay_ms'] as int?,
    );
  }

  static SceneStep _parseStep(dynamic step) {
    if (step is YamlMap) {
      // Check for checkpoint
      if (step.containsKey('checkpoint')) {
        return _parseCheckpointStep(step);
      }

      // Check for interactions
      if (step.containsKey('tap')) {
        return _parseTapStep(step);
      }
      if (step.containsKey('input_text')) {
        return _parseTextInputStep(step);
      }
      if (step.containsKey('key_event')) {
        return _parseKeyEventStep(step);
      }
      if (step.containsKey('swipe')) {
        return _parseSwipeStep(step);
      }
      if (step.containsKey('wait')) {
        return _parseWaitStep(step);
      }
      if (step.containsKey('tap_label')) {
        return _parseTapLabelStep(step);
      }
      if (step.containsKey('tap_text')) {
        return _parseTapTextStep(step);
      }

      throw SceneParseException('Unknown step type: ${step.keys}');
    }

    throw SceneParseException('Invalid step format: $step');
  }

  static CheckpointStep _parseCheckpointStep(YamlMap yaml) {
    final name = yaml['checkpoint'] as String;
    final description = yaml['description'] as String?;

    return CheckpointStep(
      CheckpointDefinition(
        name: name,
        description: description,
        captureFlutterScreenshot:
            yaml['capture_flutter_screenshot'] as bool? ?? true,
        captureDeviceScreenshot:
            yaml['capture_device_screenshot'] as bool? ?? true,
        captureWidgetTree: yaml['capture_widget_tree'] as bool? ?? true,
        captureSemanticsTree: yaml['capture_semantics_tree'] as bool? ?? true,
        captureLogs: yaml['capture_logs'] as bool? ?? true,
      ),
    );
  }

  static InteractionStep _parseTapStep(YamlMap yaml) {
    final tap = yaml['tap'];

    int x, y;
    if (tap is YamlMap) {
      x = tap['x'] as int;
      y = tap['y'] as int;
    } else {
      throw SceneParseException('Invalid tap format: $tap');
    }

    return InteractionStep(TapInteraction(x: x, y: y));
  }

  static InteractionStep _parseTextInputStep(YamlMap yaml) {
    final text = yaml['input_text'] as String;
    return InteractionStep(TextInputInteraction(text: text));
  }

  static InteractionStep _parseKeyEventStep(YamlMap yaml) {
    final keyEvent = yaml['key_event'];

    int keyCode;
    if (keyEvent is int) {
      keyCode = keyEvent;
    } else if (keyEvent is String) {
      keyCode = _parseKeyName(keyEvent);
    } else {
      throw SceneParseException('Invalid key_event format: $keyEvent');
    }

    return InteractionStep(KeyEventInteraction(keyCode: keyCode));
  }

  static int _parseKeyName(String name) {
    return switch (name.toLowerCase()) {
      'back' => KeyEventInteraction.keyBack,
      'enter' => KeyEventInteraction.keyEnter,
      'home' => KeyEventInteraction.keyHome,
      'tab' => KeyEventInteraction.keyTab,
      'escape' || 'esc' => KeyEventInteraction.keyEscape,
      _ => throw SceneParseException('Unknown key name: $name'),
    };
  }

  static InteractionStep _parseSwipeStep(YamlMap yaml) {
    final swipe = yaml['swipe'] as YamlMap;

    return InteractionStep(
      SwipeInteraction(
        startX: swipe['start_x'] as int,
        startY: swipe['start_y'] as int,
        endX: swipe['end_x'] as int,
        endY: swipe['end_y'] as int,
        durationMs: swipe['duration_ms'] as int? ?? 300,
      ),
    );
  }

  static InteractionStep _parseWaitStep(YamlMap yaml) {
    final wait = yaml['wait'];

    String barrierType;
    int? timeoutMs;

    if (wait is String) {
      barrierType = wait;
    } else if (wait is YamlMap) {
      barrierType = wait['barrier'] as String;
      timeoutMs = wait['timeout_ms'] as int?;
    } else {
      throw SceneParseException('Invalid wait format: $wait');
    }

    return InteractionStep(
      WaitInteraction(barrierType: barrierType, timeoutMs: timeoutMs),
    );
  }

  /// Check if a label is a valid namespaced semantic ID.
  /// Valid IDs contain '.' or start with 'screen:'.
  static bool _isNamespacedLabel(String label) {
    return label.contains('.') || label.startsWith('screen:');
  }

  static InteractionStep _parseTapLabelStep(YamlMap yaml) {
    final tapLabel = yaml['tap_label'];

    String label;
    int occurrence = 0;
    String? within;

    if (tapLabel is String) {
      label = tapLabel;
    } else if (tapLabel is YamlMap) {
      label = tapLabel['label'] as String;
      // Support both 'occurrence' (new) and 'match_index' (legacy)
      occurrence = tapLabel['occurrence'] as int? ??
          tapLabel['match_index'] as int? ??
          0;
      within = tapLabel['within'] as String?;
    } else {
      throw SceneParseException('Invalid tap_label format: $tapLabel');
    }

    // Validate that label is a namespaced semantic ID
    if (!_isNamespacedLabel(label)) {
      throw SceneParseException(
        'tap_label requires a semantic ID like "auth.method_picker.email". '
        'Got "$label". Use tap_text for visible text matching.',
      );
    }

    return InteractionStep(
      TapByLabelInteraction(label: label, occurrence: occurrence, within: within),
    );
  }

  static InteractionStep _parseTapTextStep(YamlMap yaml) {
    final tapText = yaml['tap_text'];

    String text;
    int occurrence = 0;
    String? within;

    if (tapText is String) {
      text = tapText;
    } else if (tapText is YamlMap) {
      text = tapText['text'] as String;
      occurrence = tapText['occurrence'] as int? ?? 0;
      within = tapText['within'] as String?;
    } else {
      throw SceneParseException('Invalid tap_text format: $tapText');
    }

    return InteractionStep(
      TapByTextInteraction(text: text, occurrence: occurrence, within: within),
    );
  }

  static Map<String, dynamic> _yamlMapToMap(YamlMap yaml) {
    final result = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key as String;
      final value = entry.value;
      if (value is YamlMap) {
        result[key] = _yamlMapToMap(value);
      } else if (value is YamlList) {
        result[key] = value.toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}

/// Exception thrown when scene parsing fails.
class SceneParseException implements Exception {
  SceneParseException(this.message);

  final String message;

  @override
  String toString() => 'SceneParseException: $message';
}
