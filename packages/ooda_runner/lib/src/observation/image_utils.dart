import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utility functions for image processing.
class ImageUtils {
  ImageUtils._();

  /// Default max dimension for Claude API compatibility.
  /// Claude limits images to 2000px on any dimension for multi-image requests.
  static const int defaultMaxDimension = 1568;

  /// Canonical dimensions for screenshot comparison.
  /// Uses 1080x1920 as the standard mobile resolution.
  static const int canonicalWidth = 1080;
  static const int canonicalHeight = 1920;

  /// Canonicalize two images to the same dimensions for comparison.
  ///
  /// Both images are resized to [canonicalWidth] x [canonicalHeight].
  /// This ensures pixel-by-pixel comparison works regardless of source resolution.
  ///
  /// Returns null for either image if it cannot be decoded.
  static ({Uint8List? first, Uint8List? second}) canonicalize(
    Uint8List first,
    Uint8List second,
  ) {
    final firstImage = img.decodePng(first);
    final secondImage = img.decodePng(second);

    if (firstImage == null || secondImage == null) {
      return (first: null, second: null);
    }

    // Check if both are already at canonical size
    final firstIsCanonical = firstImage.width == canonicalWidth &&
        firstImage.height == canonicalHeight;
    final secondIsCanonical = secondImage.width == canonicalWidth &&
        secondImage.height == canonicalHeight;

    if (firstIsCanonical && secondIsCanonical) {
      return (first: first, second: second);
    }

    // Resize to canonical dimensions
    final firstResized = firstIsCanonical
        ? first
        : _resizeToCanonical(firstImage);
    final secondResized = secondIsCanonical
        ? second
        : _resizeToCanonical(secondImage);

    return (first: firstResized, second: secondResized);
  }

  /// Resize an image to canonical dimensions.
  static Uint8List _resizeToCanonical(img.Image image) {
    final resized = img.copyResize(
      image,
      width: canonicalWidth,
      height: canonicalHeight,
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodePng(resized));
  }

  /// Resize an image to fit within the specified max dimension while
  /// preserving aspect ratio.
  ///
  /// Returns the original bytes if the image is already within limits,
  /// or null if the image cannot be decoded.
  static Uint8List? resizeToFit(
    Uint8List imageBytes, {
    int maxDimension = defaultMaxDimension,
  }) {
    final image = img.decodePng(imageBytes);
    if (image == null) return null;

    // Check if resizing is needed
    if (image.width <= maxDimension && image.height <= maxDimension) {
      return imageBytes;
    }

    // Calculate new dimensions preserving aspect ratio
    final aspectRatio = image.width / image.height;
    int newWidth;
    int newHeight;

    if (image.width > image.height) {
      newWidth = maxDimension;
      newHeight = (maxDimension / aspectRatio).round();
    } else {
      newHeight = maxDimension;
      newWidth = (maxDimension * aspectRatio).round();
    }

    // Resize the image
    final resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    // Encode back to PNG
    return Uint8List.fromList(img.encodePng(resized));
  }

  /// Get the dimensions of a PNG image.
  static ({int width, int height})? getDimensions(Uint8List imageBytes) {
    final image = img.decodePng(imageBytes);
    if (image == null) return null;
    return (width: image.width, height: image.height);
  }

  /// Check if an image exceeds the max dimension.
  static bool exceedsMaxDimension(
    Uint8List imageBytes, {
    int maxDimension = defaultMaxDimension,
  }) {
    final dims = getDimensions(imageBytes);
    if (dims == null) return false;
    return dims.width > maxDimension || dims.height > maxDimension;
  }
}
