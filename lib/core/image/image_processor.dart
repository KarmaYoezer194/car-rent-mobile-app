import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'browser_resize.dart';
import 'image_edits.dart';

/// A ready-to-upload image: edits baked in, resized and JPEG-encoded.
class ProcessedImage {
  const ProcessedImage({required this.bytes, required this.width, required this.height});

  final Uint8List bytes;
  final int width;
  final int height;

  double get aspectRatio => height == 0 ? 1 : width / height;
}

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns editor state into upload-ready bytes. Provider-agnostic on
/// purpose — it knows nothing about Cloudinary/S3/Firebase Storage, only
/// "bytes in, smaller edited bytes out" — so it composes with any
/// [ImageUploadService] implementation.
///
/// All work runs in a background isolate via [compute]: decoding and
/// re-encoding a 12 MP camera photo takes long enough on the main isolate
/// to visibly freeze the UI.
class ImageProcessor {
  ImageProcessor._();

  /// Long-edge cap for uploads. 2048 px is sharper than any phone screen
  /// displays a feed photo at, while bringing a typical 4000x3000 camera
  /// shot from ~4-6 MB down to a few hundred KB.
  static const int maxDimension = 2048;

  /// Visually lossless for photos at feed sizes, noticeably smaller than 95+.
  static const int jpegQuality = 85;

  /// Applies [edits] to [source], downsizes to [maxDimension] and encodes
  /// as JPEG. Throws [ImageProcessingException] if [source] can't be decoded.
  ///
  /// [maxDimension] defaults to [ImageProcessor.maxDimension]; smaller
  /// images (e.g. 1024 for avatars) are fine where the photo is only ever
  /// shown small.
  static Future<ProcessedImage> processForUpload(Uint8List source, ImageEdits edits, {int maxDimension = maxDimension}) async {
    // On web there's no background isolate, so the Dart pipeline below
    // would block the UI — for many seconds once a filter is applied. Let
    // the browser's native decoder/canvas do the work instead, edits
    // included; the Dart pipeline is only the fallback.
    if (kIsWeb) {
      final resized = await resizeJpegInBrowser(
        source,
        maxDimension: maxDimension,
        quality: jpegQuality,
        quarterTurns: edits.quarterTurns,
        colorMatrix: edits.hasColorChanges ? edits.colorMatrix : null,
      );
      if (resized != null) {
        return ProcessedImage(bytes: resized.bytes, width: resized.width, height: resized.height);
      }
    }
    return compute(
      _process,
      _ProcessRequest(source, edits.quarterTurns, edits.colorMatrix, edits.hasColorChanges, maxDimension),
    );
  }

  /// Bakes only the rotation into the pixels (no resize, high quality) —
  /// used right before opening the native cropper, so the cropper shows
  /// the photo the same way up as the editor preview does.
  static Future<Uint8List> bakeRotation(Uint8List source, int quarterTurns) {
    return compute(_rotate, _RotateRequest(source, quarterTurns));
  }
}

class _ProcessRequest {
  const _ProcessRequest(this.bytes, this.quarterTurns, this.matrix, this.applyMatrix, this.maxDimension);

  final Uint8List bytes;
  final int quarterTurns;
  final List<double> matrix;
  final bool applyMatrix;
  final int maxDimension;
}

class _RotateRequest {
  const _RotateRequest(this.bytes, this.quarterTurns);

  final Uint8List bytes;
  final int quarterTurns;
}

img.Image _decode(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Truncated/corrupt files make the decoders throw (e.g. RangeError)
    // rather than return null — same outcome for the user either way.
    decoded = null;
  }
  if (decoded == null) {
    throw const ImageProcessingException("This image couldn't be read — it may be damaged or in an unsupported format. Try a JPEG or PNG photo.");
  }
  // Camera JPEGs often store "rotate me" as an EXIF flag rather than
  // rotated pixels; Flutter's preview honours the flag, so bake it in
  // here or the uploaded result would come out sideways.
  var image = img.bakeOrientation(decoded);
  if (image.format != img.Format.uint8) image = image.convert(format: img.Format.uint8);
  return image;
}

img.Image _applyRotation(img.Image image, int quarterTurns) {
  final turns = quarterTurns % 4;
  return turns == 0 ? image : img.copyRotate(image, angle: turns * 90);
}

Uint8List _rotate(_RotateRequest request) {
  final image = _applyRotation(_decode(request.bytes), request.quarterTurns);
  return img.encodeJpg(image, quality: 95);
}

ProcessedImage _process(_ProcessRequest request) {
  var image = _decode(request.bytes);

  // Resize first: every later step is per-pixel, so it's far cheaper on
  // the downsized image, and nothing is lost since the extra pixels would
  // be thrown away anyway.
  final longEdge = image.width > image.height ? image.width : image.height;
  final cap = request.maxDimension;
  if (longEdge > cap) {
    image = image.width >= image.height
        ? img.copyResize(image, width: cap, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: cap, interpolation: img.Interpolation.average);
  }

  image = _applyRotation(image, request.quarterTurns);

  if (request.applyMatrix) {
    final m = request.matrix;
    for (final p in image) {
      final r = p.r, g = p.g, b = p.b, a = p.a;
      p
        ..r = (m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4]).clamp(0, 255)
        ..g = (m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9]).clamp(0, 255)
        ..b = (m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]).clamp(0, 255);
    }
  }

  // JPEG has no alpha — flatten transparent PNGs onto white rather than
  // letting transparent pixels turn black.
  if (image.hasAlpha) {
    final flattened = img.Image(width: image.width, height: image.height)..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(flattened, image);
  }

  return ProcessedImage(
    bytes: img.encodeJpg(image, quality: ImageProcessor.jpegQuality),
    width: image.width,
    height: image.height,
  );
}
