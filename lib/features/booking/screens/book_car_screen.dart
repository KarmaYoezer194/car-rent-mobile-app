import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/car_model.dart';
import '../../../widgets/custom_button.dart';

/// Date selection + confirmation for renting [car] (Section 9's "Rent Now"
/// flow). Reached from Car Details; [BookingService.createBooking] does the
/// actual availability/overlap check once the renter confirms.
class BookCarScreen extends StatefulWidget {
  const BookCarScreen({super.key, required this.car});

  final CarModel car;

  @override
  State<BookCarScreen> createState() => _BookCarScreenState();
}

class _BookCarScreenState extends State<BookCarScreen> {
  static final _dateFormat = DateFormat('EEE, d MMM');

  DateTimeRange? _range;
  bool _isSubmitting = false;

  DateTime get _firstSelectable {
    final earliest = DateTime.now();
    final availableFrom = widget.car.availableFrom;
    return availableFrom != null && availableFrom.isAfter(earliest) ? availableFrom : earliest;
  }

  DateTime get _lastSelectable {
    return widget.car.availableUntil ?? DateTime.now().add(const Duration(days: 365));
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _firstSelectable,
      lastDate: _lastSelectable,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _confirm() async {
    final range = _range;
    if (range == null) {
      AppSnackbar.show(context, 'Pick your rental dates to continue.');
      return;
    }

    final authService = context.read<AuthService>();
    final bookingService = context.read<BookingService>();
    final renterId = authService.currentUser?.uid;
    if (renterId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await bookingService.createBooking(
        car: widget.car,
        renterId: renterId,
        start: range.start,
        // showDateRangePicker returns end as the last selected calendar day
        // at midnight — treat the rental as ending the following midnight
        // so a same-day-back range still books at least 1 day.
        end: range.end.add(const Duration(days: 1)),
      );
      if (mounted) {
        AppSnackbar.show(context, 'Booking request sent! The owner will confirm shortly.');
        context.pop();
      }
    } on BookingUnavailableException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final days = range == null ? 0 : range.end.difference(range.start).inDays + 1;
    final total = days * widget.car.pricePerDay;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () => context.pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(LucideIcons.chevronLeft, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text('Select dates', style: AppTextStyles.h3),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: _DateBox(
                            label: 'Pickup date',
                            value: range == null ? 'Choose date' : _dateFormat.format(range.start),
                            highlighted: true,
                            onTap: _pickRange,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _DateBox(
                            label: 'Return date',
                            value: range == null ? 'Choose date' : _dateFormat.format(range.end),
                            highlighted: false,
                            onTap: _pickRange,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 340.ms).moveY(begin: 14, end: 0, duration: 340.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.car.title, style: AppTextStyles.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          _SummaryRow(
                            label: 'Rental days',
                            value: days == 0 ? '—' : '$days day${days == 1 ? '' : 's'}',
                          ),
                          _SummaryRow(label: 'Price per day', value: AppFormatters.currency(widget.car.pricePerDay)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Estimated total', style: AppTextStyles.titleMedium),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(scale: animation, child: child),
                                ),
                                child: Text(
                                  AppFormatters.currency(total),
                                  key: ValueKey(total),
                                  style: AppTextStyles.priceLarge,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 340.ms).moveY(begin: 14, end: 0, delay: 100.ms, duration: 340.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        'The owner has 12 hours to accept. You are not charged until the request is confirmed.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.info, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: CustomButton(
                label: 'Send Booking Request',
                isLoading: _isSubmitting,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.value, required this.highlighted, required this.onTap});

  final String label;
  final String value;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: highlighted ? AppColors.accent : AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelLarge),
              const SizedBox(height: 5),
              Text(value, style: AppTextStyles.titleMedium.copyWith(fontSize: 15.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
