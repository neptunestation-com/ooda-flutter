import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Detects overlays by comparing Flutter and device screenshots.
///
/// When native Android UI is visible (keyboard, dialogs, permissions),
/// the Flutter screenshot will differ from the device screenshot.
///
/// Rule: overlay_present = flutter_image != device_image
///
/// By default, excludes top 5% and bottom 12% of the image from comparison
/// to avoid false positives from status bar and navigation bar differences.
class OverlayDetector {
  OverlayDetector({
    this.threshold = 0.01,
    this.minDiffPercentage = 0.05,
    this.excludeTopPercent = 0.05,
    this.excludeBottomPercent = 0.12,
  });

  /// Threshold for considering pixels different (0.0 to 1.0).
  /// 0.0 = must be identical, 1.0 = always consider same
  final double threshold;

  /// Minimum percentage of pixels that must differ to detect overlay.
  final double minDiffPercentage;

  /// Percentage of image height to exclude from top (status bar area).
  /// Default 5% to skip status bar region.
  final double excludeTopPercent;

  /// Percentage of image height to exclude from bottom (nav bar area).
  /// Default 12% to skip navigation bar region.
  final double excludeBottomPercent;

  /// Compare Flutter and device screenshots to detect overlays.
  ///
  /// Returns an [OverlayDetectionResult] with details about the comparison.
  OverlayDetectionResult detect({
    required Uint8List flutterImage,
    required Uint8List deviceImage,
  }) {
    final flutter = img.decodePng(flutterImage);
    final device = img.decodePng(deviceImage);

    if (flutter == null || device == null) {
      return OverlayDetectionResult(
        overlayPresent: true,
        confidence: 0.0,
        diffPercentage: 1.0,
        reason: 'Failed to decode one or both images',
      );
    }

    // Handle different image sizes
    if (flutter.width != device.width || flutter.height != device.height) {
      return OverlayDetectionResult(
        overlayPresent: true,
        confidence: 0.5,
        diffPercentage: 1.0,
        reason:
            'Images have different dimensions: '
            '${flutter.width}x${flutter.height} vs ${device.width}x${device.height}',
      );
    }

    // Compare pixels
    final comparison = _compareImages(flutter, device);

    final overlayPresent = comparison.diffPercentage > minDiffPercentage;

    return OverlayDetectionResult(
      overlayPresent: overlayPresent,
      confidence: overlayPresent
          ? comparison.confidence
          : 1.0 - comparison.confidence,
      diffPercentage: comparison.diffPercentage,
      diffRegions: comparison.diffRegions,
      reason: overlayPresent
          ? 'Detected ${(comparison.diffPercentage * 100).toStringAsFixed(1)}% pixel difference'
          : 'Images are similar within threshold',
    );
  }

  _ImageComparison _compareImages(img.Image flutter, img.Image device) {
    // Calculate exclusion boundaries
    final startY = (flutter.height * excludeTopPercent).round();
    final endY = (flutter.height * (1 - excludeBottomPercent)).round();

    int differentPixels = 0;
    int comparedPixels = 0;

    // Track regions of difference for analysis
    int minDiffX = flutter.width;
    int maxDiffX = 0;
    int minDiffY = flutter.height;
    int maxDiffY = 0;

    for (int y = startY; y < endY; y++) {
      for (int x = 0; x < flutter.width; x++) {
        comparedPixels++;
        final fp = flutter.getPixel(x, y);
        final dp = device.getPixel(x, y);

        if (!_pixelsMatch(fp, dp)) {
          differentPixels++;
          minDiffX = math.min(minDiffX, x);
          maxDiffX = math.max(maxDiffX, x);
          minDiffY = math.min(minDiffY, y);
          maxDiffY = math.max(maxDiffY, y);
        }
      }
    }

    final diffPercentage =
        comparedPixels > 0 ? differentPixels / comparedPixels : 0.0;

    // Calculate confidence based on how concentrated the differences are
    double confidence = 0.0;
    if (differentPixels > 0) {
      final diffWidth = maxDiffX - minDiffX + 1;
      final diffHeight = maxDiffY - minDiffY + 1;
      final diffArea = diffWidth * diffHeight;
      final concentration = differentPixels / diffArea;

      // Higher concentration = more likely to be a real overlay (keyboard, dialog)
      // Lower concentration = more likely to be noise or animation
      confidence = concentration;
    }

    final diffRegions = differentPixels > 0
        ? [
            DiffRegion(
              x: minDiffX,
              y: minDiffY,
              width: maxDiffX - minDiffX + 1,
              height: maxDiffY - minDiffY + 1,
            ),
          ]
        : <DiffRegion>[];

    return _ImageComparison(
      diffPercentage: diffPercentage,
      confidence: confidence,
      diffRegions: diffRegions,
    );
  }

  bool _pixelsMatch(img.Pixel fp, img.Pixel dp) {
    // Compare RGB values with threshold
    final rDiff = (fp.r - dp.r).abs();
    final gDiff = (fp.g - dp.g).abs();
    final bDiff = (fp.b - dp.b).abs();

    final maxDiff = math.max(rDiff, math.max(gDiff, bDiff));
    return maxDiff <= (threshold * 255);
  }

  /// Generate a diff image highlighting differences.
  ///
  /// Colors:
  /// - Red: Pixels that differ (in comparison region)
  /// - Gray (50% opacity): Pixels that match (in comparison region)
  /// - Dark gray (25% opacity): Excluded regions (top/bottom)
  Uint8List? generateDiffImage({
    required Uint8List flutterImage,
    required Uint8List deviceImage,
  }) {
    final flutter = img.decodePng(flutterImage);
    final device = img.decodePng(deviceImage);

    if (flutter == null || device == null) return null;
    if (flutter.width != device.width || flutter.height != device.height) {
      return null;
    }

    // Calculate exclusion boundaries
    final startY = (flutter.height * excludeTopPercent).round();
    final endY = (flutter.height * (1 - excludeBottomPercent)).round();

    final diff = img.Image(width: flutter.width, height: flutter.height);

    for (int y = 0; y < flutter.height; y++) {
      for (int x = 0; x < flutter.width; x++) {
        final dp = device.getPixel(x, y);

        // Check if in excluded region
        if (y < startY || y >= endY) {
          // Excluded region - show dark with low opacity
          final gray = ((dp.r + dp.g + dp.b) ~/ 3).toInt();
          diff.setPixelRgba(x, y, gray ~/ 2, gray ~/ 2, gray ~/ 2, 64);
        } else {
          final fp = flutter.getPixel(x, y);
          if (_pixelsMatch(fp, dp)) {
            // Same - show grayscale version of device image
            final gray = ((dp.r + dp.g + dp.b) ~/ 3).toInt();
            diff.setPixelRgba(x, y, gray, gray, gray, 128);
          } else {
            // Different - highlight in red
            diff.setPixelRgba(x, y, 255, 0, 0, 255);
          }
        }
      }
    }

    return Uint8List.fromList(img.encodePng(diff));
  }
}

/// Result of overlay detection.
class OverlayDetectionResult {
  OverlayDetectionResult({
    required this.overlayPresent,
    required this.confidence,
    required this.diffPercentage,
    this.diffRegions = const [],
    required this.reason,
  });

  /// Whether an overlay was detected.
  final bool overlayPresent;

  /// Confidence level of the detection (0.0 to 1.0).
  final double confidence;

  /// Percentage of pixels that differ.
  final double diffPercentage;

  /// Regions where differences were detected.
  final List<DiffRegion> diffRegions;

  /// Human-readable reason for the result.
  final String reason;

  @override
  String toString() {
    return 'OverlayDetectionResult(overlayPresent: $overlayPresent, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'diffPercentage: ${(diffPercentage * 100).toStringAsFixed(1)}%)';
  }
}

/// A rectangular region where differences were detected.
class DiffRegion {
  DiffRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  @override
  String toString() => 'DiffRegion($x, $y, ${width}x$height)';
}

class _ImageComparison {
  _ImageComparison({
    required this.diffPercentage,
    required this.confidence,
    required this.diffRegions,
  });

  final double diffPercentage;
  final double confidence;
  final List<DiffRegion> diffRegions;
}
