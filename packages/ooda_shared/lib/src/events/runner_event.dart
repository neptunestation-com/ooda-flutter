import 'package:meta/meta.dart';

/// Severity level for runner events.
enum RunnerEventSeverity { debug, info, warning, error }

/// Base class for runner events (logs and diagnostics).
@immutable
sealed class RunnerEvent {
  const RunnerEvent({
    DateTime? timestamp,
    this.severity = RunnerEventSeverity.info,
  }) : timestamp = timestamp ?? const _Now();

  final DateTime timestamp;
  final RunnerEventSeverity severity;

  Map<String, dynamic> toJson();
}

class _Now implements DateTime {
  const _Now();
  DateTime get _n => DateTime.now();
  @override
  DateTime add(Duration duration) => _n.add(duration);
  @override
  int compareTo(DateTime other) => _n.compareTo(other);
  @override
  int get day => _n.day;
  @override
  Duration difference(DateTime other) => _n.difference(other);
  @override
  int get hour => _n.hour;
  @override
  bool isAfter(DateTime other) => _n.isAfter(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _n.isAtSameMomentAs(other);
  @override
  bool isBefore(DateTime other) => _n.isBefore(other);
  @override
  bool get isUtc => _n.isUtc;
  @override
  int get microsecond => _n.microsecond;
  @override
  int get microsecondsSinceEpoch => _n.microsecondsSinceEpoch;
  @override
  int get millisecond => _n.millisecond;
  @override
  int get millisecondsSinceEpoch => _n.millisecondsSinceEpoch;
  @override
  int get minute => _n.minute;
  @override
  int get month => _n.month;
  @override
  int get second => _n.second;
  @override
  DateTime subtract(Duration duration) => _n.subtract(duration);
  @override
  String get timeZoneName => _n.timeZoneName;
  @override
  Duration get timeZoneOffset => _n.timeZoneOffset;
  @override
  String toIso8601String() => _n.toIso8601String();
  @override
  DateTime toLocal() => _n.toLocal();
  @override
  DateTime toUtc() => _n.toUtc();
  @override
  int get weekday => _n.weekday;
  @override
  int get year => _n.year;
}

/// Log message event.
@immutable
class LogEvent extends RunnerEvent {
  const LogEvent({
    required this.message,
    this.source,
    super.timestamp,
    super.severity,
  });

  final String message;
  final String? source;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'log',
    'message': message,
    if (source != null) 'source': source,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() => '[$severity] $message';
}

/// Progress event (for long-running operations).
@immutable
class ProgressEvent extends RunnerEvent {
  const ProgressEvent({
    required this.id,
    required this.message,
    this.finished = false,
    super.timestamp,
  }) : super(severity: RunnerEventSeverity.debug);

  final String id;
  final String message;
  final bool finished;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'progress',
    'id': id,
    'message': message,
    'finished': finished,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Barrier timeout event with diagnostics.
@immutable
class BarrierTimeoutEvent extends RunnerEvent {
  const BarrierTimeoutEvent({
    required this.barrierName,
    required this.elapsed,
    this.diagnosticInfo,
    this.screenshotPath,
    this.logcatPath,
    super.timestamp,
  }) : super(severity: RunnerEventSeverity.error);

  final String barrierName;
  final Duration elapsed;
  final String? diagnosticInfo;
  final String? screenshotPath;
  final String? logcatPath;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'barrier_timeout',
    'barrier_name': barrierName,
    'elapsed_ms': elapsed.inMilliseconds,
    if (diagnosticInfo != null) 'diagnostic_info': diagnosticInfo,
    if (screenshotPath != null) 'screenshot_path': screenshotPath,
    if (logcatPath != null) 'logcat_path': logcatPath,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Error event.
@immutable
class ErrorEvent extends RunnerEvent {
  const ErrorEvent({
    required this.message,
    this.error,
    this.stackTrace,
    super.timestamp,
  }) : super(severity: RunnerEventSeverity.error);

  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'error',
    'message': message,
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
  };
}
