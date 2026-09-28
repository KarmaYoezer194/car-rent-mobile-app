import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The app's motion language for moving between screens. One set of curves
/// and durations everywhere, so navigating around CarRent feels like one
/// continuous app:
///
///  * [SmoothPageTransitionsBuilder] — the default for every
///    `MaterialPageRoute` push (installed in AppTheme's
///    `pageTransitionsTheme`): the new page glides in from the right while
///    fading in, and the page underneath eases a little to the left.
///  * [AppPageTransitions] — the same feel for go_router routes, plus two
///    variants (fade-up for auth screens, scale-in for Car Details).
///
/// All of them skip the animation when the OS "reduce motion" setting is on.
class AppMotion {
  AppMotion._();

  static const Duration pageIn = Duration(milliseconds: 380);
  static const Duration pageOut = Duration(milliseconds: 300);
  static const Duration tabSwitch = Duration(milliseconds: 360);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  static bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Incoming page: slides in from 6% to the right and fades in. Outgoing
  /// (covered) page: drifts 4% to the left. Horizontal "shared axis" motion
  /// reads as moving forward/back through the app.
  static Widget slideFade(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final incoming = CurvedAnimation(parent: animation, curve: enter, reverseCurve: exit);
    final covered = CurvedAnimation(parent: secondaryAnimation, curve: enter, reverseCurve: exit);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)).animate(covered),
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(incoming),
        child: FadeTransition(opacity: incoming, child: child),
      ),
    );
  }
}

/// [PageTransitionsBuilder] behind every `MaterialPageRoute` in the app.
/// iOS keeps the native Cupertino transition (and its back-swipe gesture);
/// every other platform — Android, web, desktop — gets
/// [AppMotion.slideFade].
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.pageIn;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageOut;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AppMotion.slideFade(context, animation, secondaryAnimation, child);
  }
}

/// Shared page-transition builders for go_router routes, so they move the
/// same way as `MaterialPageRoute` pushes.
class AppPageTransitions {
  AppPageTransitions._();

  /// Pushed full-screen routes (Favorites, My Cars, Settings, …): the
  /// app-wide slide + fade.
  static Page<void> slide(BuildContext context, GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.pageIn,
      reverseTransitionDuration: AppMotion.pageOut,
      transitionsBuilder: AppMotion.slideFade,
    );
  }

  /// Auth screens (Login, Register, Forgot password): a gentle fade + rise,
  /// since they aren't "deeper" in the app so much as a different place.
  static Page<void> fadeUp(BuildContext context, GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.pageIn,
      reverseTransitionDuration: AppMotion.pageOut,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppMotion.reduceMotion(context)) return child;
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Car Details — a subtle scale-up-from-behind so it reads as "opening"
  /// the card (paired with the car photo's Hero flight).
  static Page<void> scaleIn(BuildContext context, GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.pageIn,
      reverseTransitionDuration: AppMotion.pageOut,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppMotion.reduceMotion(context)) return child;
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
}
