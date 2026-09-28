import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/motion/entrance.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'cached_image.dart';
import 'user_avatar.dart';

/// One booking request/rental shown on the Booking screen — used for both
/// the "Renting" and "My Cars" tabs, with the caller supplying whatever
/// actions make sense for that role and status (accept/reject a pending
/// request, start a confirmed one, cancel, or none once it's settled).
/// [onTap] opens full details — the Active Rental screen for live bookings,
/// BookingDetailsScreen for every other status.
///
/// [counterpartId] is the *other* person on the booking (the renter on the
/// owner's list, the owner on the renter's), shown as a small avatar + name.
///
/// [showOwnerPayout] is set on the owner's list: the card then shows what
/// the owner receives ("฿849.15 payout") instead of the renter's total.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.counterpartId,
    this.showOwnerPayout = false,
    this.onTap,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onStart,
  });

  final BookingModel booking;
  final String? counterpartId;
  final bool showOwnerPayout;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onStart;

  static final _dateFormat = DateFormat('MMM d');

  /// Whole days from today until the rental starts (0 = today).
  int get _daysUntilStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(booking.startDate.year, booking.startDate.month, booking.startDate.day);
    return start.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final hasActions = onAccept != null || onReject != null || onCancel != null || onStart != null;
    final isUpcoming = booking.status == BookingStatus.confirmed;
    final dateColor = isUpcoming || booking.status == BookingStatus.pending
        ? AppColors.accent
        : AppColors.textSecondary;

    return Pressable(
      onTap: onTap ?? () {},
      scale: onTap == null ? 1 : 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(width: 78, height: 78, child: CachedImage(url: booking.carImage)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              booking.carTitle,
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          BookingStatusChip(status: booking.status),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(LucideIcons.calendar, size: 13, color: dateColor),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${_dateFormat.format(booking.startDate)} – ${_dateFormat.format(booking.endDate)}'
                              ' • ${booking.totalDays} day${booking.totalDays == 1 ? '' : 's'}',
                              style: AppTextStyles.caption.copyWith(color: dateColor, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: showOwnerPayout
                                      ? AppFormatters.money(booking.payoutForOwner)
                                      : AppFormatters.currency(booking.totalPrice),
                                  style: AppTextStyles.priceMedium.copyWith(color: AppColors.textPrimary, fontSize: 17),
                                ),
                                TextSpan(text: showOwnerPayout ? ' payout' : ' total', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (counterpartId != null) _Counterpart(userId: counterpartId!),
                          if (onTap != null) Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isUpcoming) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.keyRound, size: 16, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        switch (_daysUntilStart) {
                          <= 0 => 'Handover today',
                          1 => 'Handover tomorrow',
                          final d => 'Handover in $d days',
                        },
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Text(
                        'View details',
                        style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ],
            if (hasActions) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (onReject != null)
                    Expanded(
                      child: _CardButton(label: 'Reject', onPressed: onReject!),
                    ),
                  if (onReject != null && onAccept != null) const SizedBox(width: AppSpacing.sm),
                  if (onAccept != null)
                    Expanded(
                      child: _CardButton(label: 'Accept', onPressed: onAccept!, filled: true),
                    ),
                  if (onStart != null)
                    Expanded(
                      child: _CardButton(label: 'Start Rental', onPressed: onStart!, filled: true),
                    ),
                  if (onCancel != null)
                    Expanded(
                      child: _CardButton(label: 'Cancel Request', onPressed: onCancel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.onPressed, this.filled = false});

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.fromHeight(44)));
    return PressFeedback(
      scale: 0.97,
      child: filled
          ? ElevatedButton(onPressed: onPressed, style: style, child: Text(label))
          : OutlinedButton(onPressed: onPressed, style: style, child: Text(label)),
    );
  }
}

class _Counterpart extends StatelessWidget {
  const _Counterpart({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: context.read<AuthService>().userDoc(userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const SizedBox.shrink();
        final parts = user.name.trim().split(RegExp(r'\s+'));
        // "Arun K." — first name plus last initial keeps it short.
        final short = parts.length > 1 ? '${parts.first} ${parts.last[0]}.' : parts.first;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(name: user.name, photoUrl: user.profileImage, size: 22),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(
                short,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Colored status pill for a booking — shared by [BookingCard] and the
/// booking details screen.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status});

  final String status;

  (Color, Color) get _colors {
    switch (status) {
      case BookingStatus.pending:
        return (AppColors.statusPending, AppColors.statusPendingBg);
      case BookingStatus.confirmed:
        return (AppColors.statusConfirmed, AppColors.statusConfirmedBg);
      case BookingStatus.active:
        return (AppColors.statusActive, AppColors.statusActiveBg);
      case BookingStatus.returnRequested:
        return (AppColors.statusPending, AppColors.statusPendingBg);
      case BookingStatus.completed:
        return (AppColors.statusCompleted, AppColors.statusCompletedBg);
      case BookingStatus.rejected:
        return (AppColors.statusRejected, AppColors.statusRejectedBg);
      case BookingStatus.cancelled:
      default:
        return (AppColors.statusCancelled, AppColors.statusCancelledBg);
    }
  }

  IconData? get _icon => switch (status) {
    BookingStatus.completed => LucideIcons.circleCheck,
    BookingStatus.confirmed || BookingStatus.pending => LucideIcons.clock,
    BookingStatus.returnRequested => LucideIcons.undo2,
    BookingStatus.rejected || BookingStatus.cancelled => LucideIcons.circleX,
    _ => null,
  };

  /// A confirmed booking is shown as "Upcoming" — that's what it means to
  /// both parties (accepted, not started yet). `return_requested` needs its
  /// underscore turned into a space rather than printed raw.
  String get _label => status == BookingStatus.confirmed
      ? 'Upcoming'
      : status.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    final icon = _icon;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == BookingStatus.active)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child:
                  Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 700.ms)
                      .then()
                      .fadeOut(duration: 700.ms),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 12, color: fg),
            ),
          Text(
            _label,
            style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
    return status == BookingStatus.pending
        ? chip
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.06, duration: 900.ms, curve: Curves.easeInOut)
        : chip;
  }
}
