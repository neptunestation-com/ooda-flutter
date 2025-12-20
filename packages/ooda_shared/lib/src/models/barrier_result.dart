import 'package:meta/meta.dart';

/// Result of waiting on a barrier.
@immutable
class BarrierResult<T> {
  const BarrierResult({
    required this.success,
    this.value,
    required this.elapsed,
    this.diagnosticInfo,
    this.error,
  });

  /// Create a successful result.
  factory BarrierResult.success({
    T? value,
    required Duration elapsed,
  }) {
    return BarrierResult(
      success: true,
      value: value,
      elapsed: elapsed,
    );
  }

  /// Create a timeout failure result.
  factory BarrierResult.timeout({
    required Duration elapsed,
    String? diagnosticInfo,
  }) {
    return BarrierResult(
      success: false,
      elapsed: elapsed,
      diagnosticInfo: diagnosticInfo ?? 'Barrier timed out',
    );
  }

  /// Create an error failure result.
  factory BarrierResult.failure({
    required Duration elapsed,
    required Object error,
    String? diagnosticInfo,
  }) {
    return BarrierResult(
      success: false,
      elapsed: elapsed,
      error: error,
      diagnosticInfo: diagnosticInfo ?? error.toString(),
    );
  }

  /// Whether the barrier condition was met successfully.
  final bool success;

  /// The value produced by the barrier (if any).
  final T? value;

  /// How long the wait took.
  final Duration elapsed;

  /// Diagnostic information on failure.
  final String? diagnosticInfo;

  /// Error that occurred during waiting (if any).
  final Object? error;

  @override
  String toString() {
    if (success) {
      return 'BarrierResult.success(value: $value, elapsed: $elapsed)';
    } else {
      return 'BarrierResult.failure(elapsed: $elapsed, diagnostic: $diagnosticInfo)';
    }
  }
}
