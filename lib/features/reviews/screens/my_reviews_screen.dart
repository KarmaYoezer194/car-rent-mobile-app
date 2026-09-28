import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/review_model.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/review_card.dart';

/// My Reviews (Section 21) — every review this user has written, newest
/// first. Reached from the Profile menu.
class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    final reviewService = context.watch<ReviewService>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Reviews')),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<ReviewModel>>(
              stream: reviewService.streamReviewsByRenter(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LoadingWidget();
                if (snapshot.hasError) {
                  return const ErrorStateWidget(message: AppStrings.genericError);
                }
                final reviews = snapshot.data ?? const [];
                if (reviews.isEmpty) {
                  return const EmptyStateWidget(icon: LucideIcons.star, message: AppStrings.noReviews);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) => Entrance(
                    delay: Entrance.staggerDelay(index),
                    child: ReviewCard(review: reviews[index], showCarTitle: true),
                  ),
                );
              },
            ),
    );
  }
}
