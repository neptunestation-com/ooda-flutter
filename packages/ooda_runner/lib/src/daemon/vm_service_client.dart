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
  final VmService _service;
  final Uri _uri;
  String? _mainIsolateId;

  VmServiceClient._(this._service, this._uri);

  /// The VM service URI.
  Uri get uri => _uri;

  /// The main isolate ID.
  String? get mainIsolateId => _mainIsolateId;

  /// Connect to the VM service at the given URI.
  static Future<VmServiceClient> connect(Uri wsUri) async {
    final service = await vmServiceConnectUri(wsUri.toString());
    final client = VmServiceClient._(service, wsUri);
    await client._findMainIsolate();
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

  /// Get the root widget tree as JSON.
  ///
  /// Uses the WidgetInspectorService to get the render tree.
  Future<Map<String, dynamic>> getWidgetTree({
    bool summaryTree = true,
  }) async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    try {
      final response = await _service.callServiceExtension(
        summaryTree
            ? 'ext.flutter.inspector.getRootWidgetSummaryTree'
            : 'ext.flutter.inspector.getRootWidget',
        isolateId: _mainIsolateId,
        args: {
          'groupName': 'ooda_runner',
        },
      );

      if (response.json != null) {
        return response.json!;
      }

      throw VmServiceClientException('Empty response from widget tree');
    } catch (e) {
      throw VmServiceClientException('Failed to get widget tree: $e');
    }
  }

  /// Get the semantics tree as JSON.
  Future<Map<String, dynamic>> getSemanticsTree() async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    try {
      // First check if semantics is enabled
      final semanticsEnabled = await _service.callServiceExtension(
        'ext.flutter.debugSemantics',
        isolateId: _mainIsolateId,
        args: {'enabled': 'true'},
      );

      // Get the semantics tree
      final response = await _service.callServiceExtension(
        'ext.flutter.inspector.getSemanticsTree',
        isolateId: _mainIsolateId,
        args: {
          'groupName': 'ooda_runner',
        },
      );

      if (response.json != null) {
        return response.json!;
      }

      throw VmServiceClientException('Empty response from semantics tree');
    } catch (e) {
      throw VmServiceClientException('Failed to get semantics tree: $e');
    }
  }

  /// Take a Flutter screenshot.
  ///
  /// Returns the PNG bytes of the screenshot.
  Future<Uint8List> takeScreenshot() async {
    if (_mainIsolateId == null) {
      throw VmServiceClientException('No isolate available');
    }

    try {
      final response = await _service.callServiceExtension(
        'ext.flutter.screenshot',
        isolateId: _mainIsolateId,
      );

      final screenshot = response.json?['screenshot'] as String?;
      if (screenshot == null) {
        throw VmServiceClientException('No screenshot data in response');
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
  final String message;

  VmServiceClientException(this.message);

  @override
  String toString() => 'VmServiceClientException: $message';
}
