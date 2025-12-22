import 'dart:async';

import 'package:ooda_shared/ooda_shared.dart';

import '../adb/adb_client.dart';

/// Controls device interactions via ADB.
///
/// Executes taps, text input, key events, and swipes on the device.
class InteractionController {
  InteractionController({
    required AdbClient adb,
    required String deviceId,
    this.interactionDelay = const Duration(milliseconds: 100),
  }) : _adb = adb,
       _deviceId = deviceId;

  final AdbClient _adb;
  final String _deviceId;

  /// Delay after each interaction to let the UI settle.
  final Duration interactionDelay;

  /// Execute an interaction.
  Future<InteractionResult> execute(Interaction interaction) async {
    final stopwatch = Stopwatch()..start();

    try {
      switch (interaction) {
        case TapInteraction(:final x, :final y):
          await _adb.tap(_deviceId, x, y);
          break;

        case TextInputInteraction(:final text):
          await _adb.inputText(_deviceId, text);
          break;

        case KeyEventInteraction(:final keyCode):
          await _adb.keyEvent(_deviceId, keyCode);
          break;

        case SwipeInteraction(
          :final startX,
          :final startY,
          :final endX,
          :final endY,
          :final durationMs,
        ):
          await _adb.swipe(
            _deviceId,
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            durationMs: durationMs,
          );
          break;

        case WaitInteraction():
          // Wait interactions are handled by the scene executor
          break;

        case TapByLabelInteraction():
          // TapByLabel interactions are resolved by the scene executor
          // which gets the semantics tree, finds the label, and calls tap()
          throw StateError(
            'TapByLabelInteraction should be resolved by SceneExecutor, '
            'not executed directly',
          );

        case TapByTextInteraction():
          // TapByText interactions are resolved by the scene executor
          // which gets the semantics tree, finds the text, and calls tap()
          throw StateError(
            'TapByTextInteraction should be resolved by SceneExecutor, '
            'not executed directly',
          );
      }

      // Small delay to let UI settle
      await Future<void>.delayed(interactionDelay);

      return InteractionResult(
        success: true,
        interaction: interaction,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      return InteractionResult(
        success: false,
        interaction: interaction,
        elapsed: stopwatch.elapsed,
        error: e.toString(),
      );
    }
  }

  /// Execute a tap at coordinates.
  Future<InteractionResult> tap(int x, int y) async {
    return execute(TapInteraction(x: x, y: y));
  }

  /// Input text.
  Future<InteractionResult> inputText(String text) async {
    return execute(TextInputInteraction(text: text));
  }

  /// Send a key event.
  Future<InteractionResult> keyEvent(int keyCode) async {
    return execute(KeyEventInteraction(keyCode: keyCode));
  }

  /// Press the back button.
  Future<InteractionResult> back() async {
    return execute(const KeyEventInteraction.back());
  }

  /// Press the enter key.
  Future<InteractionResult> enter() async {
    return execute(const KeyEventInteraction.enter());
  }

  /// Press the home button.
  Future<InteractionResult> home() async {
    return execute(const KeyEventInteraction.home());
  }

  /// Perform a swipe gesture.
  Future<InteractionResult> swipe({
    required int startX,
    required int startY,
    required int endX,
    required int endY,
    int durationMs = 300,
  }) async {
    return execute(
      SwipeInteraction(
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
        durationMs: durationMs,
      ),
    );
  }

  /// Scroll up on the screen.
  Future<InteractionResult> scrollUp({
    int centerX = 540,
    int startY = 1500,
    int endY = 500,
    int durationMs = 300,
  }) async {
    return swipe(
      startX: centerX,
      startY: startY,
      endX: centerX,
      endY: endY,
      durationMs: durationMs,
    );
  }

  /// Scroll down on the screen.
  Future<InteractionResult> scrollDown({
    int centerX = 540,
    int startY = 500,
    int endY = 1500,
    int durationMs = 300,
  }) async {
    return swipe(
      startX: centerX,
      startY: startY,
      endX: centerX,
      endY: endY,
      durationMs: durationMs,
    );
  }
}

/// Result of an interaction execution.
class InteractionResult {
  InteractionResult({
    required this.success,
    required this.interaction,
    required this.elapsed,
    this.error,
  });

  final bool success;
  final Interaction interaction;
  final Duration elapsed;
  final String? error;

  @override
  String toString() {
    if (success) {
      return 'InteractionResult.success($interaction, ${elapsed.inMilliseconds}ms)';
    }
    return 'InteractionResult.failure($interaction, error: $error)';
  }
}
