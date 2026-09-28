/// The non-destructive edit state for one photo in the image editor —
/// everything except crop, which is destructive (the native cropper hands
/// back new pixels) and so lives in the editor's source bytes instead.
///
/// Brightness, contrast and the filter preset all reduce to a single 4x5
/// color matrix ([colorMatrix]). That one matrix is used twice, which is
/// what keeps "what you see" identical to "what gets posted":
/// - live preview: `ColorFilter.matrix(edits.colorMatrix)` on the image
///   widget, so slider drags cost nothing but a repaint;
/// - export: [ImageProcessor] applies the same matrix to every pixel.
class ImageEdits {
  const ImageEdits({
    this.quarterTurns = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.filter = ImageFilterPreset.none,
  });

  /// Clockwise 90° rotations, normalised to 0-3.
  final int quarterTurns;

  /// -1 (black) .. 0 (unchanged) .. 1 (white).
  final double brightness;

  /// -1 (flat grey) .. 0 (unchanged) .. 1 (double contrast).
  final double contrast;

  final ImageFilterPreset filter;

  bool get isIdentity =>
      quarterTurns == 0 && brightness == 0 && contrast == 0 && filter == ImageFilterPreset.none;

  bool get hasColorChanges => brightness != 0 || contrast != 0 || filter != ImageFilterPreset.none;

  ImageEdits copyWith({int? quarterTurns, double? brightness, double? contrast, ImageFilterPreset? filter}) {
    return ImageEdits(
      quarterTurns: (quarterTurns ?? this.quarterTurns) % 4,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      filter: filter ?? this.filter,
    );
  }

  /// Brightness, then contrast, then the filter preset — composed into one
  /// row-major 4x5 matrix in the same format as `ColorFilter.matrix`
  /// (translation column in 0-255 space).
  List<double> get colorMatrix {
    var m = ColorMatrix.identity;
    if (brightness != 0) m = ColorMatrix.multiply(ColorMatrix.brightness(brightness), m);
    if (contrast != 0) m = ColorMatrix.multiply(ColorMatrix.contrast(contrast), m);
    if (filter != ImageFilterPreset.none) m = ColorMatrix.multiply(filter.matrix, m);
    return m;
  }
}

/// Basic one-tap looks for the editor's Filters tab.
enum ImageFilterPreset {
  none('Original'),
  vivid('Vivid'),
  warm('Warm'),
  cool('Cool'),
  mono('Mono'),
  noir('Noir'),
  sepia('Sepia'),
  fade('Fade');

  const ImageFilterPreset(this.label);

  final String label;

  List<double> get matrix {
    switch (this) {
      case ImageFilterPreset.none:
        return ColorMatrix.identity;
      case ImageFilterPreset.vivid:
        return ColorMatrix.saturation(1.45);
      case ImageFilterPreset.warm:
        return ColorMatrix.channelScale(1.08, 1.0, 0.88, offset: [8, 2, -6]);
      case ImageFilterPreset.cool:
        return ColorMatrix.channelScale(0.9, 1.0, 1.1, offset: [-6, 2, 10]);
      case ImageFilterPreset.mono:
        return ColorMatrix.saturation(0);
      case ImageFilterPreset.noir:
        return ColorMatrix.multiply(ColorMatrix.contrast(0.45), ColorMatrix.saturation(0));
      case ImageFilterPreset.sepia:
        return const [
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case ImageFilterPreset.fade:
        // Lifted blacks + slightly desaturated — the classic "faded film".
        return ColorMatrix.multiply(
          ColorMatrix.channelScale(0.82, 0.82, 0.82, offset: [34, 34, 34]),
          ColorMatrix.saturation(0.75),
        );
    }
  }
}

/// Helpers for 4x5 color matrices in `ColorFilter.matrix` layout.
class ColorMatrix {
  ColorMatrix._();

  static const List<double> identity = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double> brightness(double amount) {
    final offset = amount * 255;
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  /// Scales each channel around mid-grey (128).
  static List<double> contrast(double amount) {
    final scale = 1 + amount;
    final offset = 128 * (1 - scale);
    return [
      scale, 0, 0, 0, offset,
      0, scale, 0, 0, offset,
      0, 0, scale, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  /// 0 = greyscale, 1 = unchanged, >1 = more saturated. Rec. 709 luma weights.
  static List<double> saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final inv = 1 - s;
    return [
      lr * inv + s, lg * inv, lb * inv, 0, 0,
      lr * inv, lg * inv + s, lb * inv, 0, 0,
      lr * inv, lg * inv, lb * inv + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> channelScale(double r, double g, double b, {List<double> offset = const [0, 0, 0]}) {
    return [
      r, 0, 0, 0, offset[0],
      0, g, 0, 0, offset[1],
      0, 0, b, 0, offset[2],
      0, 0, 0, 1, 0,
    ];
  }

  /// Returns `a ∘ b` — the matrix that applies [b] first, then [a]. Treats
  /// each 4x5 matrix as a 5x5 affine one with an implicit `[0 0 0 0 1]` row.
  static List<double> multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = col == 4 ? a[row * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }
}
