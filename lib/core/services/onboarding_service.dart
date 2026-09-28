import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has already been shown the onboarding carousel.
///
/// Backed by on-device [SharedPreferences] rather than Firestore — this is
/// a per-install UI flag, not account data, so it has no reason to touch
/// the network or survive a reinstall.
class OnboardingService {
  static const _seenKey = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
