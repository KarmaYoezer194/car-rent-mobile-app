import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// A user's profile photo, with their initials as the fallback — used for
/// every avatar that shows *someone* (home header, car owner, renter,
/// reviewer, post author) so they all behave the same way.
///
/// Initials show only while the photo loads, if it fails, or for users who
/// never set one. Loads through [CachedNetworkImageProvider] with no
/// decode-time resize (`memCacheWidth`): on web that resize path made the
/// home header avatar fall back to initials even for users with a photo,
/// while the Profile screen (no resize) showed it fine.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 44,
    this.borderRadius,
  });

  final String name;
  final String? photoUrl;
  final double size;

  /// Rounded-square corner radius; null makes a circle.
  final double? borderRadius;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final initials = Center(
      child: Text(
        initialsOf(name),
        style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontSize: size * 0.34),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Fixed dark ink in both themes, so the white initials always read.
        color: AppColors.navy,
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius == null ? null : BorderRadius.circular(borderRadius!),
      ),
      child: url == null || url.isEmpty
          ? initials
          : Image(
              image: CachedNetworkImageProvider(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  frame == null && !wasSynchronouslyLoaded ? initials : child,
              errorBuilder: (context, error, stackTrace) => initials,
            ),
    );
  }
}
