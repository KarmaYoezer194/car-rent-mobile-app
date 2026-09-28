import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// CarRent's typography system — Plus Jakarta Sans, and only Plus Jakarta
/// Sans, everywhere (the "Obsidian Velocity" design system).
///
/// Kept as a plain class (not a TextTheme extension) so any widget can do
/// `AppTextStyles.h1` without threading BuildContext through everywhere.
/// Hierarchy comes entirely from weight and size, never from switching
/// families: brand/logo moments get ExtraBold (800), screen titles get
/// Bold (700), section headers and car names get SemiBold (600), buttons
/// get SemiBold (600), and body/secondary text stays Regular/Medium
/// (400/500) so the reading experience never feels shouty — that's what
/// keeps the app reading as premium-automotive rather than a generic form.
///
/// Every style below is a getter, not a cached field — [AppColors] resolves
/// differently per theme brightness, so these must be re-evaluated on every
/// access rather than computed once and reused.
///
/// This is the *only* place that should call `GoogleFonts.plusJakartaSans()` — screens
/// reference the named styles below instead of reaching for GoogleFonts (or
/// any other family) directly, so the whole app is guaranteed to share one
/// typography system. The font itself is bundled as an asset (see
/// pubspec.yaml) with `GoogleFonts.config.allowRuntimeFetching = false` set
/// in main.dart, so these calls resolve to the bundled font instead of
/// racing a network fetch to Google's CDN on first use.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Brand / logo — Bold is the heaviest weight anywhere in the type scale
  // (the spec's own rule: "avoid excessive bold text" — nothing goes past
  // Bold, not even the wordmark).
  static TextStyle get brand => _base(size: 30, weight: FontWeight.w700, height: 1.1, letterSpacing: -1);

  // Hero title (30–34/Bold) — "Find Your Perfect Car", welcome screens.
  static TextStyle get h1 => _base(size: 32, weight: FontWeight.w700, height: 1.15, letterSpacing: -0.6);

  // Screen title (24–28/Semibold) — "Available Cars", step headers, sheet
  // headers.
  static TextStyle get h2 => _base(size: 26, weight: FontWeight.w600, height: 1.25, letterSpacing: -0.4);

  // A notch below h2 for nested sub-section headers ("Description",
  // "Reviews", stat numbers) — same SemiBold family, smaller size.
  static TextStyle get h3 => _base(size: 17, weight: FontWeight.w600, height: 1.3, letterSpacing: -0.3);

  // Body text — descriptions, instructions, general copy.
  static TextStyle get bodyLarge => _base(size: 15.5, weight: FontWeight.w400, height: 1.5);
  static TextStyle get bodyMedium => _base(size: 14, weight: FontWeight.w400, height: 1.5);

  // Secondary text (12–14/Regular) — locations, timestamps, metadata.
  static TextStyle get bodySmall => _base(
    size: 13,
    weight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );
  // Caption/metadata (10–12/Regular).
  static TextStyle get caption => _base(size: 12, weight: FontWeight.w400, color: AppColors.textMuted);

  // Car names / list item titles.
  static TextStyle get titleMedium => _base(size: 17, weight: FontWeight.w600, letterSpacing: -0.2);

  // Form field labels.
  static TextStyle get labelLarge => _base(size: 13.5, weight: FontWeight.w500, color: AppColors.textSecondary);

  // Price emphasis — always prominent, never louder than Bold.
  static TextStyle get priceLarge => _base(size: 21, weight: FontWeight.w700, color: AppColors.accent, letterSpacing: -0.4);
  static TextStyle get priceMedium => _base(size: 18, weight: FontWeight.w700, color: AppColors.accent, letterSpacing: -0.3);

  // Buttons — SemiBold, not Bold: prominent without shouting.
  static TextStyle get button => _base(size: 15.5, weight: FontWeight.w600, color: AppColors.onPrimary);

  /// Standalone text links — "Forgot password?", "Register", "See all" —
  /// distinct from [labelLarge] which is reserved for form field labels.
  static TextStyle get link => _base(size: 13.5, weight: FontWeight.w600, color: AppColors.accent);
}
