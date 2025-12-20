import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client for communicating with the Dart VM Service.
///
/// Provides access to:
/// - Widget tree inspection
/// - Semantics tree
/// - Flutter screenshots
/// - Service extensions
class VmServiceClient {
  VmServiceClient._(this._service, this._uri);

  final VmService _service;
  final Uri _uri;
  String? _mainIsolateId;

  /// The VM service URI.
  Uri get uri => _uri;

  /// The main isolate ID.
  String? get mainIsolateId => _mainIsolateId;

  /// Connect to the VM service at the given URI.
  static Future<VmServiceClient> connect(Uri wsUri) async {
    final service = await vmServiceConnectUri(wsUri.toString());
    final client = VmServiceClient._(service, wsUri);
    await client._findMainIsolate();
    // Enable inspector for widget tree and screenshot features
    await client.enableInspector();
    return client;
  }

  /// Find and store the main Flutter isolate.
  Future<void> _findMainIsolate() async {
    final vm = await _service.getVM();
    for (final isolate in vm.isolates ?? <IsolateRef>[]) {
      if (isolate.name?.contains('main') == true ||
          isolate.name?.contains('root') == true) {
        _mainIsolateId = isolate.id;
        return;
      }
    }
    // Fallback to first isolate
    if (vm.isolates?.isNotEmpty == true) {
      _mainIsolateId = vm.isolates!.first.id;
    }
  }

  /// Refresh the isolate reference.
  ///
  /// Call this after hot restart to get the new isolate ID.
  /// The old isolate is garbage collected after restart.
  Future<void> refreshIsolate() async {
    _mainIsolateId = null;
    await _findMainIsolate();
    // Re-enable inspector for the new isolate
    await enableInspector();
  }

  /// Wait for Flutter service extensions to be registered.
  ///
  /// After hot restart, Flutter needs time to reinitialize and register
  /// its service extensions. This method polls until key extensions are available.
  Future<bool> waitForExtensions({
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    if (_mainIsolateId == null) {
      return false;
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      try {
        final extensions = await listExtensions();
        // Check for key Flutter extensions
        // Note: screenshot is ext.flutter.inspector.screenshot, not ext.flutter.screenshot
        if (extensions.contains('ext.flutter.inspector.screenshot') &&
            extensions.contains('ext.flutter.inspector.getRootWidgetSummaryTree')) {
          return true;
        }
      } catch (_) {
        // Ignore errors during polling
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  /// Get the root widget tree as JSON.
  ///
  /// Uses the WidgetInspectorService to get the render tree.
  Future<Map<String, dynamic>> getWidgetTree({bool summaryTree = true}) async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    // Ensure widget tree is ready
    if (!await isWidgetTreeReady()) {
      final ready = await waitForWidgetTree(timeout: const Duration(seconds: 5));
      if (!ready) {
        throw VmServiceClientException('Widget tree not ready');
      }
    }

    try {
      // Dispose any existing groups to reset state
      try {
        await _service.callServiceExtension(
          'ext.flutter.inspector.disposeAllGroups',
          isolateId: _mainIsolateId,
        );
      } catch (_) {
        // Ignore errors
      }

      final groupName = 'ooda_tree_${DateTime.now().millisecondsSinceEpoch}';
      final response = await _service.callServiceExtension(
        summaryTree
            ? 'ext.flutter.inspector.getRootWidgetSummaryTree'
            : 'ext.flutter.inspector.getRootWidget',
        isolateId: _mainIsolateId,
        args: {'objectGroup': groupName},  // Flutter uses 'objectGroup', not 'groupName'
      );

      // Clean up
      try {
        await _service.callServiceExtension(
          'ext.flutter.inspector.disposeGroup',
          isolateId: _mainIsolateId,
          args: {'objectGroup': groupName},
        );
      } catch (_) {
        // Ignore cleanup errors
      }

      if (response.json != null) {
        return response.json!;
      }

      throw VmServiceClientException('Empty response from widget tree');
    } catch (e) {
      throw VmServiceClientException('Failed to get widget tree: $e');
    }
  }

  /// Get the semantics tree as a string dump.
  ///
  /// Returns the debug dump of the semantics tree.
  /// Note: This returns a string representation, not structured JSON.
  /// Returns empty string if semantics tree is not available.
  Future<String> getSemanticsTree() async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    try {
      // Try to enable semantics first via evaluate
      // Flutter's semantics tree is lazy and only built when enabled
      try {
        await evaluate('SemanticsBinding.instance.ensureSemantics()');
        // Brief delay for semantics tree to build
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } catch (_) {
        // Semantics may already be enabled or not available - continue anyway
      }

      // Get the semantics tree dump
      final response = await _service.callServiceExtension(
        'ext.flutter.debugDumpSemanticsTreeInTraversalOrder',
        isolateId: _mainIsolateId,
      );

      // The extension returns data in 'data' field, not 'result'
      final data = response.json?['data'];
      if (data is String && data.isNotEmpty) {
        return data;
      }

      // Return empty string instead of throwing - semantics may legitimately be empty
      return '';
    } catch (e) {
      throw VmServiceClientException('Failed to get semantics tree: $e');
    }
  }

  /// Check if the widget tree is ready for inspection.
  Future<bool> isWidgetTreeReady() async {
    if (_mainIsolateId == null) return false;

    try {
      final response = await _service.callServiceExtension(
        'ext.flutter.inspector.isWidgetTreeReady',
        isolateId: _mainIsolateId,
      );
      return response.json?['result'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Wait for the widget tree to be ready.
  Future<bool> waitForWidgetTree({
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (await isWidgetTreeReady()) {
        return true;
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  /// Enable the widget inspector.
  ///
  /// Must be called before using widget tree or screenshot features.
  /// This initializes the inspector's internal selection state.
  Future<void> enableInspector() async {
    if (_mainIsolateId == null) return;

    try {
      // Show the inspector to initialize its internal state
      await _service.callServiceExtension(
        'ext.flutter.inspector.show',
        isolateId: _mainIsolateId,
      );

      // Set up the pub root directories (required for some operations)
      await _service.callServiceExtension(
        'ext.flutter.inspector.setPubRootDirectories',
        isolateId: _mainIsolateId,
        args: {'arg0': <String>[]},
      );

      // Brief delay to allow initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } catch (_) {
      // Ignore errors - inspector may already be enabled
    }
  }

  /// Take a Flutter screenshot.
  ///
  /// Returns the PNG bytes of the screenshot.
  /// This captures the entire Flutter render tree.
  Future<Uint8List> takeScreenshot() async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    try {
      // Ensure widget tree is ready
      if (!await isWidgetTreeReady()) {
        final ready = await waitForWidgetTree(timeout: const Duration(seconds: 5));
        if (!ready) {
          throw VmServiceClientException('Widget tree not ready');
        }
      }

      // Dispose any existing groups to reset state
      try {
        await _service.callServiceExtension(
          'ext.flutter.inspector.disposeAllGroups',
          isolateId: _mainIsolateId,
        );
      } catch (_) {
        // Ignore errors - group might not exist
      }

      // Use a unique group name for each screenshot
      final groupName = 'ooda_screenshot_${DateTime.now().millisecondsSinceEpoch}';

      // Get the root widget to obtain the render object ID
      final rootResponse = await _service.callServiceExtension(
        'ext.flutter.inspector.getRootWidget',
        isolateId: _mainIsolateId,
        args: {'objectGroup': groupName},  // Flutter uses 'objectGroup', not 'groupName'
      );

      // The response contains a 'result' object with the widget tree
      final result = rootResponse.json?['result'] as Map<String, dynamic>?;
      final rootId = result?['valueId'] as String? ?? result?['id'] as String?;
      if (rootId == null) {
        throw VmServiceClientException('Could not get root widget ID');
      }

      // Take screenshot of the root render object
      final response = await _service.callServiceExtension(
        'ext.flutter.inspector.screenshot',
        isolateId: _mainIsolateId,
        args: {
          'id': rootId,
          'width': 1080.0,
          'height': 1920.0,
          'maxPixelRatio': 1.0,
        },
      );

      // Screenshot result can be:
      // - A Map with 'screenshot' key containing base64 string
      // - A String directly containing base64
      final resultValue = response.json?['result'];
      String? screenshot;
      if (resultValue is String) {
        screenshot = resultValue;
      } else if (resultValue is Map<String, dynamic>) {
        screenshot = resultValue['screenshot'] as String?;
      } else {
        screenshot = response.json?['screenshot'] as String?;
      }

      if (screenshot == null || screenshot.isEmpty) {
        throw VmServiceClientException('No screenshot data in response');
      }

      // Clean up the object group
      try {
        await _service.callServiceExtension(
          'ext.flutter.inspector.disposeGroup',
          isolateId: _mainIsolateId,
          args: {'objectGroup': groupName},
        );
      } catch (_) {
        // Ignore cleanup errors
      }

      return base64Decode(screenshot);
    } catch (e) {
      throw VmServiceClientException('Failed to take screenshot: $e');
    }
  }

  /// Evaluate a Dart expression in the main isolate.
  Future<String> evaluate(String expression) async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    try {
      final isolate = await _service.getIsolate(_mainIsolateId!);
      final rootLib = isolate.rootLib;

      if (rootLib == null) {
        throw VmServiceClientException('No root library found');
      }

      final result = await _service.evaluate(
        _mainIsolateId!,
        rootLib.id!,
        expression,
      );

      if (result is InstanceRef) {
        return result.valueAsString ?? result.toString();
      }

      return result.toString();
    } catch (e) {
      throw VmServiceClientException('Failed to evaluate expression: $e');
    }
  }

  /// Call a Flutter service extension.
  Future<Map<String, dynamic>?> callExtension(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    final response = await _service.callServiceExtension(
      method,
      isolateId: _mainIsolateId,
      args: args,
    );

    return response.json;
  }

  /// Enable debug paint mode.
  Future<void> setDebugPaint(bool enabled) async {
    await callExtension(
      'ext.flutter.debugPaint',
      args: {'enabled': enabled.toString()},
    );
  }

  /// Enable performance overlay.
  Future<void> setShowPerformanceOverlay(bool enabled) async {
    await callExtension(
      'ext.flutter.showPerformanceOverlay',
      args: {'enabled': enabled.toString()},
    );
  }

  /// Get the current frame rate.
  Future<double?> getFrameRate() async {
    try {
      final result = await callExtension('ext.flutter.inspector.getFrameRate');
      return result?['fps'] as double?;
    } catch (_) {
      return null;
    }
  }

  /// List available service extensions.
  Future<List<String>> listExtensions() async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    final isolate = await _service.getIsolate(_mainIsolateId!);
    return isolate.extensionRPCs ?? [];
  }

  /// Close the connection.
  Future<void> close() async {
    await _service.dispose();
  }
}

/// Exception thrown when a VM service operation fails.
class VmServiceClientException implements Exception {
  VmServiceClientException(this.message);

  final String message;

  @override
  String toString() => 'VmServiceClientException: $message';
}
