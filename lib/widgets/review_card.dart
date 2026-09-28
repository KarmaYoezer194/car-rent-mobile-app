import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_text_styles.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import 'user_avatar.dart';

/// One review shown on Car Details' Reviews section and Profile's My
/// Reviews (Section 8 / Section 21) — reviewer name/photo streamed from
/// `users` since [ReviewModel] only stores the renter's id.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.showCarTitle = false});

  final ReviewModel review;

  /// My Reviews lists reviews across many cars, so it shows which car each
  /// one was for; Car Details' list already knows the car, so it hides it.
  final bool showCarTitle;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One shared listener for the reviewer's doc (avatar + name both
          // need it) rather than each opening its own.
          StreamBuilder<UserModel?>(
            stream: authService.userDoc(review.renterId),
            builder: (context, snapshot) {
              final reviewer = snapshot.data;
              return Row(
                children: [
                  UserAvatar(name: reviewer?.name ?? '', photoUrl: reviewer?.profileImage, size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reviewer?.name ?? 'CarRent user', style: AppTextStyles.titleMedium),
                        if (showCarTitle)
                          Text(review.carTitle, style: AppTextStyles.caption)
                        else
                          Text(_dateFormat.format(review.createdAt), style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  _StarRow(rating: review.rating),
                ],
              );
            },
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(review.comment, style: AppTextStyles.bodyMedium),
          ],
          if (showCarTitle) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_dateFormat.format(review.createdAt), style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.star, color: AppColors.star, size: 16),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: AppTextStyles.bodySmall),
      ],
    );
  }
}
