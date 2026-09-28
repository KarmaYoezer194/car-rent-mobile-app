import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/car_options.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/booking_model.dart';
import '../../../models/car_model.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../booking/screens/active_rental_screen.dart';
import '../../post_car/screens/post_car_screen.dart';

/// Profile → My Cars (Section 10): view/edit/delete/disable the cars this
/// user has posted, plus a "View Rental" link straight to the Active
/// Rental screen (Section 16) for anything currently rented.
class MyCarsScreen extends StatelessWidget {
  const MyCarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final carService = context.watch<CarService>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cars'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PostCarScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text('+ Add', style: TextStyle(color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: uid == null
          ? const EmptyStateWidget(icon: LucideIcons.car, message: AppStrings.noCarsPosted)
          : StreamBuilder<List<CarModel>>(
              stream: carService.streamCarsByOwner(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                if (snapshot.hasError) {
                  return const ErrorStateWidget(message: AppStrings.genericError);
                }
                final cars = snapshot.data ?? const [];
                if (cars.isEmpty) {
                  return const EmptyStateWidget(
                    icon: LucideIcons.car,
                    message: AppStrings.noCarsPosted,
                  );
                }
                final bookingService = context.watch<BookingService>();
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: cars.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            Text('${cars.length}', style: AppTextStyles.h3),
                            const SizedBox(width: 8),
                            Text('listed car${cars.length == 1 ? '' : 's'}', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      );
                    }
                    return Entrance(
                      delay: Entrance.staggerDelay(index - 1),
                      child: _MyCarTile(
                        car: cars[index - 1],
                        carService: carService,
                        bookingService: bookingService,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _MyCarTile extends StatelessWidget {
  const _MyCarTile({required this.car, required this.carService, required this.bookingService});

  final CarModel car;
  final CarService carService;
  final BookingService bookingService;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text('This removes ${car.title} permanently. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await carService.deleteCar(car.id);
      if (context.mounted) AppSnackbar.show(context, 'Listing deleted.');
    }
  }

  Future<void> _toggleDisabled(BuildContext context) async {
    final isDisabled = car.status == CarStatus.disabled;
    await carService.setCarStatus(car.id, isDisabled ? CarStatus.available : CarStatus.disabled);
    if (context.mounted) {
      AppSnackbar.show(context, isDisabled ? 'Listing re-enabled.' : 'Listing disabled.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRented = car.status == CarStatus.rented;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CachedImage(url: car.coverImage),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(car.title, style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      _StatusBadge(status: car.status),
                      const SizedBox(height: AppSpacing.xs),
                      Text(AppFormatters.pricePerDay(car.pricePerDay), style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isRented)
              StreamBuilder<BookingModel?>(
                stream: bookingService.streamActiveBookingForCar(car.id),
                builder: (context, snapshot) {
                  final booking = snapshot.data;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: booking == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ActiveRentalScreen(booking: booking)),
                              ),
                      child: const Text('View Rental'),
                    ),
                  );
                },
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _PillButton(
                      label: 'Edit',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PostCarScreen(existingCar: car)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillButton(
                      label: car.status == CarStatus.disabled ? 'Enable' : 'Disable',
                      onTap: () => _toggleDisabled(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillButton(
                      label: 'Delete',
                      onTap: () => _confirmDelete(context),
                      background: AppColors.dangerBg,
                      foreground: AppColors.danger,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      CarStatus.available => ('Available', AppColors.success, AppColors.successBg),
      CarStatus.rented => ('Currently rented', AppColors.statusActive, AppColors.statusActiveBg),
      CarStatus.disabled => ('Disabled', AppColors.textMuted, AppColors.surfaceMuted),
      _ => (status, AppColors.textMuted, AppColors.surfaceMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: foreground ?? AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
