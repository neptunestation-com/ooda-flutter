import 'package:meta/meta.dart';

/// Definition of a checkpoint within a scene.
@immutable
class CheckpointDefinition {
  const CheckpointDefinition({
    required this.name,
    this.description,
    this.captureFlutterScreenshot = true,
    this.captureDeviceScreenshot = true,
    this.captureWidgetTree = true,
    this.captureSemanticsTree = true,
    this.captureLogs = true,
  });

  /// Create from a simple name string.
  factory CheckpointDefinition.simple(String name) {
    return CheckpointDefinition(name: name);
  }

  /// Create from YAML/JSON map.
  factory CheckpointDefinition.fromMap(Map<String, dynamic> map) {
    return CheckpointDefinition(
      name: map['name'] as String,
      description: map['description'] as String?,
      captureFlutterScreenshot:
          map['capture_flutter_screenshot'] as bool? ?? true,
      captureDeviceScreenshot:
          map['capture_device_screenshot'] as bool? ?? true,
      captureWidgetTree: map['capture_widget_tree'] as bool? ?? true,
      captureSemanticsTree: map['capture_semantics_tree'] as bool? ?? true,
      captureLogs: map['capture_logs'] as bool? ?? true,
    );
  }

  /// Unique name of the checkpoint within the scene.
  final String name;

  /// Optional human-readable description.
  final String? description;

  /// Whether to capture the Flutter screenshot at this checkpoint.
  final bool captureFlutterScreenshot;

  /// Whether to capture the device screenshot at this checkpoint.
  final bool captureDeviceScreenshot;

  /// Whether to capture the widget tree at this checkpoint.
  final bool captureWidgetTree;

  /// Whether to capture the semantics tree at this checkpoint.
  final bool captureSemanticsTree;

  /// Whether to capture logs at this checkpoint.
  final bool captureLogs;

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'capture_flutter_screenshot': captureFlutterScreenshot,
      'capture_device_screenshot': captureDeviceScreenshot,
      'capture_widget_tree': captureWidgetTree,
      'capture_semantics_tree': captureSemanticsTree,
      'capture_logs': captureLogs,
    };
  }

  @override
  String toString() => 'CheckpointDefinition(name: $name)';
}
