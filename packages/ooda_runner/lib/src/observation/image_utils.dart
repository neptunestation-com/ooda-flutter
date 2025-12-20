import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utility functions for image processing.
class ImageUtils {
  ImageUtils._();

  /// Default max dimension for Claude API compatibility.
  /// Claude limits images to 2000px on any dimension for multi-image requests.
  static const int defaultMaxDimension = 1568;

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
