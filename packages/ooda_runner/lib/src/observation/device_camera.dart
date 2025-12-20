import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../adb/adb_client.dart';
import 'image_utils.dart';

/// Captures screenshots from the device via ADB.
///
/// This is the "device camera" in the two-camera observation model.
/// It captures the actual framebuffer, including system UI, keyboard,
/// permission dialogs, and other native overlays.
class DeviceCamera {
  DeviceCamera({required AdbClient adb, required String deviceId})
    : _adb = adb,
      _deviceId = deviceId;

  final AdbClient _adb;
  final String _deviceId;

  /// Capture a screenshot and return raw PNG bytes.
  Future<Uint8List> capture() async {
    return _adb.screenshot(_deviceId);
  }

  /// Capture a screenshot and resize to fit within max dimension.
  ///
  /// This is useful for AI APIs that have image size limits (e.g., Claude's
  /// 2000px limit for multi-image requests).
  Future<Uint8List?> captureResized({
    int maxDimension = ImageUtils.defaultMaxDimension,
  }) async {
    final bytes = await capture();
    return ImageUtils.resizeToFit(bytes, maxDimension: maxDimension);
  }

  /// Capture a screenshot and save to a file.
  Future<File> captureToFile(String path) async {
    final bytes = await capture();
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Capture a screenshot and return as an Image object.
  Future<img.Image?> captureAsImage() async {
    final bytes = await capture();
    return img.decodePng(bytes);
  }

  /// Compare two screenshots for equality.
  ///
  /// Returns true if the images are identical (or nearly identical
  /// within the tolerance threshold).
  static bool areEqual(
    Uint8List image1,
    Uint8List image2, {
    double tolerance = 0.0,
  }) {
    // Quick length check
    if (image1.length != image2.length && tolerance == 0.0) {
      return false;
    }

    // Decode images for pixel comparison
    final img1 = img.decodePng(image1);
    final img2 = img.decodePng(image2);

    if (img1 == null || img2 == null) {
      return false;
    }

    if (img1.width != img2.width || img1.height != img2.height) {
      return false;
    }

    if (tolerance == 0.0) {
      // Exact comparison using raw bytes
      return _bytesEqual(image1, image2);
    }

    // Pixel-by-pixel comparison with tolerance
    int differentPixels = 0;
    final totalPixels = img1.width * img1.height;

    for (int y = 0; y < img1.height; y++) {
      for (int x = 0; x < img1.width; x++) {
        final p1 = img1.getPixel(x, y);
        final p2 = img2.getPixel(x, y);

        if (p1 != p2) {
          differentPixels++;
        }
      }
    }

    final diffRatio = differentPixels / totalPixels;
    return diffRatio <= tolerance;
  }

  /// Compute a hash of an image for quick comparison.
  static int computeHash(Uint8List imageBytes) {
    // Simple hash based on image bytes
    int hash = 0;
    for (int i = 0; i < imageBytes.length; i += 100) {
      hash = (hash * 31 + imageBytes[i]) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Check if two byte arrays are equal.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Detects when the screen has stabilized (stopped changing).
///
/// Uses rapid ADB screenshot sampling to detect visual stability.
class VisualStabilityDetector {
  VisualStabilityDetector({
    required DeviceCamera camera,
    int consecutiveMatches = 3,
    Duration samplingInterval = const Duration(milliseconds: 100),
  }) : _camera = camera,
       _consecutiveMatches = consecutiveMatches,
       _samplingInterval = samplingInterval;

  final DeviceCamera _camera;
  final int _consecutiveMatches;
  final Duration _samplingInterval;

  /// Wait for the screen to become stable.
  ///
  /// Returns the final stable screenshot.
  Future<VisualStabilityResult> waitForStability({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    int matchCount = 0;
    int framesChecked = 0;
    Uint8List? previousImage;
    int? previousHash;

    while (stopwatch.elapsed < timeout) {
      try {
        final currentImage = await _camera.capture();
        final currentHash = DeviceCamera.computeHash(currentImage);
        framesChecked++;

        if (previousHash != null && previousHash == currentHash) {
          // Hashes match - do full comparison to confirm
          if (DeviceCamera.areEqual(previousImage!, currentImage)) {
            matchCount++;
            if (matchCount >= _consecutiveMatches) {
              return VisualStabilityResult(
                stable: true,
                screenshot: currentImage,
                elapsed: stopwatch.elapsed,
                framesChecked: framesChecked,
              );
            }
          } else {
            matchCount = 0;
          }
        } else {
          matchCount = 0;
        }

        previousImage = currentImage;
        previousHash = currentHash;
      } catch (e) {
        // Continue on transient errors
        matchCount = 0;
      }

      await Future<void>.delayed(_samplingInterval);
    }

    // Timeout
    return VisualStabilityResult(
      stable: false,
      screenshot: previousImage,
      elapsed: stopwatch.elapsed,
      framesChecked: framesChecked,
    );
  }
}

/// Result of a visual stability check.
class VisualStabilityResult {
  VisualStabilityResult({
    required this.stable,
    this.screenshot,
    required this.elapsed,
    required this.framesChecked,
  });

  /// Whether the screen became stable.
  final bool stable;

  /// The final screenshot (may be null on early timeout).
  final Uint8List? screenshot;

  /// How long the stability check took.
  final Duration elapsed;

  /// Number of frames checked.
  final int framesChecked;

  @override
  String toString() {
    return 'VisualStabilityResult(stable: $stable, elapsed: $elapsed, frames: $framesChecked)';
  }
}
