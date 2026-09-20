import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifmaker/services/gif_encoder_service.dart';
import 'package:image/image.dart' as img;

Uint8List _solidColorPng(int r, int g, int b, {int width = 20, int height = 20}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return img.encodePng(image);
}

void main() {
  group('encodeToGifBytes', () {
    test('throws when fewer than 2 frames are given', () {
      final frames = [_solidColorPng(255, 0, 0)];
      expect(
        () => encodeToGifBytes(GifEncodeRequest(frames: frames, frameDelayMs: 100)),
        throwsA(isA<GifEncodeException>()),
      );
    });

    test('produces a valid animated GIF with the expected frame count and delay', () {
      final frames = [
        _solidColorPng(255, 0, 0),
        _solidColorPng(0, 255, 0),
        _solidColorPng(0, 0, 255),
      ];

      final gifBytes = encodeToGifBytes(GifEncodeRequest(frames: frames, frameDelayMs: 150));

      final header = String.fromCharCodes(gifBytes.take(6));
      expect(header, anyOf('GIF87a', 'GIF89a'));

      final decoded = img.decodeGif(gifBytes);
      expect(decoded, isNotNull);
      expect(decoded!.frames.length, 3);
      // GIF delay is stored in centiseconds (150ms -> 15cs); the decoder
      // reports frameDuration back out in milliseconds (15 * 10 = 150).
      expect(decoded.frames.first.frameDuration, 150);
    });

    test('normalizes every frame to one common canvas size capped by maxDimension', () {
      // First (widescreen) frame defines the target aspect ratio & scale.
      final wideBytes = _solidColorPng(10, 20, 30, width: 1000, height: 500);
      // Second frame has a different size/aspect ratio entirely.
      final tallBytes = _solidColorPng(200, 200, 200, width: 30, height: 90);

      final gifBytes = encodeToGifBytes(
        GifEncodeRequest(
          frames: [wideBytes, tallBytes],
          frameDelayMs: 100,
          maxDimension: 200,
        ),
      );

      final decoded = img.decodeGif(gifBytes)!;
      expect(decoded.frames.length, 2);

      // First frame: long edge (1000) scaled down to fit maxDimension (200).
      expect(decoded.frames[0].width, 200);
      expect(decoded.frames[0].height, 100);

      // Every frame must share the exact same canvas size, or the GIF is
      // corrupted (image's GifEncoder reuses the first frame's dimensions
      // for every subsequent frame's image descriptor).
      expect(decoded.frames[1].width, 200);
      expect(decoded.frames[1].height, 100);
    });

    test('throws a GifEncodeException when a frame cannot be decoded', () {
      final frames = [_solidColorPng(255, 0, 0), Uint8List.fromList([1, 2, 3, 4])];
      expect(
        () => encodeToGifBytes(GifEncodeRequest(frames: frames, frameDelayMs: 100)),
        throwsA(isA<GifEncodeException>()),
      );
    });
  });
}
