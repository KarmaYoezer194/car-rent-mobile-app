import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Result of a browser-side resize: JPEG bytes plus final pixel size.
typedef BrowserResizedImage = ({Uint8List bytes, int width, int height});

/// Decodes [source] with the browser's native decoder (which also applies
/// EXIF orientation), draws it onto a canvas capped at [maxDimension] on
/// the long edge, and re-encodes as JPEG at [quality] (0-100).
///
/// Optionally bakes in editor state the same way [ImageProcessor] does:
/// [quarterTurns] clockwise 90° rotations (done by the canvas transform,
/// so free) and a 4x5 [colorMatrix] in `ColorFilter.matrix` layout (one
/// tight loop over the canvas pixels — far cheaper than the pure-Dart
/// decode/encode, which is what froze "Next" in the web editor).
///
/// Transparent areas are flattened onto white, matching [ImageProcessor].
/// Returns null if the browser can't handle the image, so callers can
/// fall back.
Future<BrowserResizedImage?> resizeJpegInBrowser(
  Uint8List source, {
  required int maxDimension,
  required int quality,
  int quarterTurns = 0,
  List<double>? colorMatrix,
}) async {
  try {
    final bitmap = await web.window.createImageBitmap(web.Blob([source.toJS].toJS)).toDart;
    final longEdge = bitmap.width > bitmap.height ? bitmap.width : bitmap.height;
    final scale = longEdge > maxDimension ? maxDimension / longEdge : 1.0;
    final width = (bitmap.width * scale).round().clamp(1, maxDimension);
    final height = (bitmap.height * scale).round().clamp(1, maxDimension);

    final turns = quarterTurns % 4;
    final outWidth = turns.isOdd ? height : width;
    final outHeight = turns.isOdd ? width : height;

    final canvas = web.HTMLCanvasElement()
      ..width = outWidth
      ..height = outHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D
      ..imageSmoothingEnabled = true
      ..imageSmoothingQuality = 'high';
    ctx
      ..translate(outWidth / 2, outHeight / 2)
      ..rotate(turns * math.pi / 2)
      ..drawImage(bitmap, -width / 2, -height / 2, width, height)
      ..setTransform(web.DOMMatrix());
    bitmap.close();

    if (colorMatrix != null) {
      final imageData = ctx.getImageData(0, 0, outWidth, outHeight);
      _applyColorMatrix(imageData.data.toDart, colorMatrix);
      ctx.putImageData(imageData, 0, 0);
    }

    // Flatten onto white underneath whatever was drawn (JPEG has no alpha).
    ctx
      ..globalCompositeOperation = 'destination-over'
      ..fillStyle = 'white'.toJS
      ..fillRect(0, 0, outWidth, outHeight);

    final blobCompleter = Completer<web.Blob?>();
    canvas.toBlob(((web.Blob? blob) => blobCompleter.complete(blob)).toJS, 'image/jpeg', (quality / 100).toJS);
    final blob = await blobCompleter.future;
    if (blob == null) return null;

    final buffer = await blob.arrayBuffer().toDart;
    return (bytes: buffer.toDart.asUint8List(), width: outWidth, height: outHeight);
  } catch (_) {
    return null;
  }
}

/// Same per-pixel math as [ImageProcessor]'s isolate path. RGB only; alpha
/// is left untouched. Writes into a clamped array, so no manual clamping.
void _applyColorMatrix(Uint8ClampedList px, List<double> m) {
  final m0 = m[0], m1 = m[1], m2 = m[2], m3 = m[3], m4 = m[4];
  final m5 = m[5], m6 = m[6], m7 = m[7], m8 = m[8], m9 = m[9];
  final m10 = m[10], m11 = m[11], m12 = m[12], m13 = m[13], m14 = m[14];
  for (var i = 0; i < px.length; i += 4) {
    final r = px[i], g = px[i + 1], b = px[i + 2], a = px[i + 3];
    px[i] = (m0 * r + m1 * g + m2 * b + m3 * a + m4).round();
    px[i + 1] = (m5 * r + m6 * g + m7 * b + m8 * a + m9).round();
    px[i + 2] = (m10 * r + m11 * g + m12 * b + m13 * a + m14).round();
  }
}
