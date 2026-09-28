import 'package:flutter/material.dart';

/// Central color palette for CarRent — the "Obsidian Velocity" design
/// system.
///
/// Dark is the primary look: deep obsidian-navy surfaces, amber
/// (`#FFB800`) as the brand/primary action color, sky blue (`#38BDF8`) as
/// secondary, emerald (`#10B981`) as tertiary/success, and slate
/// (`#94A3B8`) as the neutral for secondary text. Light mode keeps the same
/// hues on slate-white surfaces.
///
/// Amber plays two roles, split into two tokens so both themes work:
/// [primary] is the *fill* (buttons, selected tabs/chips — always paired
/// with [onPrimary] text), and [accent] is amber used as *foreground*
/// (text, icons, selection outlines). In dark mode they're the same bright
/// amber; in light mode [accent] is a deeper amber, since bright amber text
/// or icons on white are too faint to read.
/// Keep all raw color values here — features should never hardcode a
/// Color literal, they should reference [AppColors].
///
/// Every field below is a getter that resolves against
/// [AppColors.brightness], so `AppColors.primary` (etc.) always returns the
/// color for whichever theme is active — feature code never branches on
/// brightness itself. [AppTheme] and [ThemeController] are the only two
/// places that touch [setBrightness].
class AppColors {
  AppColors._();

  static final ValueNotifier<Brightness> _brightnessNotifier = ValueNotifier(Brightness.dark);

  /// The brightness [AppColors] is currently resolving against. Set by the
  /// app root (via [ThemeController]) on every build, before any descendant
  /// widget reads a color — so by the time a widget's `build()` runs, the
  /// getters below already reflect the current theme.
  static Brightness get brightness => _brightnessNotifier.value;

  static void setBrightness(Brightness value) {
    if (_brightnessNotifier.value == value) return;
    _brightnessNotifier.value = value;
  }

  /// Notifies listeners on every brightness change. Feature widgets don't
  /// need to listen to this directly — the app root keys its whole routed
  /// subtree on brightness (see `main.dart`) so every screen gets fully
  /// remounted (and so re-reads [AppColors] fresh) on every theme change.
  static Listenable get listenable => _brightnessNotifier;

  static bool get _isDark => _brightnessNotifier.value == Brightness.dark;

  // Brand / primary action — amber *fills* (buttons, selected tabs/chips,
  // badges), always with [onPrimary] on top. Same bright amber in both
  // themes: it's the brand, and dark text on it reads well either way.
  static Color get primary => _isDark ? const Color(0xFFFFB800) : const Color(0xFFFFB300);
  static Color get primaryDark => _isDark ? const Color(0xFFE0A200) : const Color(0xFFE09E00);

  /// Amber as *foreground* — text, icons, links, prices, selection
  /// outlines. Equal to [primary] in dark mode; a deeper amber in light
  /// mode (~5:1 on white) so it stays readable.
  static Color get accent => _isDark ? const Color(0xFFFFB800) : const Color(0xFFB45309);

  /// Neutral raised tint behind an icon/badge sitting on a card — not an
  /// amber tint (that's [primarySoft]).
  static Color get primaryLight => _isDark ? const Color(0xFF1B2940) : const Color(0xFFF1F4F9);

  /// Translucent amber for "selected"/highlighted backgrounds (active
  /// category chip, amber badge fills) that shouldn't shout like a full
  /// [primary] fill.
  static Color get primarySoft => primary.withValues(alpha: _isDark ? 0.16 : 0.16);

  // Supporting hues from the design system.
  static Color get secondary => _isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  /// Text/icons on a [secondary] fill (e.g. the nav count badge).
  static Color get onSecondary => _isDark ? const Color(0xFF0A1322) : const Color(0xFFFFFFFF);
  static Color get tertiary => _isDark ? const Color(0xFF10B981) : const Color(0xFF059669);

  /// Fixed (not brightness-dependent) obsidian overlay — image scrims, the
  /// car-type badge on a photo, the snackbar surface. These sit on top of a
  /// photo or float above the app chrome, so they stay dark in both themes.
  static Color get navy => const Color(0xFF0A1322);

  // Fixed floating-surface colors (snackbars) — always the dark obsidian
  // look, so feedback toasts read the same in both themes.
  static Color get overlaySurface => const Color(0xFF16233A);
  static Color get overlayBorder => const Color(0xFF22324A);
  static Color get overlayText => const Color(0xFFE6EDF7);
  static Color get overlayAccent => const Color(0xFFFFB800);

  // Neutrals / surfaces
  static Color get background => _isDark ? const Color(0xFF0A1322) : const Color(0xFFF3F5F9);
  static Color get surface => _isDark ? const Color(0xFF111C2E) : const Color(0xFFFFFFFF);

  /// A step above [surface] — nested tiles inside a card (stat tiles,
  /// segmented-control track, menu icon wells).
  static Color get surfaceElevated => _isDark ? const Color(0xFF16233A) : const Color(0xFFF1F4F9);
  static Color get surfaceMuted => _isDark ? const Color(0xFF16233A) : const Color(0xFFEEF2F7);
  static Color get inputFill => _isDark ? const Color(0xFF142033) : const Color(0xFFF8FAFC);
  static Color get border => _isDark ? const Color(0xFF22324A) : const Color(0xFFE2E8F0);
  static Color get divider => _isDark ? const Color(0xFF1B2A40) : const Color(0xFFEDF1F6);

  // Text
  static Color get textPrimary => _isDark ? const Color(0xFFE6EDF7) : const Color(0xFF0F172A);
  static Color get textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get textMuted => _isDark ? const Color(0xFF64748B) : const Color(0xFF7C8BA1);
  static Color get onPrimary => const Color(0xFF1C1400);

  /// Cool blue-white used for display headlines in dark mode (the design
  /// system's "Headline" sample); plain [textPrimary] in light mode.
  static Color get headline => _isDark ? const Color(0xFFDCE8FF) : const Color(0xFF0F172A);

  // Status
  static Color get success => tertiary;
  static Color get successBg => _isDark ? const Color(0xFF0F2E2A) : const Color(0xFFE3F6EF);
  static Color get warning => _isDark ? const Color(0xFFFFB800) : const Color(0xFFB45309);
  static Color get warningBg => _isDark ? const Color(0xFF33280A) : const Color(0xFFFFF4DB);
  static Color get danger => _isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get dangerBg => _isDark ? const Color(0xFF3A1C24) : const Color(0xFFFDECEC);
  static Color get info => secondary;
  static Color get infoBg => _isDark ? const Color(0xFF0E2A40) : const Color(0xFFE5F4FC);

  /// Favorite heart — pinned to the danger hue rather than another red.
  static Color get heart => danger;

  // Third-party sign-in marks — fixed brand colors, same in both themes.
  static Color get googleBlue => const Color(0xFF4285F4);
  static Color get facebookBlue => const Color(0xFF1877F2);

  // Booking status colors (foreground/background pairs).
  static Color get statusPending => warning;
  static Color get statusPendingBg => warningBg;
  static Color get statusConfirmed => warning;
  static Color get statusConfirmedBg => warningBg;
  static Color get statusActive => info;
  static Color get statusActiveBg => infoBg;
  static Color get statusCompleted => success;
  static Color get statusCompletedBg => successBg;
  static Color get statusRejected => danger;
  static Color get statusRejectedBg => dangerBg;
  static Color get statusCancelled => danger;
  static Color get statusCancelledBg => dangerBg;

  // Misc
  static Color get star => _isDark ? const Color(0xFFFFB800) : const Color(0xFFD97706);
  static Color get shadow => _isDark ? const Color(0x66000000) : const Color(0x120F172A);

  /// Elevation for cards. Dark mode relies on 1px borders alone (a shadow
  /// is invisible on obsidian); light mode adds a soft, cool shadow so
  /// white cards lift off the pale background instead of looking flat.
  static List<BoxShadow> get cardShadow => _isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x080F172A), blurRadius: 3, offset: Offset(0, 1)),
        ];
}
