import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/vin_verified_badge.dart';
import '../models/car_draft.dart';

/// Step 5 — Preview (Section 9): shows the listing exactly as Car Details
/// will render it, so publishing never feels like a leap of faith.
class PreviewStep extends StatelessWidget {
  const PreviewStep({super.key, required this.draft});

  final CarDraft draft;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review your listing', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text('Make sure everything looks right before you publish.', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          if (draft.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: PageView(
                  children: draft.images.map((url) => CachedImage(url: url)).toList(),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('${draft.brand} ${draft.model} · ${draft.year ?? '—'}', style: AppTextStyles.h3),
          if (draft.vinVerified) ...[
            const SizedBox(height: AppSpacing.xs),
            const VinVerifiedBadge(),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppFormatters.pricePerDay(draft.pricePerDay ?? 0),
            style: AppTextStyles.priceLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Tag(draft.type ?? '—'),
              _Tag(draft.transmission ?? '—'),
              _Tag(draft.fuelType ?? '—'),
              _Tag('${draft.seats} seats'),
              _Tag(draft.airConditioning ? 'A/C' : 'No A/C'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Description', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(draft.description, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Text('Pickup location', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(LucideIcons.mapPin, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(draft.address, style: AppTextStyles.bodyMedium)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
    );
  }
}
