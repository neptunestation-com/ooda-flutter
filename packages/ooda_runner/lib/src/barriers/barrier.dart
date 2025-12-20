import 'dart:async';

import 'package:ooda_shared/ooda_shared.dart';

/// Abstract base class for event-driven barriers.
///
/// A barrier represents a condition that must be met before proceeding.
/// All barriers are:
/// - Predicate-based: they check a condition
/// - Time-bounded: they have a timeout
/// - Diagnostic on failure: they provide useful info when timing out
abstract class Barrier<T> {
  /// Human-readable name for this barrier.
  String get name;

  /// Maximum time to wait for the condition.
  Duration get timeout;

  /// Polling interval for checking the condition.
  Duration get pollingInterval;

  /// Wait for the barrier condition to be met.
  ///
  /// Returns a [BarrierResult] indicating success or failure.
  Future<BarrierResult<T>> wait();

  /// Check the condition once without waiting.
  ///
  /// Returns true if the condition is met.
  Future<bool> check();

  /// Collect diagnostic information on failure.
  ///
  /// Called when the barrier times out to provide useful debugging info.
  Future<String> collectDiagnostics();
}

/// Base implementation of a polling barrier.
///
/// Subclasses only need to implement [check] and [collectDiagnostics].
abstract class PollingBarrier<T> extends Barrier<T> {
  PollingBarrier({
    this.timeout = const Duration(seconds: 30),
    this.pollingInterval = const Duration(milliseconds: 500),
  });

  @override
  final Duration timeout;

  @override
  final Duration pollingInterval;

  /// Get the value when the condition is met.
  ///
  /// Called after [check] returns true.
  Future<T?> getValue() async => null;

  @override
  Future<BarrierResult<T>> wait() async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        if (await check()) {
          final value = await getValue();
          return BarrierResult.success(
            value: value,
            elapsed: stopwatch.elapsed,
          );
        }
      } catch (e) {
        // Continue polling on transient errors
      }

      await Future<void>.delayed(pollingInterval);
    }

    // Timeout - collect diagnostics
    final diagnostics = await collectDiagnostics();
    return BarrierResult.timeout(
      elapsed: stopwatch.elapsed,
      diagnosticInfo: diagnostics,
    );
  }
}

/// A barrier that waits for an event from a stream.
abstract class EventBarrier<T> extends Barrier<T> {
  EventBarrier({this.timeout = const Duration(seconds: 30)});

  @override
  final Duration timeout;

  /// The stream to listen to for events.
  Stream<dynamic> get eventStream;

  @override
  Duration get pollingInterval => Duration.zero; // Not used for event barriers

  /// Check if an event satisfies the barrier condition.
  bool matchesEvent(dynamic event);

  /// Extract the value from a matching event.
  T? extractValue(dynamic event);

  @override
  Future<bool> check() async {
    // Event barriers don't support one-shot checking
    return false;
  }

  @override
  Future<BarrierResult<T>> wait() async {
    final stopwatch = Stopwatch()..start();
    final completer = Completer<BarrierResult<T>>();

    late StreamSubscription<dynamic> subscription;

    // Set up timeout
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        collectDiagnostics().then((diagnostics) {
          completer.complete(
            BarrierResult.timeout(
              elapsed: stopwatch.elapsed,
              diagnosticInfo: diagnostics,
            ),
          );
        });
      }
    });

    // Listen for matching events
    subscription = eventStream.listen(
      (event) {
        if (matchesEvent(event) && !completer.isCompleted) {
          timer.cancel();
          subscription.cancel();
          completer.complete(
            BarrierResult.success(
              value: extractValue(event),
              elapsed: stopwatch.elapsed,
            ),
          );
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          timer.cancel();
          subscription.cancel();
          completer.complete(
            BarrierResult.failure(elapsed: stopwatch.elapsed, error: error),
          );
        }
      },
    );

    return completer.future;
  }
}
