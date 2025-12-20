import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ooda_shared/ooda_shared.dart';
import 'package:path/path.dart' as p;

import 'overlay_detector.dart';

/// A complete observation bundle captured at a checkpoint.
///
/// Schema:
/// ```
/// obs/<scene>/<checkpoint>/
///   device.png          # ADB framebuffer screenshot
///   flutter.png         # Flutter engine screenshot
///   widget_tree.json    # Widget tree from WidgetInspectorService
///   semantics.json      # Semantics tree
///   logs.txt            # Recent logcat + Flutter logs
///   meta.json           # Metadata (timestamps, overlay_present, etc.)
/// ```
class ObservationBundle {
  ObservationBundle({
    required this.sceneName,
    required this.checkpointName,
    this.deviceScreenshot,
    this.flutterScreenshot,
    this.widgetTree,
    this.semanticsTree,
    this.logs = const [],
    required this.metadata,
    this.overlayDetection,
  });

  /// Name of the scene this observation belongs to.
  final String sceneName;

  /// Name of the checkpoint within the scene.
  final String checkpointName;

  /// Device screenshot (ADB framebuffer).
  final Uint8List? deviceScreenshot;

  /// Flutter engine screenshot.
  final Uint8List? flutterScreenshot;

  /// Widget tree as JSON.
  final Map<String, dynamic>? widgetTree;

  /// Semantics tree as JSON.
  final Map<String, dynamic>? semanticsTree;

  /// Log messages captured during observation.
  final List<String> logs;

  /// Metadata about this observation.
  final ObservationMetadata metadata;

  /// Overlay detection result (if both screenshots available).
  final OverlayDetectionResult? overlayDetection;

  /// Whether an overlay (keyboard, dialog, etc.) was detected.
  bool get overlayPresent => overlayDetection?.overlayPresent ?? false;

  /// Whether this bundle has both screenshots.
  bool get hasBothScreenshots =>
      deviceScreenshot != null && flutterScreenshot != null;

  /// Whether this bundle has structural data.
  bool get hasStructuralData => widgetTree != null;

  /// Write this bundle to a directory.
  ///
  /// Creates the directory structure:
  /// ```
  /// <outputDir>/<sceneName>/<checkpointName>/
  ///   device.png
  ///   flutter.png
  ///   widget_tree.json
  ///   semantics.json
  ///   logs.txt
  ///   meta.json
  /// ```
  Future<Directory> write(Directory outputDir) async {
    final bundleDir = Directory(
      p.join(outputDir.path, sceneName, checkpointName),
    );
    await bundleDir.create(recursive: true);

    final futures = <Future<void>>[];

    // Device screenshot
    if (deviceScreenshot != null) {
      futures.add(
        File(
          p.join(bundleDir.path, 'device.png'),
        ).writeAsBytes(deviceScreenshot!),
      );
    }

    // Flutter screenshot
    if (flutterScreenshot != null) {
      futures.add(
        File(
          p.join(bundleDir.path, 'flutter.png'),
        ).writeAsBytes(flutterScreenshot!),
      );
    }

    // Widget tree
    if (widgetTree != null) {
      futures.add(
        File(
          p.join(bundleDir.path, 'widget_tree.json'),
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(widgetTree)),
      );
    }

    // Semantics tree
    if (semanticsTree != null) {
      futures.add(
        File(p.join(bundleDir.path, 'semantics.json')).writeAsString(
          const JsonEncoder.withIndent('  ').convert(semanticsTree),
        ),
      );
    }

    // Logs
    if (logs.isNotEmpty) {
      futures.add(
        File(p.join(bundleDir.path, 'logs.txt')).writeAsString(logs.join('\n')),
      );
    }

    // Metadata
    futures.add(
      File(p.join(bundleDir.path, 'meta.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      ),
    );

    // Diff image (if overlay detected)
    if (overlayDetection?.overlayPresent == true &&
        deviceScreenshot != null &&
        flutterScreenshot != null) {
      final detector = OverlayDetector();
      final diffImage = detector.generateDiffImage(
        flutterImage: flutterScreenshot!,
        deviceImage: deviceScreenshot!,
      );
      if (diffImage != null) {
        futures.add(
          File(p.join(bundleDir.path, 'diff.png')).writeAsBytes(diffImage),
        );
      }
    }

    await Future.wait(futures);
    return bundleDir;
  }

  /// Read a bundle from a directory.
  static Future<ObservationBundle> read(Directory bundleDir) async {
    final metaFile = File(p.join(bundleDir.path, 'meta.json'));
    if (!await metaFile.exists()) {
      throw ObservationBundleException(
        'meta.json not found in ${bundleDir.path}',
      );
    }

    final metaJson = jsonDecode(await metaFile.readAsString());
    final metadata = ObservationMetadata.fromJson(metaJson);

    // Read optional files
    Uint8List? deviceScreenshot;
    Uint8List? flutterScreenshot;
    Map<String, dynamic>? widgetTree;
    Map<String, dynamic>? semanticsTree;
    List<String> logs = [];

    final deviceFile = File(p.join(bundleDir.path, 'device.png'));
    if (await deviceFile.exists()) {
      deviceScreenshot = await deviceFile.readAsBytes();
    }

    final flutterFile = File(p.join(bundleDir.path, 'flutter.png'));
    if (await flutterFile.exists()) {
      flutterScreenshot = await flutterFile.readAsBytes();
    }

    final widgetTreeFile = File(p.join(bundleDir.path, 'widget_tree.json'));
    if (await widgetTreeFile.exists()) {
      widgetTree = jsonDecode(await widgetTreeFile.readAsString());
    }

    final semanticsFile = File(p.join(bundleDir.path, 'semantics.json'));
    if (await semanticsFile.exists()) {
      semanticsTree = jsonDecode(await semanticsFile.readAsString());
    }

    final logsFile = File(p.join(bundleDir.path, 'logs.txt'));
    if (await logsFile.exists()) {
      logs = (await logsFile.readAsString()).split('\n');
    }

    // Re-detect overlay if both screenshots present
    OverlayDetectionResult? overlayDetection;
    if (deviceScreenshot != null && flutterScreenshot != null) {
      final detector = OverlayDetector();
      overlayDetection = detector.detect(
        flutterImage: flutterScreenshot,
        deviceImage: deviceScreenshot,
      );
    }

    return ObservationBundle(
      sceneName: metadata.sceneName,
      checkpointName: metadata.checkpointName,
      deviceScreenshot: deviceScreenshot,
      flutterScreenshot: flutterScreenshot,
      widgetTree: widgetTree,
      semanticsTree: semanticsTree,
      logs: logs,
      metadata: metadata,
      overlayDetection: overlayDetection,
    );
  }

  @override
  String toString() =>
      'ObservationBundle(scene: $sceneName, checkpoint: $checkpointName, overlay: $overlayPresent)';
}

/// Exception thrown when bundle operations fail.
class ObservationBundleException implements Exception {
  ObservationBundleException(this.message);

  final String message;

  @override
  String toString() => 'ObservationBundleException: $message';
}

/// Builder for creating observation bundles.
class ObservationBundleBuilder {
  ObservationBundleBuilder();

  String? _sceneName;
  String? _checkpointName;
  Uint8List? _deviceScreenshot;
  Uint8List? _flutterScreenshot;
  Map<String, dynamic>? _widgetTree;
  Map<String, dynamic>? _semanticsTree;
  final List<String> _logs = [];
  String? _deviceId;
  int? _reloadId;
  String _stabilityStatus = 'unknown';
  String? _description;

  ObservationBundleBuilder scene(String name) {
    _sceneName = name;
    return this;
  }

  ObservationBundleBuilder checkpoint(String name, {String? description}) {
    _checkpointName = name;
    _description = description;
    return this;
  }

  ObservationBundleBuilder deviceScreenshot(Uint8List data) {
    _deviceScreenshot = data;
    return this;
  }

  ObservationBundleBuilder flutterScreenshot(Uint8List data) {
    _flutterScreenshot = data;
    return this;
  }

  ObservationBundleBuilder widgetTree(Map<String, dynamic> tree) {
    _widgetTree = tree;
    return this;
  }

  ObservationBundleBuilder semanticsTree(Map<String, dynamic> tree) {
    _semanticsTree = tree;
    return this;
  }

  ObservationBundleBuilder addLog(String message) {
    _logs.add(message);
    return this;
  }

  ObservationBundleBuilder addLogs(List<String> messages) {
    _logs.addAll(messages);
    return this;
  }

  ObservationBundleBuilder device(String deviceId) {
    _deviceId = deviceId;
    return this;
  }

  ObservationBundleBuilder reload(int reloadId) {
    _reloadId = reloadId;
    return this;
  }

  ObservationBundleBuilder stability(String status) {
    _stabilityStatus = status;
    return this;
  }

  /// Build the observation bundle.
  ObservationBundle build() {
    if (_sceneName == null) {
      throw ObservationBundleException('Scene name is required');
    }
    if (_checkpointName == null) {
      throw ObservationBundleException('Checkpoint name is required');
    }
    if (_deviceId == null) {
      throw ObservationBundleException('Device ID is required');
    }

    // Detect overlay if both screenshots present
    OverlayDetectionResult? overlayDetection;
    if (_deviceScreenshot != null && _flutterScreenshot != null) {
      final detector = OverlayDetector();
      overlayDetection = detector.detect(
        flutterImage: _flutterScreenshot!,
        deviceImage: _deviceScreenshot!,
      );
    }

    final metadata = ObservationMetadata(
      sceneName: _sceneName!,
      checkpointName: _checkpointName!,
      timestamp: DateTime.now(),
      overlayPresent: overlayDetection?.overlayPresent ?? false,
      reloadId: _reloadId,
      deviceId: _deviceId!,
      stabilityStatus: _stabilityStatus,
      description: _description,
    );

    return ObservationBundle(
      sceneName: _sceneName!,
      checkpointName: _checkpointName!,
      deviceScreenshot: _deviceScreenshot,
      flutterScreenshot: _flutterScreenshot,
      widgetTree: _widgetTree,
      semanticsTree: _semanticsTree,
      logs: List.unmodifiable(_logs),
      metadata: metadata,
      overlayDetection: overlayDetection,
    );
  }
}
