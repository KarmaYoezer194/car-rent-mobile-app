import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/car_options.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/custom_button.dart';

/// Filter selection applied client-side to the already-fetched available
/// cars list (Section 7). Date-based availability filtering is deferred to
/// Phase 5, once bookings exist to check overlap against.
class CarFilters {
  const CarFilters({
    this.minPrice,
    this.maxPrice,
    this.types = const {},
    this.transmissions = const {},
    this.fuelTypes = const {},
  });

  final double? minPrice;
  final double? maxPrice;
  final Set<String> types;
  final Set<String> transmissions;
  final Set<String> fuelTypes;

  bool get isEmpty =>
      minPrice == null && maxPrice == null && types.isEmpty && transmissions.isEmpty && fuelTypes.isEmpty;

  int get activeCount =>
      (minPrice != null || maxPrice != null ? 1 : 0) + types.length + transmissions.length + fuelTypes.length;

  CarFilters copyWith({
    double? minPrice,
    double? maxPrice,
    bool clearPrice = false,
    Set<String>? types,
    Set<String>? transmissions,
    Set<String>? fuelTypes,
  }) {
    return CarFilters(
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      types: types ?? this.types,
      transmissions: transmissions ?? this.transmissions,
      fuelTypes: fuelTypes ?? this.fuelTypes,
    );
  }
}

/// Opens the filter modal and resolves to the user's chosen [CarFilters],
/// or null if they dismissed it without applying.
Future<CarFilters?> showCarFilterSheet(BuildContext context, CarFilters current) {
  return showModalBottomSheet<CarFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => _CarFilterSheet(initial: current),
  );
}

const double _maxPriceBound = 10000;

/// Turns what the user typed into the Min/Max price boxes into a valid
/// slider range: blank Min means 0, blank Max means no upper limit
/// ([bound]), anything outside 0..[bound] is clamped, and a Min above Max
/// is swapped rather than rejected.
@visibleForTesting
RangeValues resolveTypedPriceRange(String minText, String maxText, {double bound = _maxPriceBound}) {
  double parse(String text, double fallback) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? fallback : double.parse(digits).clamp(0, bound).toDouble();
  }

  final min = parse(minText, 0);
  final max = parse(maxText, bound);
  return min <= max ? RangeValues(min, max) : RangeValues(max, min);
}

class _CarFilterSheet extends StatefulWidget {
  const _CarFilterSheet({required this.initial});

  final CarFilters initial;

  @override
  State<_CarFilterSheet> createState() => _CarFilterSheetState();
}

class _CarFilterSheetState extends State<_CarFilterSheet> {
  late RangeValues _priceRange;
  late Set<String> _types;
  late Set<String> _transmissions;
  late Set<String> _fuelTypes;

  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(widget.initial.minPrice ?? 0, widget.initial.maxPrice ?? _maxPriceBound);
    _types = {...widget.initial.types};
    _transmissions = {...widget.initial.transmissions};
    _fuelTypes = {...widget.initial.fuelTypes};
    _syncPriceFields();
    // Tapping away from a box counts as submitting it, same as Enter.
    _minFocus.addListener(() => _minFocus.hasFocus ? null : _commitTypedPrice());
    _maxFocus.addListener(() => _maxFocus.hasFocus ? null : _commitTypedPrice());
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  /// Slider → boxes. The "no limit" ends show as blank (hint text) rather
  /// than 0 / 10000, so an untouched range reads as "any price".
  void _syncPriceFields() {
    _minController.text = _priceRange.start > 0 ? _priceRange.start.round().toString() : '';
    _maxController.text = _priceRange.end < _maxPriceBound ? _priceRange.end.round().toString() : '';
  }

  /// Boxes → slider. Also rewrites the boxes, so a clamped or swapped
  /// value visibly snaps to what will actually be applied.
  void _commitTypedPrice() {
    if (!mounted) return;
    setState(() {
      _priceRange = resolveTypedPriceRange(_minController.text, _maxController.text);
      _syncPriceFields();
    });
  }

  void _reset() {
    setState(() {
      _priceRange = const RangeValues(0, _maxPriceBound);
      _syncPriceFields();
      _types.clear();
      _transmissions.clear();
      _fuelTypes.clear();
    });
  }

  void _apply() {
    // Pick up a value typed but not yet submitted (e.g. typed, then tapped
    // straight on Show Results).
    _priceRange = resolveTypedPriceRange(_minController.text, _maxController.text);
    Navigator.of(context).pop(
      CarFilters(
        minPrice: _priceRange.start > 0 ? _priceRange.start : null,
        maxPrice: _priceRange.end < _maxPriceBound ? _priceRange.end : null,
        types: _types,
        transmissions: _transmissions,
        fuelTypes: _fuelTypes,
      ),
    );
  }

  /// Mirrors [CarFilters.activeCount] against the sheet's live (unsaved)
  /// selections, so the header badge and button label update as the user
  /// drags the slider or taps chips — before they've hit "Show Results".
  int get _activeCount =>
      (_priceRange.start > 0 || _priceRange.end < _maxPriceBound ? 1 : 0) +
      _types.length +
      _transmissions.length +
      _fuelTypes.length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.md,
          bottom: AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — signals "this sheet can be swiped down" before
              // the user even reads the title.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Filters', style: AppTextStyles.h2),
                      if (_activeCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$_activeCount',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _activeCount > 0 ? _reset : null,
                    icon: Icon(
                      LucideIcons.refreshCw,
                      size: 16,
                      color: _activeCount > 0 ? AppColors.accent : AppColors.textMuted,
                    ),
                    label: Text(
                      'Reset',
                      style: AppTextStyles.link.copyWith(
                        color: _activeCount > 0 ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price per day', style: AppTextStyles.titleMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${AppFormatters.currency(_priceRange.start)} – '
                      '${_priceRange.end >= _maxPriceBound ? '${AppFormatters.currency(_maxPriceBound)}+' : AppFormatters.currency(_priceRange.end)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.divider,
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 9, elevation: 2),
                ),
                child: RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: _maxPriceBound,
                  divisions: 20,
                  labels: RangeLabels(
                    AppFormatters.currency(_priceRange.start),
                    _priceRange.end >= _maxPriceBound
                        ? '${AppFormatters.currency(_maxPriceBound)}+'
                        : AppFormatters.currency(_priceRange.end),
                  ),
                  onChanged: (values) => setState(() {
                    _priceRange = values;
                    _syncPriceFields();
                  }),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _PriceField(
                      label: 'Min',
                      hint: '0',
                      controller: _minController,
                      focusNode: _minFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        _commitTypedPrice();
                        _maxFocus.requestFocus();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('–', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: _PriceField(
                      label: 'Max',
                      hint: 'No limit',
                      controller: _maxController,
                      focusNode: _maxFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commitTypedPrice(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SizedBox(height: AppSpacing.xs),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text('Car type', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _ChipGroup(
                options: CarOptions.types,
                selected: _types,
                onChanged: (value) => setState(() => _types = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text('Transmission', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _ChipGroup(
                options: CarOptions.transmissions,
                selected: _transmissions,
                onChanged: (value) => setState(() => _transmissions = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text('Fuel type', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _ChipGroup(
                options: CarOptions.fuelTypes,
                selected: _fuelTypes,
                onChanged: (value) => setState(() => _fuelTypes = value),
              ),
              const SizedBox(height: AppSpacing.xxl),
              CustomButton(
                label: _activeCount > 0 ? 'Show Results ($_activeCount)' : 'Show Results',
                onPressed: _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
      onSubmitted: onSubmitted,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: '฿ ',
        isDense: true,
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.options, required this.selected, required this.onChanged});

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(
            option,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? AppColors.accent : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: isSelected,
          onSelected: (value) {
            final next = {...selected};
            value ? next.add(option) : next.remove(option);
            onChanged(next);
          },
          backgroundColor: AppColors.surfaceMuted,
          selectedColor: AppColors.primaryLight,
          checkmarkColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: BorderSide(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.5) : Colors.transparent,
              width: 1.2,
            ),
          ),
        );
      }).toList(),
    );
  }
}
