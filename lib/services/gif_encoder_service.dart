import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Input for [encodeToGifBytes] / [encodeGifIsolateEntry].
///
/// Kept as a single plain data object (no closures, no platform handles) so
/// it can be sent across the isolate boundary by `compute()`.
class GifEncodeRequest {
  const GifEncodeRequest({
    required this.frames,
    required this.frameDelayMs,
    this.maxDimension = 480,
  });

  /// Raw, still-encoded (e.g. JPEG/PNG/HEIC-decodable) image bytes, already
  /// in the order they should appear in the GIF.
  final List<Uint8List> frames;

  /// Delay between frames, in milliseconds. GIF only supports centisecond
  /// (1/100s) precision, so this is rounded to the nearest 10ms.
  final int frameDelayMs;

  /// The GIF's long edge is capped at this size (derived from the first
  /// frame's aspect ratio) to keep encode time and output size reasonable.
  final int maxDimension;
}

class GifEncodeException implements Exception {
  GifEncodeException(this.message);

  final String message;

  @override
  String toString() => 'GifEncodeException: $message';
}

/// Encodes a sequence of images, in the given order, into a single animated
/// GIF. Pure Dart with no Flutter dependency, so it can run inside an
/// isolate via `compute()` and be unit tested directly without a device.
Uint8List encodeToGifBytes(GifEncodeRequest request) {
  if (request.frames.length < 2) {
    throw GifEncodeException('At least 2 photos are required to build a GIF.');
  }

  final decodedFrames = request.frames.map(_decode).toList();

  // image's GifEncoder writes every frame using the first frame's pixel
  // dimensions, so all frames must share one exact canvas size or the
  // output is corrupted. Every frame — including the first — is therefore
  // center-cropped to a common aspect ratio and resized to the same target
  // dimensions ("cover" fit), so mixed-aspect-ratio photos aren't stretched.
  final first = decodedFrames.first;
  final longEdge = first.width >= first.height ? first.width : first.height;
  final scale = longEdge > request.maxDimension ? request.maxDimension / longEdge : 1.0;
  final targetWidth = (first.width * scale).round().clamp(1, request.maxDimension);
  final targetHeight = (first.height * scale).round().clamp(1, request.maxDimension);

  final delayCentiseconds = (request.frameDelayMs / 10).round().clamp(1, 65535);
  final encoder = img.GifEncoder(repeat: 0);

  for (final decoded in decodedFrames) {
    final fitted = _coverFit(decoded, targetWidth, targetHeight);
    encoder.addFrame(fitted, duration: delayCentiseconds);
  }

  final bytes = encoder.finish();
  if (bytes == null) {
    throw GifEncodeException('GIF encoding failed to produce output.');
  }
  return bytes;
}

img.Image _decode(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw GifEncodeException('Could not decode one of the selected photos.');
  }
  return decoded;
}

/// Center-crops [src] to the target aspect ratio, then resizes it to exactly
/// [targetWidth]x[targetHeight] — a "cover" fit, so every returned frame has
/// identical pixel dimensions without stretching the source image.
img.Image _coverFit(img.Image src, int targetWidth, int targetHeight) {
  final targetAspect = targetWidth / targetHeight;
  final srcAspect = src.width / src.height;

  var cropWidth = src.width;
  var cropHeight = src.height;
  if (srcAspect > targetAspect) {
    cropWidth = (src.height * targetAspect).round().clamp(1, src.width);
  } else if (srcAspect < targetAspect) {
    cropHeight = (src.width / targetAspect).round().clamp(1, src.height);
  }

  final cropped = (cropWidth == src.width && cropHeight == src.height)
      ? src
      : img.copyCrop(
          src,
          x: (src.width - cropWidth) ~/ 2,
          y: (src.height - cropHeight) ~/ 2,
          width: cropWidth,
          height: cropHeight,
        );

  return img.copyResize(cropped, width: targetWidth, height: targetHeight);
}

/// Top-level entry point for `compute()`, which requires a top-level or
/// static function reference. Simply forwards to [encodeToGifBytes].
Uint8List encodeGifIsolateEntry(GifEncodeRequest request) => encodeToGifBytes(request);
