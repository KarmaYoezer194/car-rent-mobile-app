import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/motion/shimmer_box.dart';

/// Interactive rotate/pinch-zoom 3D showroom model, shown when a shopper
/// taps "3D Preview" on Car Details.
///
/// This is a real `<model-viewer>` scene (drag to orbit, pinch to zoom,
/// auto-rotating when idle) rather than a spun photo — every listing's own
/// photos still come from its owner's camera, so this uses one shared
/// showroom-quality concept car model to demonstrate the interaction
/// rather than claiming to depict the exact vehicle. `CarConcept.glb` ©
/// 2024 Darmstadt Graphics Group GmbH (model & textures by Eric Chadwick),
/// licensed CC BY 4.0, via the Khronos glTF-Sample-Assets repository.
class Car3dViewer extends StatefulWidget {
  const Car3dViewer({super.key, this.height = 260});

  final double height;

  static const _modelUrl =
      'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CarConcept/glTF-Binary/CarConcept.glb';

  /// model_viewer_plus embeds a WebView, which only ships an Android/iOS/
  /// web implementation — on any other platform (or in an environment
  /// where the WebView plugin isn't registered) this degrades to a static
  /// placeholder instead of crashing.
  static bool get isSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  State<Car3dViewer> createState() => _Car3dViewerState();
}

class _Car3dViewerState extends State<Car3dViewer> {
  // The model is a multi-MB download the first time it's fetched, so
  // there's a real gap between "WebView created" and "car visible" — this
  // tracks it so the loading shimmer stays up for exactly that gap instead
  // of guessing a fixed duration. Flipped by a JS `load` listener injected
  // via `relatedJs`, with a generous failsafe timer in case that event
  // never arrives (a flaky connection, a blocked host) so the shimmer
  // doesn't sit there forever misrepresenting what's happening.
  bool _loaded = false;
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    _failsafe = Timer(const Duration(seconds: 25), () {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Car3dViewer.isSupported) {
      return _Unsupported(height: widget.height);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            ModelViewer(
              src: Car3dViewer._modelUrl,
              alt: 'Interactive 3D showroom car model',
              autoRotate: true,
              autoRotateDelay: 800,
              rotationPerSecond: '18deg',
              cameraControls: true,
              disableZoom: false,
              backgroundColor: AppColors.surfaceMuted,
              loading: Loading.eager,
              relatedJs: '''
                document.querySelector('model-viewer').addEventListener('load', () => {
                  ModelLoaded.postMessage('loaded');
                });
              ''',
              javascriptChannels: {
                JavascriptChannel('ModelLoaded', onMessageReceived: (message) {
                  if (mounted) setState(() => _loaded = true);
                }),
              },
            ),
            if (!_loaded)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: ShimmerBox(radius: 0)),
                        Positioned.fill(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.box, color: AppColors.textMuted, size: 32),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Loading 3D model…', style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_loaded)
              Positioned(
                left: AppSpacing.md,
                bottom: AppSpacing.md,
                child: _Hint(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.rotate3d, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text('Drag to rotate', style: AppTextStyles.caption.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.box, color: AppColors.textMuted, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text('3D preview isn\'t available on this device', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
