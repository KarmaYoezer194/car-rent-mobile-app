import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../router/page_transitions.dart';
import 'app_text_styles.dart';

/// The single source of truth for how CarRent looks.
///
/// "Obsidian Velocity": a dark-first system — obsidian-navy surfaces with
/// 1px borders, amber (`AppColors.primary`) for the primary action and
/// selected states, sky blue / emerald as supporting hues, slate for
/// secondary text, and Plus Jakarta Sans throughout. Light mode keeps the
/// same structure on slate-white surfaces.
///
/// [of] builds a [ThemeData] for the given [Brightness] by first pointing
/// [AppColors] at that brightness, then reading its getters — so this is
/// the *only* place that needs to know both palettes exist. Every widget
/// elsewhere just calls `AppColors.x` / `AppTextStyles.x` and gets whichever
/// theme is current.
class AppTheme {
  AppTheme._();

  static ThemeData light() => of(Brightness.light);

  static ThemeData dark() => of(Brightness.dark);

  static ThemeData of(Brightness brightness) {
    AppColors.setBrightness(brightness);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      primaryContainer: AppColors.primary,
      onPrimaryContainer: AppColors.onPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.bodyMedium.fontFamily,
      splashFactory: InkRipple.splashFactory,

      // Hover/press/focus washes for every InkWell/IconButton/ListTile —
      // subtle, and tinted with the text color so they work on any surface.
      hoverColor: AppColors.textPrimary.withValues(alpha: 0.05),
      highlightColor: AppColors.textPrimary.withValues(alpha: 0.06),
      splashColor: AppColors.primary.withValues(alpha: 0.14),
      focusColor: AppColors.primary.withValues(alpha: 0.14),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return AppColors.primary.withValues(alpha: 0.18);
            if (states.contains(WidgetState.hovered)) return AppColors.textPrimary.withValues(alpha: 0.08);
            return null;
          }),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      // One page transition for every MaterialPageRoute push (see
      // AppMotion). iOS/macOS keep the native Cupertino slide and its
      // back-swipe gesture.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),

      // Standard card, per spec: white/surface fill, a 1px border rather
      // than elevation, 16px radius, no heavy shadow.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.onPrimary : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceElevated,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : AppColors.border,
        ),
      ),

      // Primary button: flat near-black fill, white text, no gloss/gradient
      // — one dominant CTA per screen, and it should read as ink, not a
      // colored accent.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(54),
          textStyle: AppTextStyles.button,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          // Hover: a touch lighter and lifted with a soft amber glow;
          // pressed: a slightly deeper tint. Animated, not snapped.
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return AppColors.onPrimary.withValues(alpha: 0.12);
            if (states.contains(WidgetState.hovered)) return AppColors.overlayText.withValues(alpha: 0.18);
            if (states.contains(WidgetState.focused)) return AppColors.onPrimary.withValues(alpha: 0.10);
            return null;
          }),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered) && !states.contains(WidgetState.pressed) ? 6 : 0,
          ),
          shadowColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.45)),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      // Secondary button: white fill, thin border, black text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: AppColors.border, width: 1),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          // Hover: border turns amber and the fill picks up a faint tint.
          animationDuration: const Duration(milliseconds: 180),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                  ? AppColors.accent
                  : AppColors.border,
              width: 1,
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return AppColors.primary.withValues(alpha: 0.16);
            if (states.contains(WidgetState.hovered)) return AppColors.primary.withValues(alpha: 0.08);
            return null;
          }),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppTextStyles.link,
        ).copyWith(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return AppColors.primary.withValues(alpha: 0.18);
            if (states.contains(WidgetState.hovered)) return AppColors.primary.withValues(alpha: 0.10);
            return null;
          }),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // Filter chips: pill-shaped is the one place the spec allows it.
      // Unselected: white/bordered/gray text. Selected: solid black/white.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: AppColors.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),

      // Bottom nav: white, minimal line icons, black active / gray
      // inactive, no filled/colored container behind the active item, a
      // hairline top divider instead of elevation (added on the
      // Container that wraps this in AppShell).
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
        unselectedLabelStyle: AppTextStyles.caption,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),

      snackBarTheme: SnackBarThemeData(
        // Fixed overlay colors (not theme-flipping) — a floating toast
        // keeps the obsidian look in both themes.
        backgroundColor: AppColors.overlaySurface,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.overlayText),
        actionTextColor: AppColors.overlayAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.overlayBorder),
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        titleMedium: AppTextStyles.titleMedium,
        labelLarge: AppTextStyles.labelLarge,
      ),
    );
  }
}
