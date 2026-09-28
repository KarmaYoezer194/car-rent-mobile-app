import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/pricing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/booking_model.dart';
import '../../../models/review_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/booking_card.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/review_card.dart';
import '../../reviews/screens/write_review_screen.dart';

/// Read-only details for a booking that isn't live on the road — completed,
/// cancelled, rejected, pending or confirmed. (Active and return-requested
/// bookings open [ActiveRentalScreen] instead, which has the live map and
/// handover actions.)
///
/// Works from either side: the renter sees the owner as the other party,
/// the owner sees the renter.
class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key, required this.booking});

  final BookingModel booking;

  static final _dateFormat = DateFormat('EEE, MMM d, yyyy');
  static final _createdFormat = DateFormat('MMM d, yyyy · h:mm a');

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid;
    final viewerIsOwner = uid == booking.ownerId;

    final sections = <Widget>[
      _CarHeader(booking: booking),
      _Section(
        title: 'Trip',
        children: [
          _InfoRow(icon: LucideIcons.logIn, label: 'Pick-up', value: _dateFormat.format(booking.startDate)),
          _InfoRow(icon: LucideIcons.logOut, label: 'Return', value: _dateFormat.format(booking.endDate)),
          _InfoRow(
            icon: LucideIcons.clock,
            label: 'Duration',
            value: '${booking.totalDays} ${booking.totalDays == 1 ? 'day' : 'days'}',
          ),
        ],
      ),
      if (viewerIsOwner)
        _OwnerPayment(booking: booking)
      else
        _Section(
          title: 'Payment',
          children: [
            _InfoRow(
              icon: LucideIcons.tag,
              label: '${AppFormatters.currency(booking.pricePerDay)} × ${booking.totalDays} ${booking.totalDays == 1 ? 'day' : 'days'}',
              value: AppFormatters.currency(booking.pricePerDay * booking.totalDays),
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Text('Total', style: AppTextStyles.titleMedium),
                const Spacer(),
                Text(AppFormatters.currency(booking.totalPrice), style: AppTextStyles.priceLarge),
              ],
            ),
          ],
        ),
      _OtherParty(
        userId: viewerIsOwner ? booking.renterId : booking.ownerId,
        label: viewerIsOwner ? 'Rented by' : 'Car owner',
      ),
      if (booking.status == BookingStatus.completed) _ReviewSection(booking: booking, viewerIsRenter: uid == booking.renterId),
      _Section(
        title: 'Booking',
        children: [
          _InfoRow(icon: LucideIcons.hash, label: 'Booking ID', value: booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()),
          _InfoRow(icon: LucideIcons.calendarDays, label: 'Requested', value: _createdFormat.format(booking.createdAt)),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Booking details')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Entrance(delay: Entrance.staggerDelay(index), child: sections[index]),
      ),
    );
  }
}

class _CarHeader extends StatelessWidget {
  const _CarHeader({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: CachedImage(url: booking.carImage)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(booking.carTitle, style: AppTextStyles.h3)),
                    const SizedBox(width: AppSpacing.sm),
                    BookingStatusChip(status: booking.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(AppFormatters.pricePerDay(booking.pricePerDay), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/car/${booking.carId}'),
                    icon: const Icon(LucideIcons.car, size: 18),
                    label: const Text('View car'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner's view of the money: what the renter pays, the platform
/// commission, and the payout. This is the one place the breakdown is
/// shown — everywhere else owners see just the payout, and renters never
/// see the commission at all.
class _OwnerPayment extends StatelessWidget {
  const _OwnerPayment({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final commission = booking.commissionAmount;
    return _Section(
      title: 'Your earnings',
      children: [
        _InfoRow(icon: LucideIcons.receipt, label: 'Renter pays', value: AppFormatters.money(booking.totalPrice)),
        if (commission != null)
          _InfoRow(
            icon: LucideIcons.percent,
            label: 'Platform fee (${(PlatformPricing.commissionRate * 100).round()}%)',
            value: '− ${AppFormatters.money(commission)}',
          ),
        const Divider(height: AppSpacing.lg),
        Row(
          children: [
            Text('Your payout', style: AppTextStyles.titleMedium),
            const Spacer(),
            Text(AppFormatters.money(booking.payoutForOwner), style: AppTextStyles.priceLarge),
          ],
        ),
        if (commission == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No platform fee — this booking was made before fees applied.',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }
}

class _OtherParty extends StatelessWidget {
  const _OtherParty({required this.userId, required this.label});

  final String userId;
  final String label;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: context.read<AuthService>().userDoc(userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'CarRent user';
        final phone = user?.phone ?? '';
        final photo = user?.profileImage;

        return _Section(
          title: label,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CachedImage(url: photo ?? '', icon: LucideIcons.user, iconSize: 22),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
                      if (user != null && user.reviewCount > 0)
                        Row(
                          children: [
                            Icon(LucideIcons.star, size: 15, color: AppColors.star),
                            const SizedBox(width: 3),
                            Text('${user.rating.toStringAsFixed(1)} · ${user.reviewCount} reviews', style: AppTextStyles.caption),
                          ],
                        ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty)
                  IconButton.filledTonal(
                    tooltip: 'Call $phone',
                    icon: const Icon(LucideIcons.phone, size: 20),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.booking, required this.viewerIsRenter});

  final BookingModel booking;
  final bool viewerIsRenter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReviewModel?>(
      stream: context.read<ReviewService>().streamReviewForBooking(booking.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final review = snapshot.data;

        return _Section(
          title: 'Review',
          children: [
            if (review != null)
              ReviewCard(review: review)
            else if (viewerIsRenter)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => WriteReviewScreen(booking: booking)),
                  ),
                  icon: const Icon(LucideIcons.star, size: 18),
                  label: const Text('Write a Review'),
                ),
              )
            else
              Text("The renter hasn't reviewed this rental yet.", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
          const SizedBox(width: AppSpacing.sm),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
