import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/widgets/motion/shimmer_box.dart';

/// Standard image tile used everywhere a car/user photo is shown — car
/// cards, carousels, avatars in list rows. Consolidates what used to be
/// slightly-different ad hoc `Image.network` + placeholder/error blocks
/// duplicated across several screens, and adds disk caching for free via
/// `cached_network_image` (Phase 10) so scrolling back to an already-seen
/// image doesn't refetch it.
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.icon = LucideIcons.car,
    this.iconSize = 32,
  });

  final String url;
  final BoxFit fit;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return ColoredBox(
        color: AppColors.surfaceMuted,
        child: Icon(icon, color: AppColors.textMuted, size: iconSize),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 280),
      fadeInCurve: Curves.easeOut,
      placeholder: (context, url) => const ShimmerBox(radius: 0),
      errorWidget: (context, url, error) => ColoredBox(
        color: AppColors.surfaceMuted,
        child: Icon(LucideIcons.imageOff, color: AppColors.textMuted, size: iconSize),
      ),
    );
  }
}
