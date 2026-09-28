import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/cached_image.dart';

/// First screen shown on app launch.
///
/// Waits for Firebase Auth to report the persisted sign-in state, then
/// routes to `/home` (already logged in) or `/login` (needs to sign in).
/// A minimum display time keeps the brand moment from flashing instantly
/// on fast reconnects.
///
/// Pure black background with a white logo mark — the one screen allowed
/// to invert the whole palette (light-on-black) as a brand moment, still
/// strictly monochrome per the design system (no color, no gradient).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minDisplay = Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    _decideDestination();
  }

  Future<void> _decideDestination() async {
    final authService = context.read<AuthService>();
    final onboardingService = context.read<OnboardingService>();
    final userFuture = authService.authStateChanges.first;
    final seenOnboardingFuture = onboardingService.hasSeenOnboarding();
    final minDelay = Future<void>.delayed(_minDisplay);

    final user = await userFuture;
    final seenOnboarding = await seenOnboardingFuture;
    await minDelay;
    if (!mounted) return;

    if (!seenOnboarding) {
      context.go('/onboarding');
      return;
    }
    context.go(user != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CachedImage(
              url: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=85',
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.black38, Colors.black],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.car, color: Colors.white, size: 48)
                    .animate()
                    .scaleXY(begin: 0.7, end: 1, duration: 450.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 300.ms),
                const SizedBox(height: 22),
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.brand.copyWith(color: Colors.white),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 350.ms)
                    .moveY(begin: 10, end: 0, delay: 200.ms, duration: 350.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 6),
                Text(
                  'Drive. Share. Earn.',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.55)),
                ).animate().fadeIn(delay: 350.ms, duration: 350.ms),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Center(
              child: Container(
                width: 120,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(1),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: _minDisplay,
                    curve: Curves.easeInOut,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
        ],
      ),
    );
  }
}
