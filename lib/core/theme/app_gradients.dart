import 'package:flutter/material.dart';

/// Monochrome gradient helpers used on top of photos — legibility scrims
/// and a frosted-glass fill for floating controls. Kept intentionally
/// small: the design system is deliberately gradient-free everywhere else
/// (flat fills + 1px borders, per [AppTheme]), since these are the only
/// places a gradient serves a functional purpose (fading a photo to black
/// so white text/icons stay legible) rather than a decorative one.
class AppGradients {
  AppGradients._();

  /// Subtle top-to-bottom scrim over a photo so white icons/text stay
  /// legible without darkening the whole image.
  static LinearGradient get imageScrimTop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
        stops: const [0, 0.5],
      );

  static LinearGradient get imageScrimBottom => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
        stops: const [0, 0.6],
      );

  /// Soft glass fill for frosted panels over photos (floating icon buttons,
  /// the 3D-preview toggle).
  static Color glass({double alpha = 0.16}) => Colors.white.withValues(alpha: alpha);
}
