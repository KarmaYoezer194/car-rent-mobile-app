import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Replacement for image_cropper_for_web's built-in crop dialog, plugged in
/// via `WebUiSettings.customDialogBuilder`.
///
/// The package's own dialog (v7.0.0) wraps its content in `IntrinsicHeight`,
/// but the crop area is an `HtmlElementView` — a platform view, which can't
/// report intrinsic sizes. On current Flutter that makes the dialog fail
/// layout every frame: the barrier dims the screen, nothing paints, and the
/// console floods with "RenderBox was not laid out". This version gives the
/// crop area a fixed [width]x[height] and never asks for intrinsics.
class WebCropDialog extends StatefulWidget {
  const WebCropDialog({
    super.key,
    required this.cropper,
    required this.initCropper,
    required this.crop,
    required this.rotate,
    required this.scale,
    required this.width,
    required this.height,
    required this.title,
  });

  final Widget cropper;
  final void Function() initCropper;
  final Future<String?> Function() crop;
  final void Function(RotationAngle) rotate;
  final void Function(num) scale;
  final double width;
  final double height;
  final String title;

  @override
  State<WebCropDialog> createState() => _WebCropDialogState();
}

class _WebCropDialogState extends State<WebCropDialog> {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    // Must run exactly once — the package asserts if the Cropper.js
    // instance is created twice.
    widget.initCropper();
  }

  Future<void> _doCrop() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final result = await widget.crop();
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _guard(VoidCallback action) {
    // rotate/scale throw if Cropper.js hasn't finished initializing (it's
    // created ~200 ms after the dialog opens) — just ignore early taps.
    try {
      action();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: widget.width + 2 * AppSpacing.lg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: AppTextStyles.h3)),
            ),
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: widget.cropper),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Rotate left',
                    icon: const Icon(LucideIcons.rotateCcw),
                    onPressed: () => _guard(() => widget.rotate(RotationAngle.counterClockwise90)),
                  ),
                  IconButton(
                    tooltip: 'Rotate right',
                    icon: const Icon(LucideIcons.rotateCw),
                    onPressed: () => _guard(() => widget.rotate(RotationAngle.clockwise90)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _processing ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _processing ? null : _doCrop,
                    child: _processing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crop'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
