import 'package:car_rent/core/image/image_edits.dart';
import 'package:car_rent/core/image/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

img.Image _solid(int width, int height, int r, int g, int b) =>
    img.Image(width: width, height: height)..clear(img.ColorRgb8(r, g, b));

void main() {
  group('ImageEdits.colorMatrix', () {
    test('no edits is the identity matrix', () {
      expect(const ImageEdits().colorMatrix, ColorMatrix.identity);
    });

    test('brightness offsets every color channel', () {
      final m = const ImageEdits(brightness: 0.2).colorMatrix;
      expect(m[4], closeTo(51, 0.001));
      expect(m[9], closeTo(51, 0.001));
      expect(m[14], closeTo(51, 0.001));
      expect(m[19], 0);
    });

    test('mono filter maps grey to itself', () {
      final m = ImageFilterPreset.mono.matrix;
      final out = m[0] * 100 + m[1] * 100 + m[2] * 100 + m[4];
      expect(out, closeTo(100, 0.01));
    });

    test('quarterTurns wraps to 0-3', () {
      expect(const ImageEdits().copyWith(quarterTurns: -1).quarterTurns, 3);
      expect(const ImageEdits().copyWith(quarterTurns: 5).quarterTurns, 1);
    });
  });

  group('ImageProcessor.processForUpload', () {
    test('downsizes large images to the max dimension, keeping aspect ratio', () async {
      final source = img.encodePng(_solid(3000, 1500, 10, 20, 30));
      final result = await ImageProcessor.processForUpload(source, const ImageEdits());
      expect(result.width, ImageProcessor.maxDimension);
      expect(result.height, ImageProcessor.maxDimension ~/ 2);
    });

    test('rotation swaps width and height', () async {
      final source = img.encodePng(_solid(400, 200, 10, 20, 30));
      final result = await ImageProcessor.processForUpload(source, const ImageEdits(quarterTurns: 1));
      expect((result.width, result.height), (200, 400));
    });

    test('bakes the color matrix into the pixels', () async {
      final source = img.encodePng(_solid(16, 16, 100, 100, 100));
      final result = await ImageProcessor.processForUpload(source, const ImageEdits(brightness: 0.2));
      final pixel = img.decodeJpg(result.bytes)!.getPixel(8, 8);
      // 100 + 0.2 * 255 = 151, give or take JPEG rounding.
      expect(pixel.r, closeTo(151, 3));
    });

    test('rejects bytes that are not an image', () async {
      expect(
        ImageProcessor.processForUpload(img.encodePng(_solid(1, 1, 0, 0, 0)).sublist(0, 8), const ImageEdits()),
        throwsA(isA<ImageProcessingException>()),
      );
    });
  });
}
