/// A simple rectangle class for bounds (avoids dart:ui dependency).
class SemanticsRect {
  const SemanticsRect.fromLTRB(this.left, this.top, this.right, this.bottom);

  /// Empty rectangle.
  static const SemanticsRect zero = SemanticsRect.fromLTRB(0, 0, 0, 0);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  @override
  bool operator ==(Object other) =>
      other is SemanticsRect &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'SemanticsRect.fromLTRB($left, $top, $right, $bottom)';
}

/// A parsed semantics node from Flutter's debug dump.
class SemanticsNode {
  const SemanticsNode({
    required this.id,
    required this.bounds,
    this.label,
    this.value,
    this.actions = const {},
    this.flags = const {},
    this.children = const [],
    this.scale = 1.0,
  });

  /// The node ID (e.g., 22 from "SemanticsNode#22").
  final int id;

  /// The bounding rectangle in logical pixels.
  final SemanticsRect bounds;

  /// The accessibility label (e.g., "Email").
  final String? label;

  /// The current value (e.g., text field content).
  final String? value;

  /// Available actions (e.g., {"tap", "focus"}).
  final Set<String> actions;

  /// Semantic flags (e.g., {"isTextField", "isButton"}).
  final Set<String> flags;

  /// Child nodes.
  final List<SemanticsNode> children;

  /// Scale factor applied to this subtree (from "scaled by Nx").
  final double scale;

  /// Returns the absolute bounds accounting for scale.
  SemanticsRect get absoluteBounds => SemanticsRect.fromLTRB(
        bounds.left * scale,
        bounds.top * scale,
        bounds.right * scale,
        bounds.bottom * scale,
      );

  @override
  String toString() => 'SemanticsNode#$id(label: $label, bounds: $bounds)';
}

/// Parser for Flutter semantics tree text dumps.
///
/// Parses the text format returned by
/// `ext.flutter.debugDumpSemanticsTreeInTraversalOrder`.
class SemanticsParser {
  /// Parse the text dump into a tree of SemanticsNode objects.
  ///
  /// Returns null if the dump is empty or cannot be parsed.
  static SemanticsNode? parse(String dump) {
    if (dump.trim().isEmpty) return null;

    final lines = dump.split('\n');
    if (lines.isEmpty) return null;

    try {
      final (node, _) = _parseNode(lines, 0, 0, 1.0);
      return node;
    } catch (e) {
      return null;
    }
  }

  /// Find all nodes with an exactly matching label.
  static List<SemanticsNode> findByLabel(SemanticsNode root, String label) {
    final results = <SemanticsNode>[];
    _findByLabel(root, label, results, exactMatch: true);
    return results;
  }

  /// Find all nodes whose label contains the search string.
  static List<SemanticsNode> findByLabelContaining(
    SemanticsNode root,
    String searchString,
  ) {
    final results = <SemanticsNode>[];
    _findByLabel(root, searchString, results, exactMatch: false);
    return results;
  }

  /// Find the first node with a matching label.
  static SemanticsNode? findFirstByLabel(SemanticsNode root, String label) {
    final matches = findByLabel(root, label);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Find the first node whose label contains the search string.
  static SemanticsNode? findFirstByLabelContaining(
    SemanticsNode root,
    String searchString,
  ) {
    final matches = findByLabelContaining(root, searchString);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Find all nodes within a subtree rooted at [subtreeRoot].
  /// Uses exact match for label.
  static List<SemanticsNode> findByLabelInSubtree(
    SemanticsNode subtreeRoot,
    String label,
  ) {
    final results = <SemanticsNode>[];
    _findByLabel(subtreeRoot, label, results, exactMatch: true);
    return results;
  }

  /// Find all nodes within a subtree whose label contains the search string.
  static List<SemanticsNode> findByLabelContainingInSubtree(
    SemanticsNode subtreeRoot,
    String searchString,
  ) {
    final results = <SemanticsNode>[];
    _findByLabel(subtreeRoot, searchString, results, exactMatch: false);
    return results;
  }

  /// Find the subtree root node by its exact label.
  /// Returns the first node with an exactly matching label.
  static SemanticsNode? findSubtreeRoot(SemanticsNode root, String label) {
    return findFirstByLabel(root, label);
  }

  static void _findByLabel(
    SemanticsNode node,
    String label,
    List<SemanticsNode> results, {
    required bool exactMatch,
  }) {
    final nodeLabel = node.label;
    if (nodeLabel != null) {
      final matches = exactMatch
          ? nodeLabel == label
          : nodeLabel.contains(label);
      if (matches) {
        results.add(node);
      }
    }
    for (final child in node.children) {
      _findByLabel(child, label, results, exactMatch: exactMatch);
    }
  }

  /// Parse a node and its children starting at the given line index.
  /// Returns the parsed node and the next line index to process.
  static (SemanticsNode?, int) _parseNode(
    List<String> lines,
    int startIndex,
    int parentIndent,
    double inheritedScale,
  ) {
    if (startIndex >= lines.length) return (null, startIndex);

    final headerLine = lines[startIndex];
    final nodeMatch = _nodeHeaderRegex.firstMatch(headerLine);
    if (nodeMatch == null) return (null, startIndex);

    final nodeId = int.parse(nodeMatch.group(1)!);
    final nodeIndent = _getIndentLevel(headerLine);

    // Parse properties until we hit the next node or a child
    int lineIndex = startIndex + 1;
    SemanticsRect? bounds;
    String? label;
    String? value;
    final actions = <String>{};
    final flags = <String>{};
    double scale = inheritedScale;

    while (lineIndex < lines.length) {
      final line = lines[lineIndex];
      final lineIndent = _getIndentLevel(line);
      final content = _stripTreeChars(line);

      // If this is a new node header at the same or lesser indent, stop
      if (_nodeHeaderRegex.hasMatch(content) && lineIndent <= nodeIndent) {
        break;
      }

      // If this is a child node (new node header at greater indent), stop properties
      if (_nodeHeaderRegex.hasMatch(content) && lineIndent > nodeIndent) {
        break;
      }

      // Parse properties
      if (content.startsWith('Rect.fromLTRB') || content.contains('Rect.fromLTRB')) {
        bounds = _parseRect(content);
        // Scale might be on the same line as Rect
        if (content.contains('scaled by')) {
          final scaleMatch = _scaleRegex.firstMatch(content);
          if (scaleMatch != null) {
            scale = double.parse(scaleMatch.group(1)!);
          }
        }
      } else if (content.contains('scaled by')) {
        final scaleMatch = _scaleRegex.firstMatch(content);
        if (scaleMatch != null) {
          scale = double.parse(scaleMatch.group(1)!);
        }
      } else if (content.startsWith('label:')) {
        // Handle multiline labels
        final (parsedLabel, newIndex) = _parseMultilineQuotedValue(
          lines,
          lineIndex,
          content,
          'label:',
        );
        label = parsedLabel;
        lineIndex = newIndex;
        continue; // Skip the lineIndex++ at the end
      } else if (content.startsWith('value:')) {
        // Handle multiline values
        final (parsedValue, newIndex) = _parseMultilineQuotedValue(
          lines,
          lineIndex,
          content,
          'value:',
        );
        value = parsedValue;
        lineIndex = newIndex;
        continue;
      } else if (content.startsWith('actions:')) {
        actions.addAll(_parseCommaSeparated(content, 'actions:'));
      } else if (content.startsWith('flags:')) {
        flags.addAll(_parseCommaSeparated(content, 'flags:'));
      }

      lineIndex++;
    }

    // Parse children
    final children = <SemanticsNode>[];
    while (lineIndex < lines.length) {
      final line = lines[lineIndex];
      final content = _stripTreeChars(line);

      // Check if this is a child node (a node header)
      if (_nodeHeaderRegex.hasMatch(content)) {
        final childIndent = _getIndentLevel(line);

        // If the indent is <= our indent, it's a sibling or ancestor, not a child
        if (childIndent <= nodeIndent) {
          break;
        }

        // Parse the child node
        final (child, nextIndex) = _parseNode(lines, lineIndex, nodeIndent, scale);
        if (child != null) {
          children.add(child);
        }
        lineIndex = nextIndex;
      } else {
        lineIndex++;
      }
    }

    return (
      SemanticsNode(
        id: nodeId,
        bounds: bounds ?? SemanticsRect.zero,
        label: label,
        value: value,
        actions: actions,
        flags: flags,
        children: children,
        scale: scale,
      ),
      lineIndex,
    );
  }

  static final _nodeHeaderRegex = RegExp(r'SemanticsNode#(\d+)');
  static final _rectRegex = RegExp(
    r'Rect\.fromLTRB\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)',
  );
  static final _scaleRegex = RegExp(r'scaled by ([\d.]+)x');

  static int _getIndentLevel(String line) {
    // Count the visual indent level by looking at tree drawing characters
    // and leading spaces
    int indent = 0;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == ' ' || char == '│' || char == '├' || char == '└' || char == '─') {
        indent++;
      } else {
        break;
      }
    }
    return indent;
  }

  static String _stripTreeChars(String line) {
    // Remove tree drawing characters and trim
    return line
        .replaceAll('│', '')
        .replaceAll('├', '')
        .replaceAll('└', '')
        .replaceAll('─', '')
        .trim();
  }

  static SemanticsRect? _parseRect(String content) {
    final match = _rectRegex.firstMatch(content);
    if (match == null) return null;
    return SemanticsRect.fromLTRB(
      double.parse(match.group(1)!),
      double.parse(match.group(2)!),
      double.parse(match.group(3)!),
      double.parse(match.group(4)!),
    );
  }

  /// Parse a potentially multiline quoted value (like label or value).
  /// Returns the parsed string and the new line index.
  static (String?, int) _parseMultilineQuotedValue(
    List<String> lines,
    int startIndex,
    String firstLineContent,
    String prefix,
  ) {
    final afterPrefix = firstLineContent
        .substring(firstLineContent.indexOf(prefix) + prefix.length)
        .trim();

    // If it's a simple single-line value with quotes
    if (afterPrefix.startsWith('"') && afterPrefix.endsWith('"') && afterPrefix.length > 1) {
      return (afterPrefix.substring(1, afterPrefix.length - 1), startIndex + 1);
    }

    // If there's no content after prefix, look for multiline value
    if (afterPrefix.isEmpty) {
      // Look at next lines for the value
      final buffer = StringBuffer();
      int lineIndex = startIndex + 1;
      bool foundStart = false;
      bool foundEnd = false;

      while (lineIndex < lines.length && !foundEnd) {
        final line = _stripTreeChars(lines[lineIndex]);

        // Skip empty lines
        if (line.isEmpty) {
          lineIndex++;
          continue;
        }

        // Check for end of multiline (hitting another property or node)
        if (_isPropertyLine(line) || _nodeHeaderRegex.hasMatch(line)) {
          break;
        }

        // Look for opening quote
        if (!foundStart && line.startsWith('"')) {
          foundStart = true;
          final content = line.substring(1);
          if (content.endsWith('"')) {
            // Single line value
            return (content.substring(0, content.length - 1), lineIndex + 1);
          }
          buffer.write(content);
        } else if (foundStart) {
          // Continue collecting the multiline value
          if (line.endsWith('"')) {
            buffer.write('\n');
            buffer.write(line.substring(0, line.length - 1));
            foundEnd = true;
          } else {
            buffer.write('\n');
            buffer.write(line);
          }
        }
        lineIndex++;
      }

      if (buffer.isNotEmpty) {
        return (buffer.toString(), lineIndex);
      }
      return (null, lineIndex);
    }

    // Single line value starting with quote but not ending
    if (afterPrefix.startsWith('"')) {
      final buffer = StringBuffer(afterPrefix.substring(1));
      int lineIndex = startIndex + 1;

      while (lineIndex < lines.length) {
        final line = _stripTreeChars(lines[lineIndex]);

        if (line.isEmpty) {
          lineIndex++;
          continue;
        }

        if (_isPropertyLine(line) || _nodeHeaderRegex.hasMatch(line)) {
          break;
        }

        if (line.endsWith('"')) {
          buffer.write('\n');
          buffer.write(line.substring(0, line.length - 1));
          return (buffer.toString(), lineIndex + 1);
        } else {
          buffer.write('\n');
          buffer.write(line);
        }
        lineIndex++;
      }
      return (buffer.toString(), lineIndex);
    }

    // No quotes, return as-is
    return (afterPrefix.isEmpty ? null : afterPrefix, startIndex + 1);
  }

  static bool _isPropertyLine(String content) {
    return content.startsWith('label:') ||
        content.startsWith('value:') ||
        content.startsWith('actions:') ||
        content.startsWith('flags:') ||
        content.startsWith('Rect.fromLTRB') ||
        content.startsWith('textDirection:') ||
        content.startsWith('indexInParent:') ||
        content.startsWith('tags:') ||
        content.startsWith('sortKey:') ||
        content.startsWith('scrollChildren:') ||
        content.startsWith('scrollIndex:') ||
        content.startsWith('scrollPosition:') ||
        content.startsWith('scrollExtentMin:') ||
        content.startsWith('scrollExtentMax:');
  }

  static Set<String> _parseCommaSeparated(String content, String prefix) {
    final afterPrefix = content.substring(content.indexOf(prefix) + prefix.length).trim();
    return afterPrefix
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}
