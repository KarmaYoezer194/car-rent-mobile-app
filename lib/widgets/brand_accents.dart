import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/motion/entrance.dart';

/// The hero call-to-action of the onboarding and auth screens: an amber
/// gradient with a soft amber glow, a trailing arrow, and its own loading
/// spinner. (Everyday screens use the flat [CustomButton].)
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon = LucideIcons.arrowRight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final glowing = _hovered && enabled;

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.onPressed == null ? 0.5 : 1,
      // The glow brightens and spreads on hover.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: glowing ? 0.92 : 0.78)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: glowing ? 0.55 : 0.35),
              blurRadius: glowing ? 32 : 22,
              offset: Offset(0, glowing ? 12 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? widget.onPressed : null,
            mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onHover: (hovering) => setState(() => _hovered = hovering),
            child: Center(
              // Label <-> spinner crossfade on submit.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
                ),
                child: widget.isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.label, style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800)),
                          if (widget.icon != null) ...[
                            const SizedBox(width: 8),
                            // The arrow nudges forward on hover.
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              offset: Offset(glowing ? 0.25 : 0, 0),
                              child: Icon(widget.icon, size: 20, color: AppColors.onPrimary),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: widget.label,
      child: enabled ? PressFeedback(scale: 0.97, child: button) : button,
    );
  }
}

/// Display headline in two tones: [lead] in the cool headline gradient,
/// then [highlight] in amber — "Welcome / back."
class TwoToneHeadline extends StatelessWidget {
  const TwoToneHeadline({
    super.key,
    required this.lead,
    required this.highlight,
    this.fontSize = 30,
    this.textAlign = TextAlign.start,
  });

  final String lead;
  final String highlight;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.h1.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.2);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.headline, AppColors.secondary.withValues(alpha: 0.9)],
              ).createShader(bounds),
              child: Text(lead, style: style),
            ),
          ),
          TextSpan(text: highlight, style: style.copyWith(color: AppColors.accent)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
