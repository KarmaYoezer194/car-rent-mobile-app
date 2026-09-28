import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/booking_model.dart';
import '../../../models/review_model.dart';
import '../../../widgets/booking_card.dart';
import '../../../widgets/brand_header.dart';
import '../../../widgets/loading_widget.dart';
import '../../reviews/screens/write_review_screen.dart';
import 'active_rental_screen.dart';
import 'booking_details_screen.dart';

/// Status groups for the filter chips. Cancelled and rejected bookings only
/// appear under [all] — they're history, not something to act on.
enum _BookingFilter {
  all('All'),
  upcoming('Upcoming'),
  active('Active'),
  completed('Completed');

  const _BookingFilter(this.label);
  final String label;

  bool matches(BookingModel b) => switch (this) {
    _BookingFilter.all => true,
    _BookingFilter.upcoming => b.status == BookingStatus.pending || b.status == BookingStatus.confirmed,
    _BookingFilter.active => b.status == BookingStatus.active || b.status == BookingStatus.returnRequested,
    _BookingFilter.completed => b.status == BookingStatus.completed,
  };
}

/// Booking hub (Section 13): "Renting" (cars this user is renting) and "My
/// Cars" (booking requests against cars this user owns), with a stats
/// summary and status filters for whichever side is selected.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.initialTabIndex = 0});

  /// Which side opens first — 0 (Renting) or 1 (My Cars). Set when arriving
  /// from a notification tap, so e.g. a "new booking request" lands owners
  /// straight on the side that shows it.
  final int initialTabIndex;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late bool _ownerSide = widget.initialTabIndex == 1;
  _BookingFilter _filter = _BookingFilter.all;

  @override
  void didUpdateWidget(covariant BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A notification tap can re-route here with a different side while
    // this tab is already alive.
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _ownerSide = widget.initialTabIndex == 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    final bookingService = context.watch<BookingService>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const BrandHeader(subtitle: 'My Bookings'),
            Expanded(
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<BookingModel>>(
                      // Keyed by side so switching doesn't flash the other
                      // side's list while the new stream connects.
                      key: ValueKey(_ownerSide),
                      stream: _ownerSide
                          ? bookingService.streamBookingsForOwner(uid)
                          : bookingService.streamBookingsForRenter(uid),
                      builder: (context, snapshot) {
                        final bookings = snapshot.data ?? const <BookingModel>[];
                        final visible = bookings.where(_filter.matches).toList();

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            AppSpacing.xs,
                            AppSpacing.screen,
                            AppSpacing.xl,
                          ),
                          children: [
                            _HeaderCard(
                              ownerSide: _ownerSide,
                              onSideChanged: (owner) => setState(() {
                                _ownerSide = owner;
                                _filter = _BookingFilter.all;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _StatsRow(bookings: bookings, ownerSide: _ownerSide),
                            const SizedBox(height: AppSpacing.md),
                            _FilterChips(
                              bookings: bookings,
                              selected: _filter,
                              onSelected: (f) => setState(() => _filter = f),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            // Crossfades when the side, filter or loading state
                            // changes, instead of swapping the list instantly.
                            AnimatedSwitcher(
                              duration: AppMotion.tabSwitch,
                              switchInCurve: AppMotion.enter,
                              switchOutCurve: AppMotion.exit,
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.topCenter,
                                children: [...previous, ?current],
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(
                                  '$_ownerSide|${_filter.name}|${snapshot.connectionState == ConnectionState.waiting}',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (snapshot.connectionState == ConnectionState.waiting)
                                      const SizedBox(height: 240, child: LoadingWidget())
                                    else if (snapshot.hasError)
                                      ErrorStateWidget(message: AppStrings.genericError, onRetry: () => setState(() {}))
                                    else if (visible.isEmpty)
                                      EmptyStateWidget(
                                        icon: _ownerSide ? LucideIcons.fileText : LucideIcons.calendarX,
                                        message: _filter != _BookingFilter.all
                                            ? 'No ${_filter.label.toLowerCase()} bookings.'
                                            : (_ownerSide ? AppStrings.noBookingRequests : AppStrings.noActiveRentals),
                                      )
                                    else
                                      for (final (index, booking) in visible.indexed)
                                        Entrance(
                                          delay: Entrance.staggerDelay(index),
                                          child: _ownerSide
                                              ? _OwnerBookingItem(booking: booking, bookingService: bookingService)
                                              : _RenterBookingItem(booking: booking, bookingService: bookingService),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                            if (_ownerSide) ...[const SizedBox(height: AppSpacing.sm), const _ListAnotherCarCard()],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.ownerSide, required this.onSideChanged});

  final bool ownerSide;
  final ValueChanged<bool> onSideChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Text('Bookings', style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ownerSide ? 'Fleet performance & activity' : 'Your trips & activity',
              style: AppTextStyles.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _Segment(label: 'Renting', selected: !ownerSide, onTap: () => onSideChanged(false)),
                _Segment(label: 'My Cars', selected: ownerSide, onTap: () => onSideChanged(true)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Expanded must stay the direct child of the Row, so the press
    // effect goes inside it.
    return Expanded(
      child: PressFeedback(
        scale: 0.97,
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.bookings, required this.ownerSide});

  final List<BookingModel> bookings;
  final bool ownerSide;

  @override
  Widget build(BuildContext context) {
    final completed = bookings.where((b) => b.status == BookingStatus.completed).toList();
    final upcoming = bookings.where(_BookingFilter.upcoming.matches).length;
    // Owners earn their payout (total minus platform commission); renters
    // spent the full total.
    final total = completed.fold<double>(0, (sum, b) => sum + (ownerSide ? b.payoutForOwner : b.totalPrice));

    return Row(
      children: [
        Expanded(
          child: _StatTile(value: '${completed.length}', label: 'Completed'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(value: '$upcoming', label: 'Upcoming', valueColor: upcoming > 0 ? AppColors.accent : null),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            value: ownerSide ? AppFormatters.money(total) : AppFormatters.currency(total),
            label: ownerSide ? 'Earned' : 'Spent',
            valueColor: ownerSide ? AppColors.success : AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.h3.copyWith(fontSize: 19, fontWeight: FontWeight.w800, color: valueColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.bookings, required this.selected, required this.onSelected});

  final List<BookingModel> bookings;
  final _BookingFilter selected;
  final ValueChanged<_BookingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _BookingFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = _BookingFilter.values[index];
          final isSelected = filter == selected;
          final count = bookings.where(filter.matches).length;
          return Material(
            color: isSelected ? AppColors.primary : AppColors.surface,
            shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelected(filter),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    '${filter.label} ($count)',
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void _openBooking(BuildContext context, BookingModel booking) {
  // Live rentals get the tracking/handover screen — return_requested
  // included, since the owner needs it to see the car and tap Confirm
  // Return (the renter lands on its "waiting for the owner" notice).
  // Everything else — completed, cancelled, rejected, pending, confirmed —
  // opens the read-only details screen.
  final live = [BookingStatus.active, BookingStatus.returnRequested].contains(booking.status);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => live ? ActiveRentalScreen(booking: booking) : BookingDetailsScreen(booking: booking),
    ),
  );
}

/// Bookings that are done — nothing to accept/cancel/start any more — are
/// the only ones swipeable off either list.
bool _isSettled(String status) =>
    status == BookingStatus.cancelled || status == BookingStatus.rejected || status == BookingStatus.completed;

Future<void> _run(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) AppSnackbar.show(context, success);
  } catch (e) {
    if (context.mounted) AppSnackbar.show(context, AppStrings.genericError);
  }
}

class _RenterBookingItem extends StatelessWidget {
  const _RenterBookingItem({required this.booking, required this.bookingService});

  final BookingModel booking;
  final BookingService bookingService;

  @override
  Widget build(BuildContext context) {
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingCard(
          booking: booking,
          counterpartId: booking.ownerId,
          onTap: () => _openBooking(context, booking),
          onCancel: [BookingStatus.pending, BookingStatus.confirmed].contains(booking.status)
              ? () => _run(context, () => bookingService.cancelBooking(booking))
              : null,
        ),
        if (booking.status == BookingStatus.completed) _WriteReviewCta(booking: booking),
      ],
    );
    if (!_isSettled(booking.status)) return card;
    return _DismissibleBooking(
      bookingId: booking.id,
      onHide: () => bookingService.hideForRenter(booking.id),
      onUndo: () => bookingService.hideForRenter(booking.id, hidden: false),
      child: card,
    );
  }
}

class _OwnerBookingItem extends StatelessWidget {
  const _OwnerBookingItem({required this.booking, required this.bookingService});

  final BookingModel booking;
  final BookingService bookingService;

  @override
  Widget build(BuildContext context) {
    final isPending = booking.status == BookingStatus.pending;
    final card = BookingCard(
      booking: booking,
      counterpartId: booking.renterId,
      showOwnerPayout: true,
      onTap: () => _openBooking(context, booking),
      onAccept: isPending ? () => _run(context, () => bookingService.respondToBooking(booking, accept: true)) : null,
      onReject: isPending ? () => _run(context, () => bookingService.respondToBooking(booking, accept: false)) : null,
      onStart: booking.status == BookingStatus.confirmed
          ? () => _run(context, () => bookingService.startRental(booking), success: 'Rental started.')
          : null,
    );
    if (!_isSettled(booking.status)) return card;
    return _DismissibleBooking(
      bookingId: booking.id,
      onHide: () => bookingService.hideForOwner(booking.id),
      onUndo: () => bookingService.hideForOwner(booking.id, hidden: false),
      child: card,
    );
  }
}

/// End of the owner's list: a nudge to list another car, straight into the
/// Post tab.
class _ListAnotherCarCard extends StatelessWidget {
  const _ListAnotherCarCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.add_road_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'List Another Car',
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text('More cars, more bookings.', style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              onPressed: () => context.go('/post'),
              child: const Text('List'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a settled booking card so it can be swiped to reveal a Delete
/// button. Sliding it only exposes that button — nothing is removed until
/// it's tapped and confirmed. Confirmed deletes only hide the booking from
/// the swiping party's own list (see
/// [BookingService.hideForRenter]/[hideForOwner]) — the record itself
/// isn't deleted, since the other side of the same booking may still want
/// to see it — so an "Undo" snackbar can put it straight back.
class _DismissibleBooking extends StatelessWidget {
  const _DismissibleBooking({required this.bookingId, required this.onHide, required this.onUndo, required this.child});

  final String bookingId;
  final Future<void> Function() onHide;
  final VoidCallback onUndo;
  final Widget child;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this booking?'),
        content: const Text('This removes it from your list. You can undo it right after.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await onHide();
    } catch (e) {
      if (context.mounted) AppSnackbar.show(context, AppStrings.genericError);
      return;
    }
    if (context.mounted) {
      AppSnackbar.show(
        context,
        'Booking removed from this list.',
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(bookingId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          CustomSlidableAction(
            onPressed: _confirmDelete,
            backgroundColor: Colors.transparent,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.xl)),
                child: SizedBox.expand(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.trash2, color: AppColors.overlayText),
                        const SizedBox(height: 4),
                        Text(
                          'Delete',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.overlayText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Sits under a `completed` [BookingCard] in the Renting list: a "Write a
/// Review" button, or a small "you reviewed this" line once
/// [ReviewService.streamReviewForBooking] shows one already exists.
class _WriteReviewCta extends StatelessWidget {
  const _WriteReviewCta({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final reviewService = context.watch<ReviewService>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: StreamBuilder<ReviewModel?>(
        stream: reviewService.streamReviewForBooking(booking.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
          final review = snapshot.data;
          if (review != null) {
            return Row(
              children: [
                Icon(LucideIcons.star, color: AppColors.star, size: 16),
                const SizedBox(width: 4),
                Text('You rated this rental ${review.rating.toStringAsFixed(1)}', style: AppTextStyles.bodySmall),
              ],
            );
          }
          return OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => WriteReviewScreen(booking: booking))),
            icon: Icon(LucideIcons.star, size: 18, color: AppColors.star),
            label: const Text('Write a Review'),
          );
        },
      ),
    );
  }
}
