import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/image/image_source_picker.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/image_crop.dart';
import '../../../widgets/cached_image.dart';
import '../../../core/widgets/motion/entrance.dart';

/// Step 1 — Photos (Section 9), Obsidian Velocity layout: a large cover
/// ("hero") photo slot, three suggested-angle slots, then any extra photos.
///
/// Slots are positions in the same ordered `images` list the listing
/// stores — position 0 is the cover, 1-3 are the suggested angles, 4+ are
/// extras. The angle labels are suggestions, not enforced: picking photos
/// from any empty slot appends them in order. Each picked image is cropped
/// and uploaded to Cloudinary immediately (so removing one later is just a
/// list edit). Requires at least one image — the cover — before moving on.
class PhotosStep extends StatefulWidget {
  const PhotosStep({
    super.key,
    required this.images,
    required this.ownerId,
    required this.imageUploadService,
    required this.onChanged,
  });

  final List<String> images;
  final String ownerId;
  final ImageUploadService imageUploadService;
  final ValueChanged<List<String>> onChanged;

  @override
  State<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends State<PhotosStep> {
  static const _angles = [
    (icon: Icons.airline_seat_recline_normal_rounded, title: 'Cockpit', hint: 'Steering & Dash'),
    (icon: Icons.directions_car_filled_outlined, title: 'Rear Three-Qtr', hint: 'Exhaust & Trunk'),
    (icon: Icons.tire_repair_rounded, title: 'Wheels & Trim', hint: 'Tires & Calipers'),
  ];

  /// Photos picked but not uploaded yet; they occupy the next empty
  /// positions as spinners.
  int _uploading = 0;

  Future<void> _addPhotos() async {
    final source = await showImageSourceSheet(context, title: 'Add car photos');
    if (source == null || !mounted) return;

    List<XFile> picked;
    if (source == ImageSource.camera) {
      final file = await pickImageFromSource(context, ImageSource.camera);
      picked = file == null ? const [] : [file];
    } else {
      try {
        picked = await ImagePicker().pickMultiImage(maxWidth: 4096, maxHeight: 4096, imageQuality: 90);
      } catch (e) {
        if (mounted) AppSnackbar.show(context, "Couldn't open your photo library.");
        return;
      }
    }
    if (picked.isEmpty) return;

    var images = List<String>.of(widget.images);
    for (final file in picked) {
      setState(() => _uploading++);
      try {
        // Each photo gets its own crop step; cancelling the cropper means
        // "leave this one out", not "upload it uncropped".
        if (!mounted) return;
        final cropped = await cropPickedFile(file, context: context, title: 'Crop Photo');
        if (cropped == null) continue;
        final url = await widget.imageUploadService.uploadImage(
          cropped.bytes,
          filename: cropped.filename,
          folder: 'car_images/${widget.ownerId}',
        );
        images = [...images, url];
        widget.onChanged(images);
      } catch (e) {
        if (mounted) AppSnackbar.show(context, 'One of your photos failed to upload. Try again.');
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  void _removeAt(int index) {
    final images = List<String>.of(widget.images)..removeAt(index);
    widget.onChanged(images);
  }

  /// What occupies [position]: a photo, an in-progress upload, or nothing.
  Widget _slot(int position, {required Widget empty, double radius = AppRadius.lg}) {
    if (position < widget.images.length) {
      return _PhotoTile(url: widget.images[position], radius: radius, onRemove: () => _removeAt(position));
    }
    if (position < widget.images.length + _uploading) return _UploadingTile(radius: radius);
    return empty;
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = widget.images.isNotEmpty;
    final extrasStart = 1 + _angles.length;
    final extrasCount = (widget.images.length + _uploading - extrasStart).clamp(0, 1 << 20);
    final remainingAngles = (_angles.length - (widget.images.length - 1).clamp(0, _angles.length)).clamp(
      0,
      _angles.length,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload vehicle photos', style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "High-resolution shots catch renters' interest quickly and earn their trust. "
            'Include daytime exterior and cockpit views.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Cover photo
          AspectRatio(
            aspectRatio: 16 / 10,
            child: _slot(
              0,
              radius: AppRadius.xl,
              empty: _HeroDropZone(onTap: _addPhotos),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hasCover ? AppColors.success : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Primary Cover Image',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _Tag(
                text: hasCover ? 'Added' : 'Required',
                color: hasCover ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Suggested angles
          Row(
            children: [
              Text('Suggested Angles', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (remainingAngles > 0)
                Text(
                  '$remainingAngles ${remainingAngles == 1 ? 'slot' : 'slots'} recommended',
                  style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < _angles.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.9,
                    child: _slot(
                      1 + i,
                      empty: _AngleSlot(
                        icon: _angles[i].icon,
                        title: _angles[i].title,
                        hint: _angles[i].hint,
                        onTap: _addPhotos,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Anything beyond the cover + three angles.
          if (widget.images.length + _uploading >= extrasStart) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('More photos', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: extrasCount + 1,
              itemBuilder: (context, index) => _slot(extrasStart + index, empty: _AddMoreTile(onTap: _addPhotos)),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // Tip
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
                  child: Icon(LucideIcons.lightbulb, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pro Host Tip', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: AppTextStyles.bodySmall,
                          children: [
                            const TextSpan(text: 'Listings with '),
                            TextSpan(
                              text: '5+ well-lit daytime photos',
                              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(
                              text: ' give renters a clear picture of your car — and fewer surprises at pickup.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _HeroDropZone extends StatelessWidget {
  const _HeroDropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      scale: 0.98,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: DottedBorderBox(
            radius: AppRadius.xl,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(LucideIcons.imagePlus, color: AppColors.textPrimary, size: 26),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Tap to select hero photo',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text('Front three-quarter angles work best', style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.badgeCheck, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            'Recommended 1920 × 1080 · JPG or PNG',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

class _AngleSlot extends StatelessWidget {
  const _AngleSlot({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      scale: 0.95,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.textMuted),
                    const Spacer(),
                    Icon(LucideIcons.imagePlus, size: 16, color: AppColors.accent),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hint,
                  style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMoreTile extends StatelessWidget {
  const _AddMoreTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      scale: 0.95,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: DottedBorderBox(child: Icon(LucideIcons.plus, color: AppColors.accent)),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url, required this.onRemove, required this.radius});

  final String url;
  final VoidCallback onRemove;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedImage(url: url),
          Positioned(
            top: 6,
            right: 6,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.7), shape: BoxShape.circle),
                  child: Icon(LucideIcons.x, color: AppColors.overlayText, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

/// Dashed-border container used for the "add photo" drop zones — [Border]
/// has no built-in dashed style, so this paints one with a [CustomPainter]
/// instead of pulling in a package for a single box.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, this.radius = AppRadius.lg});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: AppColors.border, radius: radius),
      child: Center(child: child),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dashLength = 6.0, gapLength = 5.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashLength), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
