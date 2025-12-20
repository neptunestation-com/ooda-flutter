import 'package:meta/meta.dart';

/// Metadata for an observation bundle.
@immutable
class ObservationMetadata {
  /// Schema version for forward compatibility.
  final String schemaVersion;

  /// Name of the scene this observation belongs to.
  final String sceneName;

  /// Name of the checkpoint within the scene.
  final String checkpointName;

  /// When the observation was captured.
  final DateTime timestamp;

  /// Whether an overlay (keyboard, dialog, etc.) was detected.
  final bool overlayPresent;

  /// The reload ID at the time of capture.
  final int? reloadId;

  /// The device/emulator ID.
  final String deviceId;

  /// Whether the screen was stable when captured.
  final String stabilityStatus;

  /// Optional description of the checkpoint.
  final String? description;

  /// Optional additional data.
  final Map<String, dynamic>? extra;

  const ObservationMetadata({
    this.schemaVersion = '1.0.0',
    required this.sceneName,
    required this.checkpointName,
    required this.timestamp,
    required this.overlayPresent,
    this.reloadId,
    required this.deviceId,
    this.stabilityStatus = 'unknown',
    this.description,
    this.extra,
  });

  /// Convert to JSON map for serialization.
  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'scene': sceneName,
      'checkpoint': checkpointName,
      'timestamp': timestamp.toIso8601String(),
      'overlay_present': overlayPresent,
      if (reloadId != null) 'reload_id': reloadId,
      'device_id': deviceId,
      'stability_status': stabilityStatus,
      if (description != null) 'description': description,
      if (extra != null) ...extra!,
    };
  }

  /// Create from JSON map.
  factory ObservationMetadata.fromJson(Map<String, dynamic> json) {
    return ObservationMetadata(
      schemaVersion: json['schema_version'] as String? ?? '1.0.0',
      sceneName: json['scene'] as String,
      checkpointName: json['checkpoint'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      overlayPresent: json['overlay_present'] as bool,
      reloadId: json['reload_id'] as int?,
      deviceId: json['device_id'] as String,
      stabilityStatus: json['stability_status'] as String? ?? 'unknown',
      description: json['description'] as String?,
    );
  }

  @override
  String toString() =>
      'ObservationMetadata(scene: $sceneName, checkpoint: $checkpointName)';
}
