import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/car_options.dart';
import '../../../core/services/vin_decoder_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/custom_text_field.dart';
import '../models/car_draft.dart';

/// Step 2 — Car Information (Section 9).
///
/// Starts with an optional VIN: when the owner leaves that field (or presses
/// Next), it's decoded with NHTSA vPIC ([VinDecoderService]) and make /
/// model / year are auto-filled — only into fields that are empty or still
/// hold a previous auto-fill, and always editable. A failed or partial
/// decode shows a warning and never blocks the step.
class CarInfoStep extends StatefulWidget {
  const CarInfoStep({super.key, required this.draft, required this.onChanged});

  final CarDraft draft;
  final VoidCallback onChanged;

  @override
  State<CarInfoStep> createState() => _CarInfoStepState();
}

class _CarInfoStepState extends State<CarInfoStep> {
  late final _brandController = TextEditingController(text: widget.draft.brand);
  late final _modelController = TextEditingController(text: widget.draft.model);
  late final _yearController = TextEditingController(text: widget.draft.year?.toString() ?? '');
  late final _descriptionController = TextEditingController(text: widget.draft.description);
  late final _seatsController = TextEditingController(text: widget.draft.seats.toString());
  late final _vinController = TextEditingController(text: widget.draft.vin);

  /// VIN most recently sent for decoding — blurring the field again without
  /// changing it doesn't re-call the API.
  late String? _lastDecodedVin = widget.draft.vinDecode?.vin;

  /// Bumped on every new decode and every VIN edit; a response whose number
  /// no longer matches arrived for an outdated VIN and is dropped.
  int _decodeSeq = 0;
  bool _checkingVin = false;

  /// What auto-fill last wrote into each field. A field is only ever
  /// overwritten by a later decode if it's empty or still holds exactly
  /// what auto-fill put there — never something the owner typed.
  String? _filledBrand;
  String? _filledModel;
  String? _filledYear;

  /// Briefly tints the brand/model/year fields after auto-fill so the
  /// owner notices they changed.
  bool _flashFilled = false;

  void _onVinChanged(String value) {
    widget.draft.vin = value;
    final vin = VinDecoderService.normalize(value);
    if (vin != _lastDecodedVin) {
      // Any in-flight decode is now for an outdated VIN.
      _decodeSeq++;
      _lastDecodedVin = null;
      setState(() {
        _checkingVin = false;
        widget.draft.vinDecode = null;
      });
    }
    widget.onChanged();
  }

  Future<void> _decodeVin() async {
    final vin = VinDecoderService.normalize(_vinController.text);
    if (vin.isEmpty || vin == _lastDecodedVin) return;
    _lastDecodedVin = vin;
    final seq = ++_decodeSeq;
    setState(() => _checkingVin = true);

    final result = await context.read<VinDecoderService>().decode(vin);
    if (!mounted || seq != _decodeSeq) return;

    setState(() {
      _checkingVin = false;
      widget.draft.vinDecode = result;
      if (result.hasVehicleData) _autofill(result);
    });
    widget.onChanged();
  }

  void _autofill(VinDecodeResult result) {
    bool canFill(TextEditingController c, String? lastFilled) => c.text.trim().isEmpty || c.text == lastFilled;
    var filledAny = false;

    if (result.make.isNotEmpty && canFill(_brandController, _filledBrand)) {
      _brandController.text = widget.draft.brand = _filledBrand = result.make;
      filledAny = true;
    }
    if (result.model.isNotEmpty && canFill(_modelController, _filledModel)) {
      _modelController.text = widget.draft.model = _filledModel = result.model;
      filledAny = true;
    }
    if (result.year != null && canFill(_yearController, _filledYear)) {
      _yearController.text = _filledYear = '${result.year}';
      widget.draft.year = result.year;
      filledAny = true;
    }

    if (filledAny) {
      _flashFilled = true;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _flashFilled = false);
      });
    }
  }

  Widget? _vinSuffix() {
    final decode = widget.draft.vinDecode;
    if (_checkingVin) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (decode == null) return null;
    return widget.draft.vinVerified
        ? Icon(LucideIcons.badgeCheck, color: AppColors.success)
        : Icon(LucideIcons.triangleAlert, color: AppColors.warning);
  }

  Widget _vinStatus() {
    final decode = widget.draft.vinDecode;
    final IconData icon;
    final Color color;
    final String text;

    if (_checkingVin) {
      icon = LucideIcons.search;
      color = AppColors.textMuted;
      text = 'Checking VIN…';
    } else if (decode == null) {
      icon = LucideIcons.info;
      color = AppColors.textMuted;
      text = "Optional. If we can verify it, we'll fill in the make, model and year for you.";
    } else if (widget.draft.vinVerified) {
      icon = LucideIcons.circleCheck;
      color = AppColors.success;
      text = 'Verified: ${decode.year} ${decode.make} ${decode.model} — details filled in below.';
    } else if (decode.status == VinDecodeStatus.verified) {
      icon = LucideIcons.triangleAlert;
      color = AppColors.warning;
      text = "The make, model or year below no longer match this VIN, so it won't show as verified.";
    } else if (decode.status == VinDecodeStatus.partial) {
      icon = LucideIcons.triangleAlert;
      color = AppColors.warning;
      text = 'VIN may be incorrect (${decode.problem}). We filled in what we could — please double-check.';
    } else if (!VinDecoderService.isWellFormed(decode.vin)) {
      icon = LucideIcons.triangleAlert;
      color = AppColors.warning;
      text =
          'VIN could not be verified — a VIN is 17 letters and numbers (no I, O or Q). '
          'Enter the make, model and year yourself.';
    } else {
      icon = LucideIcons.triangleAlert;
      color = AppColors.warning;
      text = 'VIN could not be verified. Enter the make, model and year yourself.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: AppTextStyles.caption.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _seatsController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us about your car', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xl),
          CustomTextField(
            label: 'VIN (optional)',
            hint: '17 characters, e.g. 1HGCM82633A004352',
            controller: _vinController,
            textCapitalization: TextCapitalization.characters,
            enableSpellCheck: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(17),
              _UpperCaseFormatter(),
            ],
            suffixIcon: _vinSuffix(),
            onChanged: _onVinChanged,
            // Decode "on blur" — when the owner moves on to the next field —
            // or when they press Next on the keyboard.
            onFocusChange: (hasFocus) {
              if (!hasFocus) _decodeVin();
            },
            onFieldSubmitted: (_) => _decodeVin(),
          ),
          _vinStatus(),
          const SizedBox(height: AppSpacing.lg),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _flashFilled ? AppColors.successBg : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Brand',
                        hint: 'Toyota',
                        controller: _brandController,
                        inputFormatters: [CapitalizeWordsFormatter()],
                        onChanged: (value) {
                          widget.draft.brand = value;
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: CustomTextField(
                        label: 'Model',
                        hint: 'Camry',
                        controller: _modelController,
                        inputFormatters: [CapitalizeWordsFormatter()],
                        onChanged: (value) {
                          widget.draft.model = value;
                          widget.onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Year',
                        hint: 'e.g. 2022',
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          widget.draft.year = int.tryParse(value);
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: CustomTextField(
                        label: 'Seats',
                        hint: '5',
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          widget.draft.seats = int.tryParse(value) ?? widget.draft.seats;
                          widget.onChanged();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChoiceSection(
            label: 'Car type',
            options: CarOptions.types,
            selected: widget.draft.type,
            onSelected: (value) {
              setState(() => widget.draft.type = value);
              widget.onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChoiceSection(
            label: 'Transmission',
            options: CarOptions.transmissions,
            selected: widget.draft.transmission,
            onSelected: (value) {
              setState(() => widget.draft.transmission = value);
              widget.onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChoiceSection(
            label: 'Fuel type',
            options: CarOptions.fuelTypes,
            selected: widget.draft.fuelType,
            onSelected: (value) {
              setState(() => widget.draft.fuelType = value);
              widget.onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Air conditioning', style: AppTextStyles.titleMedium),
              Switch(
                value: widget.draft.airConditioning,
                onChanged: (value) {
                  setState(() => widget.draft.airConditioning = value);
                  widget.onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomTextField(
            label: 'Description',
            hint: 'What makes your car great to rent?',
            controller: _descriptionController,
            maxLines: 4,
            inputFormatters: [CapitalizeSentencesFormatter()],
            onChanged: (value) {
              widget.draft.description = value;
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({required this.label, required this.options, required this.selected, required this.onSelected});

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((option) {
            final isSelected = selected == option;
            return AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: ChoiceChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: AppColors.primaryLight,
                // Explicit label color: the theme's selected-chip label is
                // `onPrimary` (meant for a `primary` fill), which is
                // invisible on this `primaryLight` fill in both themes.
                labelStyle: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onSelected(option),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Uppercases as the owner types, so the VIN field always shows the
/// canonical form (VINs are case-insensitive but written in capitals).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
