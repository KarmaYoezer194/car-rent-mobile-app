import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

/// Write a Review (Section 21) — reached from a `completed` booking on the
/// Booking screen's Renting tab. One review per booking, enforced by
/// [ReviewService] keying the document off the booking id, so this screen
/// only needs to worry about collecting the rating/comment.
class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key, required this.booking});

  final BookingModel booking;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppSnackbar.show(context, 'Pick a star rating first.');
      return;
    }
    // Only the renter named on this booking may review it — checked again
    // here (not just relied on from the Renting tab's own filtering)
    // because the signed-in account can change *after* this screen opened
    // (e.g. another tab of the same browser signing in as someone else,
    // which swaps the session for every tab sharing that browser's Firebase
    // Auth storage). Catching it here gives a precise message instead of a
    // round trip to a permission-denied from Firestore.
    final currentUid = context.read<AuthService>().currentUser?.uid;
    if (currentUid != widget.booking.renterId) {
      AppSnackbar.show(context, "You're signed in as a different account than the one that booked this rental.");
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await context.read<ReviewService>().submitReview(
            booking: widget.booking,
            rating: _rating.toDouble(),
            comment: _commentController.text,
          );
      if (mounted) {
        AppSnackbar.show(context, 'Thanks for your review!');
        Navigator.of(context).pop(true);
      }
    } on ReviewException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message);
    } on FirebaseException catch (e) {
      debugPrint('WriteReviewScreen submit failed: ${e.plugin}/${e.code} ${e.message}');
      if (mounted) {
        AppSnackbar.show(
          context,
          e.code == 'permission-denied'
              ? "You don't have permission to review this rental."
              : 'Something went wrong (${e.code}). Please try again.',
        );
      }
    } catch (e) {
      debugPrint('WriteReviewScreen submit failed: $e');
      if (mounted) AppSnackbar.show(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 86,
                height: 86,
                child: CachedImage(url: widget.booking.carImage),
              ),
            ).animate().scaleXY(begin: 0.7, end: 1, duration: 420.ms, curve: Curves.easeOutBack).fadeIn(duration: 280.ms),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('How was your rental?', style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.booking.carTitle,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Text('Rate the car', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                _StarPicker(rating: _rating, onChanged: (value) => setState(() => _rating = value)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomTextField(
            label: 'Comment',
            controller: _commentController,
            hint: 'Share details about the car, the pickup, or the owner...',
            maxLines: 5,
            inputFormatters: [CapitalizeSentencesFormatter()],
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(label: 'Submit Review', isLoading: _isSubmitting, onPressed: _submit),
        ],
      ),
    );
  }
}

/// Five tappable stars, 1-indexed — tapping star N sets the rating to N.
class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= rating;
        return IconButton(
          iconSize: 40,
          onPressed: () => onChanged(starValue),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: AppColors.star,
          )
              .animate(key: ValueKey('$starValue-$filled'))
              .scaleXY(begin: filled ? 0.5 : 1, end: 1, duration: 260.ms, curve: Curves.easeOutBack),
        );
      }),
    );
  }
}
