import 'dart:typed_data';

/// Result of a browser-side resize: JPEG bytes plus final pixel size.
typedef BrowserResizedImage = ({Uint8List bytes, int width, int height});

Future<BrowserResizedImage?> resizeJpegInBrowser(
  Uint8List source, {
  required int maxDimension,
  required int quality,
  int quarterTurns = 0,
  List<double>? colorMatrix,
}) async =>
    null;
