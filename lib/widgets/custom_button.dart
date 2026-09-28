import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/motion/entrance.dart';

/// Primary/secondary button used everywhere an action needs to look like
/// "the obvious thing to do on this screen" (Section 28, rule 12).
///
/// Handles its own loading spinner so callers don't have to juggle a
/// separate loading widget next to the button. Filled buttons are the
/// design system's amber primary (see AppTheme); outlined ones sit on the
/// surface with a 1px border. A light press-scale (via [PressFeedback]) is
/// the only feedback beyond the platform ripple.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.iconAfterLabel = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;

  /// Puts [icon] after the label ("Next: Car Info →") instead of before it.
  final bool iconAfterLabel;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isLoading || onPressed == null;

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              // Outlined buttons sit on the surface, not amber.
              valueColor: AlwaysStoppedAnimation<Color>(isOutlined ? AppColors.textPrimary : AppColors.onPrimary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null && !iconAfterLabel) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: isOutlined ? AppTextStyles.button.copyWith(color: AppColors.textPrimary) : null,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null && iconAfterLabel) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 20),
              ],
            ],
          );

    // Label <-> spinner crossfade instead of a pop.
    final animatedChild = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(isLoading), child: child),
    );

    // While loading, the button keeps its normal (amber) look and simply
    // ignores taps — disabling it would flash it grey on every submit.
    final VoidCallback? handler = onPressed == null ? null : (isLoading ? () {} : onPressed);
    final button = isOutlined
        ? OutlinedButton(onPressed: handler, child: animatedChild)
        : ElevatedButton(onPressed: handler, child: animatedChild);

    final sized = expand ? SizedBox(width: double.infinity, child: button) : button;
    return disabled ? sized : PressFeedback(scale: 0.97, child: sized);
  }
}
