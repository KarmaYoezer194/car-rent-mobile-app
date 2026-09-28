import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

/// A rounded placeholder block with a moving light sweep — the shared
/// "content is loading" language used by every skeleton in the app
/// (car-card grids, list rows, profile stats) instead of a bare spinner.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1400.ms,
          color: AppColors.border.withValues(alpha: 0.5),
        );
  }
}

/// The skeleton shown in place of a [CarCard] while the home grid's first
/// stream snapshot is still loading — same proportions (16:10 photo +
/// title/meta/price stack) so the grid doesn't jump when real cards swap
/// in.
class CarCardSkeleton extends StatelessWidget {
  const CarCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 11,
              child: ShimmerBox(radius: AppRadius.lg),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 100, height: 15),
                  SizedBox(height: 8),
                  ShimmerBox(width: 130, height: 12),
                  SizedBox(height: 10),
                  ShimmerBox(width: 70, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple horizontal-row skeleton for list screens (bookings, favorites,
/// reviews) — a square thumbnail beside two lines of text.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const ShimmerBox(width: 72, height: 72, radius: AppRadius.lg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 160, height: 15),
                SizedBox(height: 8),
                ShimmerBox(width: 110, height: 12),
                SizedBox(height: 8),
                ShimmerBox(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
