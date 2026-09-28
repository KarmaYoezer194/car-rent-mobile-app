/// Consistent spacing and radius scale used across the whole app.
///
/// Always reach for these instead of magic numbers so screens stay visually
/// consistent as more features are added in later phases.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double screen = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  /// Prominent/large containers — car cards, booking cards, form step
  /// cards, hero panels.
  static const double xxl = 24;

  /// Bottom sheets, the splash logo mark, and other full-bleed rounded
  /// panels that need to read as "one size up" from a card.
  static const double sheet = 24;

  static const double pill = 999;
}
