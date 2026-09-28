import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the user's light/dark/system preference and persists it on-device.
///
/// This is a per-install UI setting, not account data (mirrors
/// [OnboardingService]'s reasoning), so it's backed by [SharedPreferences]
/// rather than Firestore. [CarRentApp] listens to this via [Provider] and
/// rebuilds the whole app — through [AppTheme.of] — whenever [mode] changes.
class ThemeController extends ChangeNotifier {
  static const _modeKey = 'theme_mode';

  /// Dark by default: the "Obsidian Velocity" design is a dark-first
  /// system. Users can still pick Light or System in Settings.
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  /// Loads the persisted preference, if any. Called once at startup before
  /// [runApp] so the very first frame already reflects it.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_modeKey);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.dark,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}
