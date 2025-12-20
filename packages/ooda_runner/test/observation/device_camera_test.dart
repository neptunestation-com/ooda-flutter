import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:ooda_runner/src/observation/device_camera.dart';
import 'package:test/test.dart';

/// Create a simple test PNG image.
Uint8List createTestPng(int width, int height, {int color = 0xFFFF0000}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgba(x, y, (color >> 16) & 0xFF, (color >> 8) & 0xFF,
          color & 0xFF, (color >> 24) & 0xFF);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('DeviceCamera', () {
    group('areEqual', () {
      test('returns true for identical PNG images', () {
        final image1 = createTestPng(10, 10, color: 0xFFFF0000);
        final image2 = createTestPng(10, 10, color: 0xFFFF0000);

        expect(DeviceCamera.areEqual(image1, image2), isTrue);
      });

      test('returns false for different size images', () {
        final image1 = createTestPng(10, 10);
        final image2 = createTestPng(20, 20);

        expect(DeviceCamera.areEqual(image1, image2), isFalse);
      });

      test('returns false for different color images', () {
        final image1 = createTestPng(10, 10, color: 0xFFFF0000);
        final image2 = createTestPng(10, 10, color: 0xFF00FF00);

        expect(DeviceCamera.areEqual(image1, image2), isFalse);
      });

      test('returns false for invalid PNG data', () {
        final invalidPng = Uint8List.fromList([1, 2, 3, 4, 5]);
        final validPng = createTestPng(10, 10);

        expect(DeviceCamera.areEqual(invalidPng, validPng), isFalse);
      });
    });

    group('computeHash', () {
      test('returns same hash for identical images', () {
        final image1 = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        final image2 = Uint8List.fromList(List.generate(1000, (i) => i % 256));

        expect(
          DeviceCamera.computeHash(image1),
          equals(DeviceCamera.computeHash(image2)),
        );
      });

      test('returns different hash for different images', () {
        final image1 = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        final image2 =
            Uint8List.fromList(List.generate(1000, (i) => (i + 1) % 256));

        expect(
          DeviceCamera.computeHash(image1),
          isNot(equals(DeviceCamera.computeHash(image2))),
        );
      });

      test('handles empty image', () {
        final empty = Uint8List(0);
        expect(() => DeviceCamera.computeHash(empty), returnsNormally);
      });
    });
  });

  group('VisualStabilityResult', () {
    test('creates stable result', () {
      final screenshot = Uint8List.fromList([1, 2, 3]);
      final result = VisualStabilityResult(
        stable: true,
        screenshot: screenshot,
        elapsed: const Duration(milliseconds: 500),
        framesChecked: 5,
      );

      expect(result.stable, isTrue);
      expect(result.screenshot, screenshot);
      expect(result.elapsed, const Duration(milliseconds: 500));
      expect(result.framesChecked, 5);
    });

    test('creates unstable result', () {
      final result = VisualStabilityResult(
        stable: false,
        screenshot: null,
        elapsed: const Duration(seconds: 5),
        framesChecked: 50,
      );

      expect(result.stable, isFalse);
      expect(result.screenshot, isNull);
    });

    test('toString includes relevant info', () {
      final result = VisualStabilityResult(
        stable: true,
        elapsed: const Duration(milliseconds: 300),
        framesChecked: 3,
      );

      final str = result.toString();
      expect(str, contains('stable: true'));
      expect(str, contains('frames: 3'));
    });
  });
}
