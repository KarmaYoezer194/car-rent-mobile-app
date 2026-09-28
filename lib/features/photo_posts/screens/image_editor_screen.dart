import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/image/image_edits.dart';
import '../../../core/image/image_processor.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/image_crop.dart';
import 'post_preview_screen.dart';

enum _EditorTool { rotate, adjust, filters }

enum _Adjustment { brightness, contrast }

/// Full-screen editor shown right after a photo is taken or picked.
///
/// Crop runs through the native cropper (which also handles free rotation
/// and pinch-zoom while cropping) and replaces [_bytes]. Everything else —
/// 90° rotation, brightness, contrast, filters — is kept as [ImageEdits]
/// and only previewed live here; [ImageProcessor] bakes it into the pixels
/// when the user taps Next. That keeps slider drags instant and means
/// going back from the preview screen lands here with every edit intact.
///
/// Pops with `true` once the photo has been posted, or null if the user
/// cancelled.
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({super.key, required this.image, required this.authorId});

  final PickedImage image;
  final String authorId;

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late Uint8List _bytes = widget.image.bytes;
  late String? _path = widget.image.path;
  bool _cropped = false;
  ImageEdits _edits = const ImageEdits();

  _EditorTool _tool = _EditorTool.filters;
  _Adjustment _adjustment = _Adjustment.brightness;
  bool _busy = false;
  final _viewerController = TransformationController();

  bool get _hasChanges => _cropped || !_edits.isIdentity;

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  void _update(ImageEdits edits) => setState(() => _edits = edits);

  Future<void> _crop() async {
    setState(() => _busy = true);
    try {
      var path = _path;
      var turns = _edits.quarterTurns;

      // Bake any pending 90° rotation in first so the cropper shows the
      // photo the same way up as the preview. Web has no temp files to
      // hand the cropper, so there the rotation just stays applied after.
      if (!kIsWeb && (turns != 0 || path == null)) {
        final rotated = turns == 0 ? _bytes : await ImageProcessor.bakeRotation(_bytes, turns);
        final file = io.File('${io.Directory.systemTemp.path}/carrent_edit_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await file.writeAsBytes(rotated, flush: true);
        path = file.path;
        turns = 0;
      }
      if (path == null || !mounted) return;

      final cropped = await cropImageAtPath(
        path,
        filename: widget.image.filename,
        context: context,
        title: 'Crop & Rotate',
        compressQuality: 95,
      );
      if (cropped == null || !mounted) return; // Cancelled — keep everything as it was.

      setState(() {
        _bytes = cropped.bytes;
        _path = cropped.path;
        _cropped = true;
        _edits = _edits.copyWith(quarterTurns: turns);
        _viewerController.value = Matrix4.identity();
      });
    } catch (_) {
      if (mounted) AppSnackbar.show(context, "Couldn't open the crop tool. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    ProcessedImage processed;
    try {
      processed = await ImageProcessor.processForUpload(_bytes, _edits);
    } on ImageProcessingException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message);
      return;
    } catch (_) {
      if (mounted) AppSnackbar.show(context, "Couldn't apply your edits to this photo. Please try again.");
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    final result = await Navigator.of(context).push<PostPreviewResult>(
      MaterialPageRoute(builder: (_) => PostPreviewScreen(image: processed, authorId: widget.authorId)),
    );
    if (!mounted) return;
    // null = the preview's back button: stay here so the user can keep editing.
    if (result == PostPreviewResult.posted) Navigator.of(context).pop(true);
    if (result == PostPreviewResult.cancelled) Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this photo?'),
        content: const Text("Your edits won't be saved."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PopScope(
      canPop: !_hasChanges && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _confirmDiscard();
      },
      child: Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.white, onPrimary: Colors.black, surface: Color(0xFF161616)),
          sliderTheme: const SliderThemeData(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white12,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(LucideIcons.x),
              tooltip: 'Cancel',
              onPressed: _busy ? null : _confirmDiscard,
            ),
            title: const Text('Edit photo'),
            actions: [
              if (!_edits.isIdentity)
                TextButton(
                  onPressed: _busy ? null : () => _update(const ImageEdits()),
                  child: const Text('Reset', style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _viewerController,
                          minScale: 1,
                          maxScale: 5,
                          child: Center(
                            // RotatedBox (not a paint-only Transform) so a
                            // portrait photo turned landscape is re-fitted
                            // to the screen instead of overflowing it.
                            child: RotatedBox(
                              quarterTurns: _edits.quarterTurns,
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(_edits.colorMatrix),
                                child: Image.memory(
                                  _bytes,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  // Decode at ~2x screen width: sharp at
                                  // moderate zoom without holding a full
                                  // 12 MP bitmap in memory.
                                  cacheWidth: (screenWidth * dpr * 2).round(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: IgnorePointer(
                          child: Center(
                            child: Text('Pinch to zoom', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
                          ),
                        ),
                      ),
                      if (_busy)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black54,
                            child: Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 116,
                  child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_tool), child: _buildToolPanel())),
                ),
                _buildToolBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _busy ? null : _confirmDiscard,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: _busy ? null : _next,
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolBar() {
    Widget item(IconData icon, String label, {required bool selected, required VoidCallback? onTap}) {
      final color = selected ? Colors.white : Colors.white54;
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Crop opens the native crop screen directly rather than a panel.
          if (imageCropperSupported) item(LucideIcons.crop, 'Crop', selected: false, onTap: _crop),
          item(LucideIcons.rotateCwSquare, 'Rotate',
              selected: _tool == _EditorTool.rotate, onTap: () => setState(() => _tool = _EditorTool.rotate)),
          item(LucideIcons.slidersHorizontal, 'Adjust',
              selected: _tool == _EditorTool.adjust, onTap: () => setState(() => _tool = _EditorTool.adjust)),
          item(LucideIcons.sparkles, 'Filters',
              selected: _tool == _EditorTool.filters, onTap: () => setState(() => _tool = _EditorTool.filters)),
        ],
      ),
    );
  }

  Widget _buildToolPanel() {
    switch (_tool) {
      case _EditorTool.rotate:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundAction(
              icon: LucideIcons.rotateCcw,
              label: 'Left',
              onTap: () => _update(_edits.copyWith(quarterTurns: _edits.quarterTurns - 1)),
            ),
            const SizedBox(width: 32),
            _RoundAction(
              icon: LucideIcons.rotateCw,
              label: 'Right',
              onTap: () => _update(_edits.copyWith(quarterTurns: _edits.quarterTurns + 1)),
            ),
          ],
        );
      case _EditorTool.adjust:
        final value = _adjustment == _Adjustment.brightness ? _edits.brightness : _edits.contrast;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<_Adjustment>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Adjustment.brightness, icon: Icon(LucideIcons.sun, size: 18), label: Text('Brightness')),
                ButtonSegment(value: _Adjustment.contrast, icon: Icon(LucideIcons.contrast, size: 18), label: Text('Contrast')),
              ],
              selected: {_adjustment},
              onSelectionChanged: (selection) => setState(() => _adjustment = selection.first),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      // ±0.5 is already a strong change; the full ±1 range
                      // mostly just produces blown-out or grey images.
                      min: -0.5,
                      max: 0.5,
                      value: value,
                      onChanged: (v) => _update(_adjustment == _Adjustment.brightness
                          ? _edits.copyWith(brightness: v)
                          : _edits.copyWith(contrast: v)),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(value * 200).round()}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case _EditorTool.filters:
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: ImageFilterPreset.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final preset = ImageFilterPreset.values[index];
            final selected = preset == _edits.filter;
            return GestureDetector(
              onTap: () => _update(_edits.copyWith(filter: preset)),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(preset.matrix),
                        child: RotatedBox(
                          quarterTurns: _edits.quarterTurns,
                          child: Image.memory(_bytes, fit: BoxFit.cover, cacheWidth: 180, gaplessPlayback: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preset.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white12,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(14), child: Icon(icon, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
