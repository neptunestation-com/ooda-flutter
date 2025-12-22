import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:ooda_runner/src/observation/image_utils.dart';
import 'package:test/test.dart';

void main() {
  group('ImageUtils.canonicalize', () {
    Uint8List createTestImage(int width, int height, {int color = 0xFF0000FF}) {
      final image = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          image.setPixelRgba(
            x,
            y,
            (color >> 24) & 0xFF,
            (color >> 16) & 0xFF,
            (color >> 8) & 0xFF,
            color & 0xFF,
          );
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    }

    test('returns original images when both are already canonical size', () {
      final first = createTestImage(
        ImageUtils.canonicalWidth,
        ImageUtils.canonicalHeight,
      );
      final second = createTestImage(
        ImageUtils.canonicalWidth,
        ImageUtils.canonicalHeight,
        color: 0x00FF00FF,
      );

      final result = ImageUtils.canonicalize(first, second);

      expect(result.first, equals(first));
      expect(result.second, equals(second));
    });

    test('resizes non-canonical images to canonical size', () {
      // Create images at different sizes
      final first = createTestImage(540, 960); // Half size
      final second = createTestImage(1440, 2560); // Larger size

      final result = ImageUtils.canonicalize(first, second);

      expect(result.first, isNotNull);
      expect(result.second, isNotNull);

      // Verify dimensions of resized images
      final firstDims = ImageUtils.getDimensions(result.first!);
      final secondDims = ImageUtils.getDimensions(result.second!);

      expect(firstDims?.width, equals(ImageUtils.canonicalWidth));
      expect(firstDims?.height, equals(ImageUtils.canonicalHeight));
      expect(secondDims?.width, equals(ImageUtils.canonicalWidth));
      expect(secondDims?.height, equals(ImageUtils.canonicalHeight));
    });

    test('resizes only non-canonical image when one is already canonical', () {
      final canonical = createTestImage(
        ImageUtils.canonicalWidth,
        ImageUtils.canonicalHeight,
      );
      final nonCanonical = createTestImage(720, 1280);

      final result = ImageUtils.canonicalize(canonical, nonCanonical);

      // First should be unchanged (same reference)
      expect(result.first, equals(canonical));

      // Second should be resized
      expect(result.second, isNotNull);
      final secondDims = ImageUtils.getDimensions(result.second!);
      expect(secondDims?.width, equals(ImageUtils.canonicalWidth));
      expect(secondDims?.height, equals(ImageUtils.canonicalHeight));
    });

    test('returns nulls when first image cannot be decoded', () {
      final invalidFirst = Uint8List.fromList([0, 1, 2, 3]);
      final validSecond = createTestImage(100, 100);

      final result = ImageUtils.canonicalize(invalidFirst, validSecond);

      expect(result.first, isNull);
      expect(result.second, isNull);
    });

    test('returns nulls when second image cannot be decoded', () {
      final validFirst = createTestImage(100, 100);
      final invalidSecond = Uint8List.fromList([0, 1, 2, 3]);

      final result = ImageUtils.canonicalize(validFirst, invalidSecond);

      expect(result.first, isNull);
      expect(result.second, isNull);
    });

    test('returns nulls when both images cannot be decoded', () {
      final invalidFirst = Uint8List.fromList([0, 1, 2, 3]);
      final invalidSecond = Uint8List.fromList([4, 5, 6, 7]);

      final result = ImageUtils.canonicalize(invalidFirst, invalidSecond);

      expect(result.first, isNull);
      expect(result.second, isNull);
    });
  });

  group('ImageUtils.resizeToFit', () {
    Uint8List createTestImage(int width, int height) {
      final image = img.Image(width: width, height: height);
      return Uint8List.fromList(img.encodePng(image));
    }

    test('returns original when already within max dimension', () {
      final small = createTestImage(100, 100);

      final result = ImageUtils.resizeToFit(small, maxDimension: 200);

      expect(result, equals(small));
    });

    test('resizes wide image to fit max dimension', () {
      final wide = createTestImage(2000, 1000);

      final result = ImageUtils.resizeToFit(wide, maxDimension: 1000);

      expect(result, isNotNull);
      final dims = ImageUtils.getDimensions(result!);
      expect(dims?.width, equals(1000));
      expect(dims?.height, equals(500)); // Preserves aspect ratio
    });

    test('resizes tall image to fit max dimension', () {
      final tall = createTestImage(1000, 2000);

      final result = ImageUtils.resizeToFit(tall, maxDimension: 1000);

      expect(result, isNotNull);
      final dims = ImageUtils.getDimensions(result!);
      expect(dims?.width, equals(500)); // Preserves aspect ratio
      expect(dims?.height, equals(1000));
    });

    test('returns null for invalid image data', () {
      final invalid = Uint8List.fromList([0, 1, 2, 3]);

      final result = ImageUtils.resizeToFit(invalid);

      expect(result, isNull);
    });
  });

  group('ImageUtils.getDimensions', () {
    test('returns correct dimensions for valid image', () {
      final image = img.Image(width: 123, height: 456);
      final bytes = Uint8List.fromList(img.encodePng(image));

      final dims = ImageUtils.getDimensions(bytes);

      expect(dims?.width, equals(123));
      expect(dims?.height, equals(456));
    });

    test('returns null for invalid image data', () {
      final invalid = Uint8List.fromList([0, 1, 2, 3]);

      final dims = ImageUtils.getDimensions(invalid);

      expect(dims, isNull);
    });
  });

  group('ImageUtils.exceedsMaxDimension', () {
    test('returns false when within limits', () {
      final image = img.Image(width: 100, height: 100);
      final bytes = Uint8List.fromList(img.encodePng(image));

      final exceeds = ImageUtils.exceedsMaxDimension(bytes, maxDimension: 200);

      expect(exceeds, isFalse);
    });

    test('returns true when width exceeds limit', () {
      final image = img.Image(width: 300, height: 100);
      final bytes = Uint8List.fromList(img.encodePng(image));

      final exceeds = ImageUtils.exceedsMaxDimension(bytes, maxDimension: 200);

      expect(exceeds, isTrue);
    });

    test('returns true when height exceeds limit', () {
      final image = img.Image(width: 100, height: 300);
      final bytes = Uint8List.fromList(img.encodePng(image));

      final exceeds = ImageUtils.exceedsMaxDimension(bytes, maxDimension: 200);

      expect(exceeds, isTrue);
    });

    test('returns false for invalid image data', () {
      final invalid = Uint8List.fromList([0, 1, 2, 3]);

      final exceeds = ImageUtils.exceedsMaxDimension(invalid);

      expect(exceeds, isFalse);
    });
  });
}
