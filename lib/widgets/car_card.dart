import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/motion/entrance.dart';
import '../core/widgets/motion/tilt_card.dart';
import '../models/car_model.dart';
import 'cached_image.dart';

/// The card shown for every car across Home, Favorites, and My Cars —
/// Obsidian Velocity style: a photo with an uppercase type badge and a
/// floating heart, then the name, rating and area, and the price balanced
/// against an amber "open" arrow.
class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final CarModel car;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  /// The neighbourhood part of a full address ("Bangsue, Bangkok 10800" →
  /// "Bangsue") — the whole address doesn't fit a half-width card.
  static String areaOf(String address) {
    final first = address.split(',').first.trim();
    return first.isEmpty ? address.trim() : first;
  }

  @override
  Widget build(BuildContext context) {
    // Press feedback only — no hover lift/grow on car cards.
    return Pressable(
      onTap: onTap,
      hoverScale: 1,
      hoverLift: 0,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TiltCard(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'car_image_${car.id}',
                      child: CachedImage(url: car.coverImage, iconSize: 40),
                    ),
                    if (car.type.isNotEmpty) Positioned(left: 8, top: 8, child: _TypeBadge(label: car.type)),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _FavoriteButton(isFavorite: isFavorite, onTap: onFavoriteToggle),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
              // Stacked, not side-by-side: this card sits in a 2-column
              // grid (~150px wide), too narrow for a title+price row.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (car.reviewCount > 0) ...[
                        Icon(LucideIcons.star, size: 14, color: AppColors.star),
                        const SizedBox(width: 2),
                        Text(
                          car.rating.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else
                        Text(
                          'New',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text('  ·  ', style: AppTextStyles.caption),
                      Expanded(
                        child: Text(
                          areaOf(car.address),
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: AppFormatters.currency(car.pricePerDay),
                                style: AppTextStyles.priceMedium.copyWith(color: AppColors.textPrimary, fontSize: 17),
                              ),
                              TextSpan(text: ' /day', style: AppTextStyles.caption),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(LucideIcons.arrowRight, size: 16, color: AppColors.accent),
                      ),
                    ],
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

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(7)),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.overlayText,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      scale: 0.85,
      hoverScale: 1,
      child: Material(
        color: isFavorite ? AppColors.danger.withValues(alpha: 0.9) : AppColors.navy.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(isFavorite ? LucideIcons.heart : LucideIcons.heart, color: AppColors.overlayText, size: 16),
          ),
        ),
      ),
    );
  }
}
