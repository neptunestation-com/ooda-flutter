import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../daemon/vm_service_client.dart';

/// Captures screenshots and structural data from the Flutter engine.
///
/// This is the "Flutter camera" in the two-camera observation model.
/// It captures:
/// - Flutter engine screenshots (what Flutter renders)
/// - Widget tree structure
/// - Semantics tree
///
/// Pros: Fast, hot-reload aligned, structural truth
/// Cons: Blind to Android IME, system dialogs, native overlays
class FlutterCamera {
  FlutterCamera({required VmServiceClient vmService}) : _vmService = vmService;

  final VmServiceClient _vmService;

  /// Capture a Flutter screenshot.
  ///
  /// Returns PNG bytes of the Flutter-rendered content.
  Future<Uint8List> captureScreenshot() async {
    return await _vmService.takeScreenshot();
  }

  /// Capture a screenshot and save to a file.
  Future<File> captureScreenshotToFile(String path) async {
    final bytes = await captureScreenshot();
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Get the widget tree as JSON.
  ///
  /// If [summaryTree] is true, returns a condensed tree suitable for
  /// AI analysis. Otherwise returns the full detailed tree.
  Future<Map<String, dynamic>> getWidgetTree({bool summaryTree = true}) async {
    return await _vmService.getWidgetTree(summaryTree: summaryTree);
  }

  /// Get the widget tree as a formatted text string.
  Future<String> getWidgetTreeText({bool summaryTree = true}) async {
    final tree = await getWidgetTree(summaryTree: summaryTree);
    return _formatWidgetTree(tree, 0);
  }

  /// Get the semantics tree as JSON.
  Future<Map<String, dynamic>> getSemanticsTree() async {
    return await _vmService.getSemanticsTree();
  }

  /// Get the semantics tree as a formatted text string.
  Future<String> getSemanticsTreeText() async {
    final tree = await getSemanticsTree();
    return _formatSemanticsTree(tree, 0);
  }

  /// Capture a complete Flutter observation.
  ///
  /// Returns screenshot, widget tree, and semantics tree.
  Future<FlutterObservation> capture({bool includeSemanticsTree = true}) async {
    final results = await Future.wait([
      captureScreenshot(),
      getWidgetTree(),
      if (includeSemanticsTree) getSemanticsTree(),
    ]);

    return FlutterObservation(
      screenshot: results[0] as Uint8List,
      widgetTree: results[1] as Map<String, dynamic>,
      semanticsTree: includeSemanticsTree
          ? results[2] as Map<String, dynamic>
          : null,
    );
  }

  String _formatWidgetTree(Map<String, dynamic> node, int indent) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;

    final description =
        node['description'] ?? node['widgetRuntimeType'] ?? 'Unknown';
    buffer.writeln('$prefix$description');

    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          buffer.write(_formatWidgetTree(child, indent + 1));
        }
      }
    }

    return buffer.toString();
  }

  String _formatSemanticsTree(Map<String, dynamic> node, int indent) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;

    final label = node['label'] ?? '';
    final value = node['value'] ?? '';
    final hint = node['hint'] ?? '';
    final flags = node['flags'] as List<dynamic>? ?? [];
    final actions = node['actions'] as List<dynamic>? ?? [];

    final parts = <String>[];
    if (label.isNotEmpty) parts.add('label: "$label"');
    if (value.isNotEmpty) parts.add('value: "$value"');
    if (hint.isNotEmpty) parts.add('hint: "$hint"');
    if (flags.isNotEmpty) parts.add('flags: $flags');
    if (actions.isNotEmpty) parts.add('actions: $actions');

    if (parts.isNotEmpty) {
      buffer.writeln('$prefix[${parts.join(', ')}]');
    }

    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          buffer.write(_formatSemanticsTree(child, indent + 1));
        }
      }
    }

    return buffer.toString();
  }
}

/// A complete observation from the Flutter camera.
class FlutterObservation {
  FlutterObservation({
    required this.screenshot,
    required this.widgetTree,
    this.semanticsTree,
  });

  /// The Flutter screenshot as PNG bytes.
  final Uint8List screenshot;

  /// The widget tree as JSON.
  final Map<String, dynamic> widgetTree;

  /// The semantics tree as JSON (may be null if not captured).
  final Map<String, dynamic>? semanticsTree;

  /// Get the widget tree as a JSON string.
  String get widgetTreeJson =>
      const JsonEncoder.withIndent('  ').convert(widgetTree);

  /// Get the semantics tree as a JSON string.
  String? get semanticsTreeJson => semanticsTree != null
      ? const JsonEncoder.withIndent('  ').convert(semanticsTree)
      : null;
}
