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
  const TapInteraction({required this.x, required this.y});

  /// X coordinate of the tap.
  final int x;

  /// Y coordinate of the tap.
  final int y;

  @override
  Map<String, dynamic> toJson() => {'type': 'tap', 'x': x, 'y': y};

  @override
  String toString() => 'TapInteraction(x: $x, y: $y)';
}

/// A text input interaction.
@immutable
class TextInputInteraction extends Interaction {
  const TextInputInteraction({required this.text});

  /// The text to input.
  final String text;

  @override
  Map<String, dynamic> toJson() => {'type': 'text_input', 'text': text};

  @override
  String toString() => 'TextInputInteraction(text: $text)';
}

/// A key event interaction.
@immutable
class KeyEventInteraction extends Interaction {
  const KeyEventInteraction({required this.keyCode});

  /// Create a back key event.
  const KeyEventInteraction.back() : keyCode = keyBack;

  /// Create an enter key event.
  const KeyEventInteraction.enter() : keyCode = keyEnter;

  /// Create a home key event.
  const KeyEventInteraction.home() : keyCode = keyHome;

  /// The Android key code.
  final int keyCode;

  /// Named key constants.
  static const int keyBack = 4;
  static const int keyEnter = 66;
  static const int keyHome = 3;
  static const int keyTab = 61;
  static const int keyEscape = 111;

  @override
  Map<String, dynamic> toJson() => {'type': 'key_event', 'key_code': keyCode};

  @override
  String toString() => 'KeyEventInteraction(keyCode: $keyCode)';
}

/// A swipe/scroll interaction.
@immutable
class SwipeInteraction extends Interaction {
  const SwipeInteraction({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.durationMs = 300,
  });

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
  const WaitInteraction({required this.barrierType, this.timeoutMs});

  /// The type of barrier to wait for.
  final String barrierType;

  /// Optional timeout override in milliseconds.
  final int? timeoutMs;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'wait',
    'barrier': barrierType,
    if (timeoutMs != null) 'timeout_ms': timeoutMs,
  };

  @override
  String toString() => 'WaitInteraction(barrier: $barrierType)';
}

/// A tap interaction targeting a UI element by its semantic ID.
///
/// At execution time, the semantics tree is queried to find the element
/// with the EXACT matching label. The label must be a namespaced semantic ID
/// (contains '.' or starts with 'screen:').
///
/// For visible text matching, use [TapByTextInteraction] instead.
@immutable
class TapByLabelInteraction extends Interaction {
  const TapByLabelInteraction({
    required this.label,
    this.occurrence = 0,
    this.within,
  });

  /// The semantic ID to find and tap (exact match only).
  /// Must be namespaced (contain '.' or start with 'screen:').
  final String label;

  /// Which occurrence to tap if multiple nodes match (0 = first).
  final int occurrence;

  /// Optional semantic ID of a parent node to constrain the search.
  /// The search will only look within the subtree of this node.
  final String? within;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tap_label',
    'label': label,
    if (occurrence != 0) 'occurrence': occurrence,
    if (within != null) 'within': within,
  };

  @override
  String toString() => 'TapByLabelInteraction(label: "$label"'
      '${occurrence != 0 ? ', occurrence: $occurrence' : ''}'
      '${within != null ? ', within: "$within"' : ''})';
}

/// A tap interaction targeting a UI element by its visible text.
///
/// Uses substring/contains matching to find elements. This is useful for
/// tapping buttons or other elements by their displayed text, but is more
/// brittle than semantic ID matching since visible text can change.
///
/// For stable semantic ID matching, use [TapByLabelInteraction] instead.
@immutable
class TapByTextInteraction extends Interaction {
  const TapByTextInteraction({
    required this.text,
    this.occurrence = 0,
    this.within,
  });

  /// The visible text to search for (substring match).
  final String text;

  /// Which occurrence to tap if multiple nodes match (0 = first).
  final int occurrence;

  /// Optional semantic ID of a parent node to constrain the search.
  /// The search will only look within the subtree of this node.
  final String? within;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tap_text',
    'text': text,
    if (occurrence != 0) 'occurrence': occurrence,
    if (within != null) 'within': within,
  };

  @override
  String toString() => 'TapByTextInteraction(text: "$text"'
      '${occurrence != 0 ? ', occurrence: $occurrence' : ''}'
      '${within != null ? ', within: "$within"' : ''})';
}
