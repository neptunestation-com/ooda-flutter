import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:ooda_runner/src/observation/overlay_detector.dart';
import 'package:test/test.dart';

/// Create a test PNG image with a solid color.
Uint8List createSolidPng(int width, int height, {int color = 0xFFFF0000}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (color >> 16) & 0xFF,
        (color >> 8) & 0xFF,
        color & 0xFF,
        (color >> 24) & 0xFF,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Create a test PNG with a rectangle overlay.
Uint8List createPngWithOverlay(
  int width,
  int height, {
  int bgColor = 0xFFFF0000,
  int overlayColor = 0xFF00FF00,
  int overlayX = 10,
  int overlayY = 10,
  int overlayWidth = 50,
  int overlayHeight = 30,
}) {
  final image = img.Image(width: width, height: height);

  // Fill background
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (bgColor >> 16) & 0xFF,
        (bgColor >> 8) & 0xFF,
        bgColor & 0xFF,
        (bgColor >> 24) & 0xFF,
      );
    }
  }

  // Draw overlay
  for (int y = overlayY; y < overlayY + overlayHeight && y < height; y++) {
    for (int x = overlayX; x < overlayX + overlayWidth && x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (overlayColor >> 16) & 0xFF,
        (overlayColor >> 8) & 0xFF,
        overlayColor & 0xFF,
        (overlayColor >> 24) & 0xFF,
      );
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('OverlayDetector', () {
    late OverlayDetector detector;

    setUp(() {
      detector = OverlayDetector();
    });

    test('detects no overlay for identical images', () {
      final image = createSolidPng(100, 100);

      final result = detector.detect(flutterImage: image, deviceImage: image);

      expect(result.overlayPresent, isFalse);
      expect(result.diffPercentage, equals(0.0));
    });

    test('detects overlay when images differ', () {
      final flutter = createSolidPng(100, 100, color: 0xFFFF0000);
      final device = createPngWithOverlay(
        100,
        100,
        bgColor: 0xFFFF0000,
        overlayColor: 0xFF00FF00,
      );

      final result = detector.detect(
        flutterImage: flutter,
        deviceImage: device,
      );

      expect(result.overlayPresent, isTrue);
      expect(result.diffPercentage, greaterThan(0));
    });

    test('handles different image sizes', () {
      final flutter = createSolidPng(100, 100);
      final device = createSolidPng(200, 200);

      final result = detector.detect(
        flutterImage: flutter,
        deviceImage: device,
      );

      expect(result.overlayPresent, isTrue);
      expect(result.reason, contains('different dimensions'));
    });

    test('handles invalid image data', () {
      final invalid = Uint8List.fromList([1, 2, 3, 4, 5]);
      final valid = createSolidPng(100, 100);

      final result = detector.detect(flutterImage: invalid, deviceImage: valid);

      expect(result.overlayPresent, isTrue);
      expect(result.reason, contains('decode'));
    });

    test('calculates diff percentage correctly', () {
      // 100x100 image with 25% different (25x100 strip)
      final flutter = createSolidPng(100, 100, color: 0xFFFF0000);

      final image = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          if (x < 25) {
            image.setPixelRgba(x, y, 0, 255, 0, 255); // Green
          } else {
            image.setPixelRgba(x, y, 255, 0, 0, 255); // Red
          }
        }
      }
      final device = Uint8List.fromList(img.encodePng(image));

      final result = detector.detect(
        flutterImage: flutter,
        deviceImage: device,
      );

      expect(result.diffPercentage, closeTo(0.25, 0.01));
    });

    test('reports diff regions', () {
      final flutter = createSolidPng(100, 100, color: 0xFFFF0000);
      final device = createPngWithOverlay(
        100,
        100,
        bgColor: 0xFFFF0000,
        overlayColor: 0xFF00FF00,
        overlayX: 20,
        overlayY: 30,
        overlayWidth: 40,
        overlayHeight: 20,
      );

      final result = detector.detect(
        flutterImage: flutter,
        deviceImage: device,
      );

      expect(result.diffRegions, isNotEmpty);
      final region = result.diffRegions.first;
      expect(region.x, equals(20));
      expect(region.y, equals(30));
      expect(region.width, equals(40));
      expect(region.height, equals(20));
    });

    test('respects threshold setting', () {
      final detector = OverlayDetector(threshold: 0.5);

      // Create two images with slight color difference
      final image1 = img.Image(width: 10, height: 10);
      final image2 = img.Image(width: 10, height: 10);

      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          image1.setPixelRgba(x, y, 100, 0, 0, 255);
          image2.setPixelRgba(x, y, 110, 0, 0, 255); // Slight difference
        }
      }

      final png1 = Uint8List.fromList(img.encodePng(image1));
      final png2 = Uint8List.fromList(img.encodePng(image2));

      final result = detector.detect(flutterImage: png1, deviceImage: png2);

      // With 0.5 threshold, slight color difference should be ignored
      expect(result.overlayPresent, isFalse);
    });
  });

  group('OverlayDetectionResult', () {
    test('toString includes relevant info', () {
      final result = OverlayDetectionResult(
        overlayPresent: true,
        confidence: 0.85,
        diffPercentage: 0.15,
        reason: 'Test',
      );

      final str = result.toString();
      expect(str, contains('overlayPresent: true'));
      expect(str, contains('85'));
      expect(str, contains('15'));
    });
  });

  group('DiffRegion', () {
    test('toString formats correctly', () {
      final region = DiffRegion(x: 10, y: 20, width: 100, height: 50);
      expect(region.toString(), 'DiffRegion(10, 20, 100x50)');
    });
  });
}
