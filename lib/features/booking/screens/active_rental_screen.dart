import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/tracking_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../models/booking_location_model.dart';
import '../../../models/car_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/osm_map_view.dart';
import '../../cars/screens/full_screen_map_screen.dart';
import '../../../widgets/user_avatar.dart';

/// Active Rental (Section 16) — reached by tapping a booking whose status
/// is `active` or `return_requested`.
///
/// Location sharing: the first time the renter opens an active booking
/// they're asked, explicitly, whether to share their location with the
/// owner for this rental; the answer is stored on the booking with a
/// server timestamp (BookingService.recordLocationConsent). Only after a
/// grant does their device send its position (every
/// [TrackingConfig.heartbeatInterval]) — resuming automatically on later
/// visits, since consent was already given. The switch pauses sending
/// without touching the consent record. The owner sees the latest position
/// on a map while the booking is `active`; once it leaves `active`,
/// sharing stops and the stored location is deleted.
///
/// Section 20's handover is two steps: the renter taps "I've Returned the
/// Car" (`_requestReturn`) to flag the car as handed back — which is what
/// stops this screen rendering the sharing toggle for the renter, since the
/// stream this screen watches moves the booking out of `active` — and then
/// the owner, who keeps seeing the full screen through that in-between
/// state, taps "Confirm Return" (`_confirmReturn`) once they've actually
/// checked the car. An owner can also confirm straight from `active`
/// without waiting on the renter's tap.
class ActiveRentalScreen extends StatefulWidget {
  const ActiveRentalScreen({super.key, required this.booking});

  final BookingModel booking;

  @override
  State<ActiveRentalScreen> createState() => _ActiveRentalScreenState();
}

class _ActiveRentalScreenState extends State<ActiveRentalScreen> {
  final _trackingService = TrackingService();
  bool _isSharingLocation = false;
  bool _isTogglingShare = false;

  /// Guards so the consent prompt / automatic resume happen at most once
  /// per visit to this screen, however often the booking stream rebuilds.
  bool _consentPromptShown = false;
  bool _autoResumeAttempted = false;

  static final _dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');

  @override
  void dispose() {
    // Section 18/20: tracking must not outlive this screen or the rental.
    _trackingService.stopTracking();
    super.dispose();
  }

  Future<void> _toggleSharing(bool value) async {
    setState(() => _isTogglingShare = true);
    try {
      if (value) {
        await _trackingService.startTracking(
          bookingId: widget.booking.id,
          renterId: widget.booking.renterId,
          ownerId: widget.booking.ownerId,
          // The backend refused an update — the booking left `active`.
          onStopped: () {
            if (mounted) setState(() => _isSharingLocation = false);
          },
        );
      } else {
        await _trackingService.stopTracking();
      }
      if (mounted) setState(() => _isSharingLocation = value);
    } on LocationException catch (e) {
      if (!mounted) return;
      if (e.canOpenSettings) {
        _showSettingsDialog(e.message);
      } else {
        AppSnackbar.show(context, e.message);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, "Couldn't start sharing your location. Please try again.");
    } finally {
      if (mounted) setState(() => _isTogglingShare = false);
    }
  }

  void _showSettingsDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location needed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _trackingService.stopTracking();
              LocationService().openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Asks the renter, once, whether to share their location for this
  /// rental. Not dismissible by tapping outside — it needs an answer.
  Future<void> _askForConsent(BookingService bookingService, BookingModel booking) async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _LocationConsentDialog(),
    );
    if (granted == null || !mounted) return;
    await _saveConsent(bookingService, booking, granted: granted);
  }

  Future<void> _saveConsent(BookingService bookingService, BookingModel booking, {required bool granted}) async {
    try {
      await bookingService.recordLocationConsent(booking, granted: granted);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, "Couldn't save your choice. Please try again.");
      return;
    }
    if (granted && mounted) await _toggleSharing(true);
  }

  Future<void> _requestReturn(BookingService bookingService, BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return the car?'),
        content: const Text("This lets the owner know you're handing the car back. They'll confirm once they've checked it."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("I've Returned It")),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await bookingService.requestReturn(booking);
      if (mounted) AppSnackbar.show(context, "The owner's been notified.");
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Something went wrong. Please try again.');
    }
  }

  Future<void> _confirmReturn(BookingService bookingService, BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm the car was returned?'),
        content: const Text('This completes the rental and makes the car available again.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm Return')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await bookingService.completeRental(booking);
      if (mounted) AppSnackbar.show(context, 'Rental completed.');
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final bookingService = context.watch<BookingService>();
    final carService = context.watch<CarService>();
    final uid = authService.currentUser?.uid;
    final isOwner = uid == widget.booking.ownerId;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Rental')),
      body: StreamBuilder<BookingModel?>(
        stream: bookingService.streamBooking(widget.booking.id),
        builder: (context, snapshot) {
          // Fall back to the snapshot this screen was opened with until the
          // live stream delivers its first value.
          final booking = snapshot.data ?? widget.booking;
          final isReturnRequested = booking.status == BookingStatus.returnRequested;

          if (booking.status != BookingStatus.active) {
            if (_isSharingLocation || _trackingService.isTracking) {
              // The rental moved on (either party completed it, or the
              // renter just flagged the handover) while this screen (and
              // this device's location sharing) was still open — stop it.
              WidgetsBinding.instance.addPostFrameCallback((_) => _toggleSharing(false));
            }
            // The owner still needs the working screen — map, other-party
            // card, Confirm Return — while a return request awaits their
            // confirmation; only the renter (or a truly finished rental)
            // gets the ended notice here.
            if (!(isOwner && isReturnRequested)) {
              return _RentalEndedNotice(status: booking.status);
            }
          }

          final otherPartyId = isOwner ? booking.renterId : booking.ownerId;

          // Renter + active: never share without an explicit answer. No
          // answer yet → ask. Already granted → resume sharing once per
          // visit (they can pause with the switch). Declined → nothing
          // until they opt in from the card below.
          if (!isOwner && booking.status == BookingStatus.active) {
            if (booking.locationConsent == null && !_consentPromptShown) {
              _consentPromptShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _askForConsent(bookingService, booking));
            } else if (booking.hasLocationConsent && !_autoResumeAttempted && !_isSharingLocation && !_isTogglingShare) {
              _autoResumeAttempted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _toggleSharing(true));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: CachedImage(url: booking.carImage),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isReturnRequested ? AppColors.statusPendingBg : AppColors.statusActiveBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: isReturnRequested ? AppColors.statusPending : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.8, end: 1.3, duration: 900.ms, curve: Curves.easeInOut),
                              Text(
                                isReturnRequested ? 'Return requested' : 'In progress',
                                style: AppTextStyles.caption.copyWith(
                                  color: isReturnRequested ? AppColors.statusPending : AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(booking.carTitle, style: AppTextStyles.h3),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 340.ms).moveY(begin: -10, end: 0, duration: 340.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: AppSpacing.xl),
              _InfoCard(
                children: [
                  _InfoRow(label: 'Rental starts', value: _dateFormat.format(booking.startDate)),
                  const Divider(height: AppSpacing.xl),
                  _InfoRow(label: 'Rental ends', value: _dateFormat.format(booking.endDate)),
                  const Divider(height: AppSpacing.xl),
                  // Owners see what they receive; renters the total they pay.
                  isOwner
                      ? _InfoRow(label: 'Your payout', value: AppFormatters.money(booking.payoutForOwner))
                      : _InfoRow(label: 'Total price', value: AppFormatters.currency(booking.totalPrice)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Car location', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              if (isOwner && isReturnRequested)
                const _SharingEndedCard()
              else if (isOwner)
                _OwnerLocationMap(
                  booking: booking,
                  trackingService: _trackingService,
                  carService: carService,
                )
              else
                _RenterSharingCard(
                  consent: booking.locationConsent,
                  consentAt: booking.locationConsentAt,
                  isSharing: _isSharingLocation,
                  isBusy: _isTogglingShare,
                  onChanged: _toggleSharing,
                  onOptIn: () => _saveConsent(bookingService, booking, granted: true),
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(isOwner ? 'Renter' : 'Owner', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<UserModel?>(
                stream: authService.userDoc(otherPartyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 64, child: LoadingWidget());
                  }
                  final person = snapshot.data;
                  return _InfoCard(
                    children: [
                      Row(
                        children: [
                          UserAvatar(name: person?.name ?? '', photoUrl: person?.profileImage, size: 48),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(person?.name ?? 'User', style: AppTextStyles.titleMedium),
                                Text(person?.phone ?? '', style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              if (isOwner && isReturnRequested) ...[
                const SizedBox(height: AppSpacing.xl),
                _InfoCard(
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.undo2, color: AppColors.statusPending, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            "The renter marked this car as returned. Confirm below once you've checked it.",
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              if (isOwner) ...[
                const SizedBox(height: AppSpacing.xxl),
                CustomButton(label: 'Confirm Return', onPressed: () => _confirmReturn(bookingService, booking)),
              ] else if (booking.status == BookingStatus.active) ...[
                const SizedBox(height: AppSpacing.xxl),
                CustomButton(
                  label: "I've Returned the Car",
                  isOutlined: true,
                  onPressed: () => _requestReturn(bookingService, booking),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LocationConsentDialog extends StatelessWidget {
  const _LocationConsentDialog();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
            ],
          ),
        );

    return AlertDialog(
      icon: Icon(LucideIcons.mapPin, color: AppColors.accent),
      title: const Text('Share your location with the owner?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          point(LucideIcons.locateFixed, "Your phone's approximate GPS location is shared while this rental is active."),
          point(LucideIcons.user, "Only this car's owner can see it — nobody else."),
          point(LucideIcons.clock, 'It updates about every ${TrackingConfig.heartbeatInterval.inSeconds} seconds while this screen is open.'),
          point(LucideIcons.trash2, 'Sharing stops when you return the car, and the location is deleted.'),
          point(LucideIcons.circlePause, 'You can pause sharing at any time.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Don't allow")),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Allow')),
      ],
    );
  }
}

class _RenterSharingCard extends StatelessWidget {
  const _RenterSharingCard({
    required this.consent,
    required this.consentAt,
    required this.isSharing,
    required this.isBusy,
    required this.onChanged,
    required this.onOptIn,
  });

  final String? consent;
  final DateTime? consentAt;
  final bool isSharing;
  final bool isBusy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOptIn;

  static final _consentFormat = DateFormat('MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    if (consent != LocationConsent.granted) {
      return _InfoCard(
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPinOff, color: AppColors.textMuted, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  consent == LocationConsent.declined
                      ? "You chose not to share your location. The owner can't see where the car is."
                      : 'Waiting for your answer about sharing your location.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : onOptIn,
              icon: const Icon(LucideIcons.locateFixed, size: 18),
              label: const Text('Share my location'),
            ),
          ),
        ],
      );
    }

    return _InfoCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isSharing ? 'Sharing your location' : 'Sharing paused', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    isSharing
                        ? 'The owner can see the car on their map. Keep this screen open to keep it updating.'
                        : 'The owner sees your last shared location as out of date. Turn on to resume.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            if (isBusy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Switch(value: isSharing, onChanged: onChanged),
          ],
        ),
        if (consentAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('You agreed to share on ${_consentFormat.format(consentAt!)}', style: AppTextStyles.caption),
          ),
        ],
      ],
    );
  }
}

/// Owner's view once the renter has marked the car returned: sharing has
/// ended and the stored location was deleted with that status change.
class _SharingEndedCard extends StatelessWidget {
  const _SharingEndedCard();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      children: [
        Row(
          children: [
            Icon(LucideIcons.locateOff, color: AppColors.textMuted, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Location sharing ended when the renter marked the car as returned.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OwnerLocationMap extends StatelessWidget {
  const _OwnerLocationMap({
    required this.booking,
    required this.trackingService,
    required this.carService,
  });

  final BookingModel booking;
  final TrackingService trackingService;
  final CarService carService;

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Placeholder shown until there's a live location: the car's declared
  /// pickup spot, with [message] explaining why.
  Widget _pickupPlaceholder(String message, IconData icon) {
    return StreamBuilder<CarModel?>(
      stream: carService.streamCar(booking.carId),
      builder: (context, carSnapshot) {
        final car = carSnapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (car != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: 220,
                  child: OsmMapView(center: MapPins.pickup(car.latitude, car.longitude), interactive: false),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(icon, color: AppColors.textMuted, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(message, style: AppTextStyles.caption)),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (booking.locationConsent == LocationConsent.declined) {
      return _pickupPlaceholder(
        'The renter chose not to share their location — showing the pickup spot.',
        LucideIcons.mapPinOff,
      );
    }
    if (!booking.hasLocationConsent) {
      return _pickupPlaceholder(
        'Waiting for the renter to allow location sharing — showing the pickup spot for now.',
        LucideIcons.locate,
      );
    }

    return StreamBuilder<BookingLocationModel?>(
      stream: trackingService.watchLocation(booking.id),
      builder: (context, locationSnapshot) {
        if (locationSnapshot.hasError) {
          // Rules refuse reads once the booking isn't active; the booking
          // stream normally swaps this widget out first, so this is a
          // brief edge case rather than a normal state.
          return _pickupPlaceholder('Live location is no longer available.', LucideIcons.locateOff);
        }
        final location = locationSnapshot.data;
        if (location == null) {
          return _pickupPlaceholder(
            'Waiting for the first location from the renter — showing the pickup spot for now.',
            LucideIcons.locate,
          );
        }

        final carPin = MapPins.car(location.lat, location.lng);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: 220,
                // Non-interactive — this map is inside the screen's
                // ListView, so pinch/pan here would fight page scrolling
                // (the same bug reported and fixed on Car Details' pickup
                // map). The expand button is the way to actually zoom in.
                child: Stack(
                  children: [
                    OsmMapView(center: carPin, interactive: false),
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullScreenMapScreen(title: 'Car Location', pin: carPin),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(LucideIcons.maximize, size: 20, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Rebuilds every 15 s on its own so "Updated 1m ago" and the
            // stale warning keep moving even when no new location arrives
            // (which is exactly when staleness matters).
            StreamBuilder<void>(
              stream: Stream<void>.periodic(const Duration(seconds: 15)),
              builder: (context, _) {
                final isStale = DateTime.now().difference(location.updatedAt) > TrackingConfig.staleAfter;
                final color = isStale ? AppColors.warning : AppColors.textMuted;
                return Row(
                  children: [
                    Icon(isStale ? LucideIcons.triangleAlert : LucideIcons.clock, color: color, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        isStale
                            ? "Out of date — last updated ${_timeAgo(location.updatedAt)}. The renter's app may be closed or offline."
                            : 'Updated ${_timeAgo(location.updatedAt)} · accurate to about ${location.accuracyM.round()} m',
                        style: AppTextStyles.caption.copyWith(color: color),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RentalEndedNotice extends StatelessWidget {
  const _RentalEndedNotice({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == BookingStatus.completed;
    final isReturnRequested = status == BookingStatus.returnRequested;

    final IconData icon;
    final Color color;
    final String message;
    if (isCompleted) {
      icon = LucideIcons.circleCheck;
      color = AppColors.success;
      message = 'This rental has been completed.';
    } else if (isReturnRequested) {
      icon = LucideIcons.hourglass;
      color = AppColors.statusPending;
      message = "You've marked the car as returned — waiting for the owner to confirm.";
    } else {
      icon = LucideIcons.info;
      color = AppColors.textMuted;
      message = 'This rental is no longer active.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(value, style: AppTextStyles.titleMedium),
      ],
    );
  }
}
