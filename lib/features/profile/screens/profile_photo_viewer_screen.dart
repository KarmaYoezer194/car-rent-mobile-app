import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full-screen view of the signed-in user's profile photo, reached by
/// tapping the small avatar on the Profile tab — that avatar is only
/// 68px, too small to actually see the picture. Pinch/double-tap to zoom
/// via [InteractiveViewer]; tap anywhere else (or the close button) to
/// dismiss, mirroring how most apps let you preview an avatar.
class ProfilePhotoViewerScreen extends StatelessWidget {
  const ProfilePhotoViewerScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.name,
  });

  final String imageUrl;
  final Object heroTag;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: heroTag,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(color: Colors.white54),
                        errorWidget: (context, url, error) =>
                            const Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
              ),
            ),
            if (name != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Text(
                  name!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
