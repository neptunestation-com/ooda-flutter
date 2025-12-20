import 'package:meta/meta.dart';

import 'checkpoint_definition.dart';
import 'interaction.dart';

/// A step in a scene - either an interaction or a checkpoint.
@immutable
sealed class SceneStep {
  const SceneStep();
}

/// A step that performs an interaction.
@immutable
class InteractionStep extends SceneStep {
  const InteractionStep(this.interaction);

  final Interaction interaction;

  @override
  String toString() => 'InteractionStep($interaction)';
}

/// A step that captures a checkpoint.
@immutable
class CheckpointStep extends SceneStep {
  const CheckpointStep(this.checkpoint);

  final CheckpointDefinition checkpoint;

  @override
  String toString() => 'CheckpointStep(${checkpoint.name})';
}

/// Setup configuration for a scene.
@immutable
class SceneSetup {
  const SceneSetup({
    this.hotRestart = false,
    this.navigateTo,
    this.setupDelayMs,
  });

  factory SceneSetup.fromMap(Map<String, dynamic> map) {
    return SceneSetup(
      hotRestart: map['hot_restart'] as bool? ?? false,
      navigateTo: map['navigate_to'] as String?,
      setupDelayMs: map['setup_delay_ms'] as int?,
    );
  }

  /// Whether to hot restart before the scene.
  final bool hotRestart;

  /// Optional route to navigate to.
  final String? navigateTo;

  /// Optional delay after setup in milliseconds.
  final int? setupDelayMs;

  Map<String, dynamic> toJson() {
    return {
      'hot_restart': hotRestart,
      if (navigateTo != null) 'navigate_to': navigateTo,
      if (setupDelayMs != null) 'setup_delay_ms': setupDelayMs,
    };
  }
}

/// Barrier configuration for a scene.
@immutable
class BarrierConfig {
  const BarrierConfig({
    this.timeoutMs = 5000,
    this.consecutiveMatches = 3,
    this.pollingIntervalMs = 100,
  });

  factory BarrierConfig.fromMap(Map<String, dynamic> map) {
    return BarrierConfig(
      timeoutMs: _parseDuration(map['timeout']) ?? 5000,
      consecutiveMatches: map['consecutive_matches'] as int? ?? 3,
      pollingIntervalMs: map['polling_interval_ms'] as int? ?? 100,
    );
  }

  /// Timeout in milliseconds.
  final int timeoutMs;

  /// Number of consecutive matches for visual stability.
  final int consecutiveMatches;

  /// Polling interval in milliseconds.
  final int pollingIntervalMs;

  static int? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      // Parse strings like "5s", "500ms"
      if (value.endsWith('s') && !value.endsWith('ms')) {
        final seconds = int.tryParse(value.substring(0, value.length - 1));
        if (seconds != null) return seconds * 1000;
      }
      if (value.endsWith('ms')) {
        return int.tryParse(value.substring(0, value.length - 2));
      }
      return int.tryParse(value);
    }
    return null;
  }
}

/// Complete definition of a scene.
@immutable
class SceneDefinition {
  const SceneDefinition({
    required this.name,
    this.description,
    this.setup = const SceneSetup(),
    required this.steps,
    this.barriers = const {},
  });

  /// Unique name of the scene.
  final String name;

  /// Optional description.
  final String? description;

  /// Setup configuration.
  final SceneSetup setup;

  /// Ordered list of steps (interactions and checkpoints).
  final List<SceneStep> steps;

  /// Barrier configurations by name.
  final Map<String, BarrierConfig> barriers;

  /// Get all checkpoints in this scene.
  List<CheckpointDefinition> get checkpoints {
    return steps
        .whereType<CheckpointStep>()
        .map((s) => s.checkpoint)
        .toList();
  }

  /// Get barrier config by name, or default.
  BarrierConfig getBarrierConfig(String name) {
    return barriers[name] ?? const BarrierConfig();
  }

  @override
  String toString() =>
      'SceneDefinition(name: $name, steps: ${steps.length}, checkpoints: ${checkpoints.length})';
}
