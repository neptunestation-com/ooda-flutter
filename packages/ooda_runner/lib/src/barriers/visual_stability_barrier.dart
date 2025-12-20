import 'dart:async';
import 'dart:typed_data';

import 'package:ooda_shared/ooda_shared.dart';

import '../observation/device_camera.dart';
import 'barrier.dart';

/// Barrier that waits for the screen to become visually stable.
///
/// Uses rapid ADB screenshot sampling to detect when the UI has stopped
/// changing. This is essential for capturing reliable observations.
class VisualStabilityBarrier extends PollingBarrier<VisualStabilityResult> {
  @override
  final String name = 'VisualStability';

  final DeviceCamera _camera;

  /// Number of consecutive identical frames required.
  final int consecutiveMatches;

  /// Captured result after stability achieved.
  VisualStabilityResult? _result;

  /// Previous screenshot for comparison.
  Uint8List? _previousImage;
  int? _previousHash;
  int _matchCount = 0;
  int _framesChecked = 0;
  final Stopwatch _stopwatch = Stopwatch();

  VisualStabilityBarrier({
    required DeviceCamera camera,
    this.consecutiveMatches = 3,
    super.timeout = const Duration(seconds: 5),
    super.pollingInterval = const Duration(milliseconds: 100),
  }) : _camera = camera;

  @override
  Future<bool> check() async {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    try {
      final currentImage = await _camera.capture();
      final currentHash = DeviceCamera.computeHash(currentImage);
      _framesChecked++;

      if (_previousHash != null && _previousHash == currentHash) {
        // Hash matches - do full comparison to confirm
        if (DeviceCamera.areEqual(_previousImage!, currentImage)) {
          _matchCount++;
          if (_matchCount >= consecutiveMatches) {
            _result = VisualStabilityResult(
              stable: true,
              screenshot: currentImage,
              elapsed: _stopwatch.elapsed,
              framesChecked: _framesChecked,
            );
            return true;
          }
        } else {
          _matchCount = 0;
        }
      } else {
        _matchCount = 0;
      }

      _previousImage = currentImage;
      _previousHash = currentHash;
      return false;
    } catch (e) {
      // Continue on transient errors
      _matchCount = 0;
      return false;
    }
  }

  @override
  Future<VisualStabilityResult?> getValue() async => _result;

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('Visual Stability Barrier Timeout Diagnostics');
    buffer.writeln('');
    buffer.writeln('Frames checked: $_framesChecked');
    buffer.writeln('Consecutive matches: $_matchCount / $consecutiveMatches');
    buffer.writeln('Elapsed: ${_stopwatch.elapsed}');
    buffer.writeln('');
    buffer.writeln('Possible causes:');
    buffer.writeln('  - Ongoing animations in the app');
    buffer.writeln('  - Blinking cursor or loading indicators');
    buffer.writeln('  - Background video or live content');
    buffer.writeln('  - Device performance issues');
    buffer.writeln('');
    buffer.writeln('Suggestions:');
    buffer.writeln('  - Increase timeout duration');
    buffer.writeln('  - Reduce consecutiveMatches requirement');
    buffer.writeln('  - Ensure app is in a stable state before observation');

    return buffer.toString();
  }
}

/// Barrier that combines visual stability with both cameras.
///
/// Waits for both Flutter and device screenshots to stabilize,
/// then compares them for overlay detection.
class DualCameraStabilityBarrier extends PollingBarrier<DualCameraStabilityResult> {
  @override
  final String name = 'DualCameraStability';

  final DeviceCamera _deviceCamera;
  final Future<Uint8List> Function() _flutterScreenshot;

  /// Number of consecutive identical frames required.
  final int consecutiveMatches;

  DualCameraStabilityResult? _result;

  Uint8List? _previousDeviceImage;
  Uint8List? _previousFlutterImage;
  int? _previousDeviceHash;
  int? _previousFlutterHash;
  int _matchCount = 0;
  int _framesChecked = 0;
  final Stopwatch _stopwatch = Stopwatch();

  DualCameraStabilityBarrier({
    required DeviceCamera deviceCamera,
    required Future<Uint8List> Function() flutterScreenshot,
    this.consecutiveMatches = 3,
    super.timeout = const Duration(seconds: 5),
    super.pollingInterval = const Duration(milliseconds: 150),
  })  : _deviceCamera = deviceCamera,
        _flutterScreenshot = flutterScreenshot;

  @override
  Future<bool> check() async {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    try {
      // Capture both cameras in parallel
      final results = await Future.wait([
        _deviceCamera.capture(),
        _flutterScreenshot(),
      ]);

      final deviceImage = results[0];
      final flutterImage = results[1];
      final deviceHash = DeviceCamera.computeHash(deviceImage);
      final flutterHash = DeviceCamera.computeHash(flutterImage);
      _framesChecked++;

      // Check if both are stable
      final deviceStable = _previousDeviceHash != null &&
          _previousDeviceHash == deviceHash &&
          DeviceCamera.areEqual(_previousDeviceImage!, deviceImage);

      final flutterStable = _previousFlutterHash != null &&
          _previousFlutterHash == flutterHash &&
          DeviceCamera.areEqual(_previousFlutterImage!, flutterImage);

      if (deviceStable && flutterStable) {
        _matchCount++;
        if (_matchCount >= consecutiveMatches) {
          _result = DualCameraStabilityResult(
            stable: true,
            deviceScreenshot: deviceImage,
            flutterScreenshot: flutterImage,
            elapsed: _stopwatch.elapsed,
            framesChecked: _framesChecked,
          );
          return true;
        }
      } else {
        _matchCount = 0;
      }

      _previousDeviceImage = deviceImage;
      _previousFlutterImage = flutterImage;
      _previousDeviceHash = deviceHash;
      _previousFlutterHash = flutterHash;
      return false;
    } catch (e) {
      _matchCount = 0;
      return false;
    }
  }

  @override
  Future<DualCameraStabilityResult?> getValue() async => _result;

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('Dual Camera Stability Barrier Timeout Diagnostics');
    buffer.writeln('');
    buffer.writeln('Frames checked: $_framesChecked');
    buffer.writeln('Consecutive matches: $_matchCount / $consecutiveMatches');
    buffer.writeln('Elapsed: ${_stopwatch.elapsed}');

    return buffer.toString();
  }
}

/// Result of dual camera stability check.
class DualCameraStabilityResult {
  final bool stable;
  final Uint8List? deviceScreenshot;
  final Uint8List? flutterScreenshot;
  final Duration elapsed;
  final int framesChecked;

  DualCameraStabilityResult({
    required this.stable,
    this.deviceScreenshot,
    this.flutterScreenshot,
    required this.elapsed,
    required this.framesChecked,
  });

  @override
  String toString() =>
      'DualCameraStabilityResult(stable: $stable, elapsed: $elapsed, frames: $framesChecked)';
}
