import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/brand_accents.dart';
import '../../../widgets/cached_image.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.imageUrl,
    required this.lead,
    required this.highlight,
    required this.description,
  });

  final String imageUrl;

  /// Headline in two parts: [lead] in the cool headline gradient, then
  /// [highlight] in amber — "Exceptional cars, / on demand."
  final String lead;
  final String highlight;
  final String description;
}

const _slides = [
  _OnboardingSlide(
    imageUrl: 'https://images.unsplash.com/photo-1614200187524-dc4b892acf16?auto=format&fit=crop&w=1200&q=85',
    lead: 'Exceptional cars, ',
    highlight: 'on demand.',
    description: 'Rent great cars from private hosts near you — filter by price, type and location.',
  ),
  _OnboardingSlide(
    imageUrl: 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=85',
    lead: 'Your car, ',
    highlight: 'earning for you.',
    description: 'List it in a few steps, set your own price and dates, and approve every request yourself.',
  ),
  _OnboardingSlide(
    imageUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=85',
    lead: 'Every trip, ',
    highlight: 'in your hands.',
    description: 'Follow each booking from request to return, with live location while a rental is active.',
  ),
];

/// Intro carousel shown once, before the very first login. `/splash`
/// decides whether to land here at all; this screen is solely responsible
/// for marking itself seen via [OnboardingService].
///
/// Kept to the essentials: photo, headline, description, page dots, the
/// Next / "Get Started" button (→ sign-up) and a Skip link (→ log in). The page offset drives a parallax slide/scale/fade
/// between slides and the morphing dot indicator.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Current scroll position as a fraction — e.g. `1.35` is 35% of the way
  /// from slide 1 into slide 2.
  double get _t {
    if (_pageController.hasClients && _pageController.page != null) return _pageController.page!;
    return _page.toDouble();
  }

  Future<void> _finish({required bool newAccount}) async {
    await context.read<OnboardingService>().markOnboardingSeen();
    if (!mounted) return;
    final loggedIn = context.read<AuthService>().currentUser != null;
    context.go(loggedIn ? '/home' : (newAccount ? '/register' : '/login'));
  }

  void _getStarted() {
    if (_page < _slides.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _finish(newAccount: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pageController,
          builder: (context, _) {
            final t = _t;
            return Column(
              children: [
                // Just Skip (to log in) — fades out on the last slide, where
                // the main button already says "Get Started".
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, AppSpacing.md, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isLast ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: isLast,
                        child: TextButton(
                          onPressed: () => _finish(newAccount: false),
                          child: Text(
                            'Skip',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) => _SlideContent(slide: _slides[index], pageOffset: t - index),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.lg),
                  child: Column(
                    children: [
                      _DotIndicator(t: t, count: _slides.length),
                      const SizedBox(height: AppSpacing.xl),
                      GlowButton(label: isLast ? 'Get Started' : 'Next', onPressed: _getStarted),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.t, required this.count});

  final double t;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final closeness = 1 - (t - index).abs().clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 7 + closeness * 17,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Color.lerp(AppColors.border, AppColors.primary, closeness),
          ),
        );
      }),
    );
  }
}

/// One slide's photo + copy. [pageOffset] is 0 when centered and ±1 a full
/// page away, driving a parallax slide/scale/fade as the user drags.
class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide, required this.pageOffset});

  final _OnboardingSlide slide;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final diff = pageOffset.clamp(-1.0, 1.0);
    final opacity = (1 - diff.abs()).clamp(0.0, 1.0);
    final titleStyle = AppTextStyles.h1.copyWith(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(diff * 60, 0),
        child: Transform.scale(
          scale: 1 - diff.abs() * 0.12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedImage(url: slide.imageUrl, iconSize: 56),
                        // Fades the photo's bottom edge into the page.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.55, 1],
                              colors: [Colors.transparent, AppColors.navy.withValues(alpha: 0.7)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text.rich(
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
                          child: Text(slide.lead, style: titleStyle),
                        ),
                      ),
                      TextSpan(text: slide.highlight, style: titleStyle.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  slide.description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
