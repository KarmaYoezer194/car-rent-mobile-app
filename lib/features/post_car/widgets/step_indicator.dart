import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// Segmented progress bar at the top of the Post Car wizard, so the 5-step
/// form (Section 9) never feels like "one long form". Done and current
/// steps are amber; the current one is a touch taller with a soft glow.
/// (The "Step N of 5 • Label" text lives in the wizard's header.)
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.stepCount, required this.currentStep});

  final int stepCount;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${currentStep + 1} of $stepCount',
      child: SizedBox(
        height: 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(stepCount, (index) {
            final isDone = index < currentStep;
            final isActive = index == currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.only(right: index == stepCount - 1 ? 0 : AppSpacing.xs),
                height: isActive ? 6 : 4,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : isDone
                          ? AppColors.primary.withValues(alpha: 0.55)
                          : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)]
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
