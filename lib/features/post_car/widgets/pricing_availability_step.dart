import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../widgets/custom_text_field.dart';
import '../models/car_draft.dart';

/// Step 3 — Pricing & Availability (Section 9). The date range collected
/// here is the owner-defined window bookings are checked against once
/// Phase 5 adds booking creation.
class PricingAvailabilityStep extends StatefulWidget {
  const PricingAvailabilityStep({super.key, required this.draft, required this.onChanged});

  final CarDraft draft;
  final VoidCallback onChanged;

  @override
  State<PricingAvailabilityStep> createState() => _PricingAvailabilityStepState();
}

class _PricingAvailabilityStepState extends State<PricingAvailabilityStep> {
  late final _priceController =
      TextEditingController(text: widget.draft.pricePerDay?.toStringAsFixed(0) ?? '');
  final _dateFormat = DateFormat('EEE, MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    widget.draft.availableFrom ??= DateTime.now();
    widget.draft.availableUntil ??= DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? widget.draft.availableFrom! : widget.draft.availableUntil!;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        widget.draft.availableFrom = picked;
        if (widget.draft.availableUntil!.isBefore(picked)) {
          widget.draft.availableUntil = picked.add(const Duration(days: 1));
        }
      } else {
        if (picked.isBefore(widget.draft.availableFrom!)) {
          AppSnackbar.show(context, 'End date must be after the start date.');
          return;
        }
        widget.draft.availableUntil = picked;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set your price and availability', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xl),
          CustomTextField(
            label: 'Price per day (฿)',
            hint: 'e.g. 1500',
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: LucideIcons.banknote,
            onChanged: (value) {
              widget.draft.pricePerDay = double.tryParse(value);
              widget.onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Available from', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _DateTile(
            date: _dateFormat.format(widget.draft.availableFrom!),
            onTap: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Available until', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _DateTile(
            date: _dateFormat.format(widget.draft.availableUntil!),
            onTap: () => _pickDate(isStart: false),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onTap});

  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(LucideIcons.calendar, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(date, style: AppTextStyles.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
