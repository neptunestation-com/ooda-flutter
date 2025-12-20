import 'package:meta/meta.dart';

/// Base class for all interaction types.
@immutable
sealed class Interaction {
  const Interaction();

  /// Convert to JSON representation.
  Map<String, dynamic> toJson();
}

/// A tap interaction at specific coordinates.
@immutable
class TapInteraction extends Interaction {
  /// X coordinate of the tap.
  final int x;

  /// Y coordinate of the tap.
  final int y;

  const TapInteraction({required this.x, required this.y});

  @override
  Map<String, dynamic> toJson() => {'type': 'tap', 'x': x, 'y': y};

  @override
  String toString() => 'TapInteraction(x: $x, y: $y)';
}

/// A text input interaction.
@immutable
class TextInputInteraction extends Interaction {
  /// The text to input.
  final String text;

  const TextInputInteraction({required this.text});

  @override
  Map<String, dynamic> toJson() => {'type': 'text_input', 'text': text};

  @override
  String toString() => 'TextInputInteraction(text: $text)';
}

/// A key event interaction.
@immutable
class KeyEventInteraction extends Interaction {
  /// The Android key code.
  final int keyCode;

  /// Named key constants.
  static const int keyBack = 4;
  static const int keyEnter = 66;
  static const int keyHome = 3;
  static const int keyTab = 61;
  static const int keyEscape = 111;

  const KeyEventInteraction({required this.keyCode});

  /// Create a back key event.
  const KeyEventInteraction.back() : keyCode = keyBack;

  /// Create an enter key event.
  const KeyEventInteraction.enter() : keyCode = keyEnter;

  /// Create a home key event.
  const KeyEventInteraction.home() : keyCode = keyHome;

  @override
  Map<String, dynamic> toJson() => {'type': 'key_event', 'key_code': keyCode};

  @override
  String toString() => 'KeyEventInteraction(keyCode: $keyCode)';
}

/// A swipe/scroll interaction.
@immutable
class SwipeInteraction extends Interaction {
  /// Starting X coordinate.
  final int startX;

  /// Starting Y coordinate.
  final int startY;

  /// Ending X coordinate.
  final int endX;

  /// Ending Y coordinate.
  final int endY;

  /// Duration of the swipe in milliseconds.
  final int durationMs;

  const SwipeInteraction({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.durationMs = 300,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'swipe',
        'start_x': startX,
        'start_y': startY,
        'end_x': endX,
        'end_y': endY,
        'duration_ms': durationMs,
      };

  @override
  String toString() =>
      'SwipeInteraction(($startX,$startY) -> ($endX,$endY), ${durationMs}ms)';
}

/// A wait interaction for barriers.
@immutable
class WaitInteraction extends Interaction {
  /// The type of barrier to wait for.
  final String barrierType;

  /// Optional timeout override in milliseconds.
  final int? timeoutMs;

  const WaitInteraction({
    required this.barrierType,
    this.timeoutMs,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'wait',
        'barrier': barrierType,
        if (timeoutMs != null) 'timeout_ms': timeoutMs,
      };

  @override
  String toString() => 'WaitInteraction(barrier: $barrierType)';
}
