import 'package:meta/meta.dart';

/// Base class for lifecycle events.
@immutable
sealed class LifecycleEvent {
  const LifecycleEvent({DateTime? timestamp})
    : timestamp = timestamp ?? const _CurrentDateTime();

  /// When this event occurred.
  final DateTime timestamp;

  /// Convert to JSON map.
  Map<String, dynamic> toJson();
}

/// Helper class to get current time in const context.
class _CurrentDateTime implements DateTime {
  const _CurrentDateTime();

  DateTime get _now => DateTime.now();

  @override
  DateTime add(Duration duration) => _now.add(duration);
  @override
  int compareTo(DateTime other) => _now.compareTo(other);
  @override
  int get day => _now.day;
  @override
  Duration difference(DateTime other) => _now.difference(other);
  @override
  int get hour => _now.hour;
  @override
  bool isAfter(DateTime other) => _now.isAfter(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _now.isAtSameMomentAs(other);
  @override
  bool isBefore(DateTime other) => _now.isBefore(other);
  @override
  bool get isUtc => _now.isUtc;
  @override
  int get microsecond => _now.microsecond;
  @override
  int get microsecondsSinceEpoch => _now.microsecondsSinceEpoch;
  @override
  int get millisecond => _now.millisecond;
  @override
  int get millisecondsSinceEpoch => _now.millisecondsSinceEpoch;
  @override
  int get minute => _now.minute;
  @override
  int get month => _now.month;
  @override
  int get second => _now.second;
  @override
  DateTime subtract(Duration duration) => _now.subtract(duration);
  @override
  String get timeZoneName => _now.timeZoneName;
  @override
  Duration get timeZoneOffset => _now.timeZoneOffset;
  @override
  String toIso8601String() => _now.toIso8601String();
  @override
  DateTime toLocal() => _now.toLocal();
  @override
  DateTime toUtc() => _now.toUtc();
  @override
  int get weekday => _now.weekday;
  @override
  int get year => _now.year;
}

/// Device connected event.
@immutable
class DeviceConnectedEvent extends LifecycleEvent {
  const DeviceConnectedEvent({
    required this.deviceId,
    required this.isEmulator,
    super.timestamp,
  });

  final String deviceId;
  final bool isEmulator;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'device_connected',
    'device_id': deviceId,
    'is_emulator': isEmulator,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Device boot completed event.
@immutable
class DeviceBootCompleteEvent extends LifecycleEvent {
  const DeviceBootCompleteEvent({
    required this.deviceId,
    required this.bootDuration,
    super.timestamp,
  });

  final String deviceId;
  final Duration bootDuration;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'device_boot_complete',
    'device_id': deviceId,
    'boot_duration_ms': bootDuration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// App started event.
@immutable
class AppStartedEvent extends LifecycleEvent {
  const AppStartedEvent({
    required this.deviceId,
    required this.appId,
    this.vmServiceUri,
    super.timestamp,
  });

  final String deviceId;
  final String appId;
  final Uri? vmServiceUri;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'app_started',
    'device_id': deviceId,
    'app_id': appId,
    if (vmServiceUri != null) 'vm_service_uri': vmServiceUri.toString(),
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Hot reload completed event.
@immutable
class ReloadCompleteEvent extends LifecycleEvent {
  const ReloadCompleteEvent({
    required this.reloadDuration,
    required this.reloadId,
    super.timestamp,
  });

  final Duration reloadDuration;
  final int reloadId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'reload_complete',
    'reload_duration_ms': reloadDuration.inMilliseconds,
    'reload_id': reloadId,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Visual stability achieved event.
@immutable
class VisualStabilityEvent extends LifecycleEvent {
  const VisualStabilityEvent({
    required this.stabilizationTime,
    required this.framesChecked,
    super.timestamp,
  });

  final Duration stabilizationTime;
  final int framesChecked;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'visual_stability',
    'stabilization_time_ms': stabilizationTime.inMilliseconds,
    'frames_checked': framesChecked,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Checkpoint captured event.
@immutable
class CheckpointCapturedEvent extends LifecycleEvent {
  const CheckpointCapturedEvent({
    required this.sceneName,
    required this.checkpointName,
    required this.bundlePath,
    super.timestamp,
  });

  final String sceneName;
  final String checkpointName;
  final String bundlePath;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'checkpoint_captured',
    'scene_name': sceneName,
    'checkpoint_name': checkpointName,
    'bundle_path': bundlePath,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Session ended event.
@immutable
class SessionEndedEvent extends LifecycleEvent {
  const SessionEndedEvent({
    required this.exitCode,
    this.reason,
    super.timestamp,
  });

  final int exitCode;
  final String? reason;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'session_ended',
    'exit_code': exitCode,
    if (reason != null) 'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };
}
