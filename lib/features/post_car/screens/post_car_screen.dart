import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../models/car_model.dart';
import '../../../widgets/brand_header.dart';
import '../../../widgets/custom_button.dart';
import '../models/car_draft.dart';
import '../widgets/car_info_step.dart';
import '../widgets/location_step.dart';
import '../widgets/photos_step.dart';
import '../widgets/preview_step.dart';
import '../widgets/pricing_availability_step.dart';
import '../widgets/step_indicator.dart';

const _stepLabels = ['Photos', 'Car Info', 'Pricing', 'Location', 'Preview'];

/// The Post Car flow (Section 9): a 5-step wizard rather than one long
/// form. Also doubles as the Edit flow for My Cars (Section 10) — pass
/// [existingCar] to pre-fill and switch the final action to "Save Changes".
class PostCarScreen extends StatefulWidget {
  const PostCarScreen({super.key, this.existingCar});

  final CarModel? existingCar;

  @override
  State<PostCarScreen> createState() => _PostCarScreenState();
}

class _PostCarScreenState extends State<PostCarScreen> {
  final _pageController = PageController();
  late CarDraft _draft = widget.existingCar != null ? CarDraft.fromCar(widget.existingCar!) : CarDraft();

  int _step = 0;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingCar != null;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _canAdvanceFrom(int step) {
    switch (step) {
      case 0:
        return _draft.hasPhotos;
      case 1:
        return _draft.isCarInfoValid;
      case 2:
        return _draft.isPricingValid;
      case 3:
        return _draft.isLocationValid;
      default:
        return true;
    }
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
  }

  void _next() {
    if (!_canAdvanceFrom(_step)) {
      AppSnackbar.show(context, _incompleteMessageFor(_step));
      return;
    }
    if (_step < _stepLabels.length - 1) _goToStep(_step + 1);
  }

  void _back() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      // Reached via the bottom-nav Post tab, which is the root of its own
      // shell branch — there's nothing to pop here, so send the user Home.
      context.go('/home');
    }
  }

  String _incompleteMessageFor(int step) {
    switch (step) {
      case 0:
        return 'Add at least one photo to continue.';
      case 1:
        return 'Fill in brand, model, year, type, transmission, fuel type, and a short description.';
      case 2:
        return 'Set a price per day and a valid availability window.';
      case 3:
        return 'Set the pickup location and address to continue.';
      default:
        return 'Please complete this step.';
    }
  }

  Future<void> _submit() async {
    final authService = context.read<AuthService>();
    final carService = context.read<CarService>();
    final uid = authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await carService.updateCar(widget.existingCar!.id, {
          ...(_draft.toCarModel(
            id: widget.existingCar!.id,
            ownerId: uid,
            status: widget.existingCar!.status,
            rating: widget.existingCar!.rating,
            reviewCount: widget.existingCar!.reviewCount,
            createdAt: widget.existingCar!.createdAt,
          ).toMap()),
        });
        if (mounted) AppSnackbar.show(context, 'Listing updated.');
      } else {
        await carService.createCar(
          _draft.toCarModel(id: '', ownerId: uid, createdAt: DateTime.now()),
        );
        if (mounted) AppSnackbar.show(context, 'Your car is live!');
      }
      if (mounted) {
        // Editing always got here via a pushed MaterialPageRoute (My Cars ->
        // Edit), so popping is safe. A new post is created straight from the
        // Post tab, which is the *root* of that tab's own navigator — there
        // is nothing to pop there, and go_router throws if you try. Instead,
        // reset the wizard back to a blank step 1 so the user lands on the
        // Post page again, ready to list another car.
        if (_isEditing) {
          context.pop();
        } else {
          setState(() {
            _draft = CarDraft();
            _step = 0;
          });
          _pageController.jumpToPage(0);
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final uid = authService.currentUser?.uid ?? '';
    final isLastStep = _step == _stepLabels.length - 1;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandHeader(subtitle: _isEditing ? 'Edit Listing' : 'Post Car'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _back,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(LucideIcons.chevronLeft, size: 16, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                          // Expanded + ellipsis so a narrow window (e.g. web
                          // with DevTools docked) truncates the title instead
                          // of overflowing the row.
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _isEditing ? 'Edit listing' : 'Post your car',
                                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(
                                    'Step ${_step + 1} of ${_stepLabels.length} • ${_stepLabels[_step]}',
                                    key: ValueKey(_step),
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              _isEditing ? 'Editing' : 'Draft',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StepIndicator(stepCount: _stepLabels.length, currentStep: _step),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.sm),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  PhotosStep(
                    images: _draft.images,
                    ownerId: uid,
                    imageUploadService: context.watch<ImageUploadService>(),
                    onChanged: (images) => setState(() => _draft.images = images),
                  ),
                  CarInfoStep(draft: _draft, onChanged: () => setState(() {})),
                  PricingAvailabilityStep(draft: _draft, onChanged: () => setState(() {})),
                  LocationStep(draft: _draft, onChanged: () => setState(() {})),
                  PreviewStep(draft: _draft),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
              child: CustomButton(
                label: isLastStep
                    ? (_isEditing ? 'Save Changes' : 'Publish Car')
                    : 'Next: ${_stepLabels[_step + 1]}',
                icon: isLastStep ? null : LucideIcons.arrowRight,
                iconAfterLabel: true,
                isLoading: _isSubmitting,
                onPressed: isLastStep ? _submit : _next,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
