import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/booking/screens/booking_screen.dart';
import '../../features/cars/screens/car_details_screen.dart';
import '../../features/cars/screens/favorites_screen.dart';
import '../../features/cars/screens/my_cars_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/photo_posts/screens/photo_feed_screen.dart';
import '../../features/post_car/screens/post_car_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/support/screens/help_support_screen.dart';
import '../services/auth_service.dart';
import 'animated_branch_container.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'page_transitions.dart';

/// App-wide route table.
///
/// The four bottom-nav tabs live under one [StatefulShellRoute] so each
/// keeps independent navigation state (Section 3). Auth screens sit outside
/// the shell so the bottom nav never shows while logged out. `redirect`
/// below is the single source of truth for who can see what — driven off
/// [AuthService.authStateChanges] so a login/logout anywhere in the app
/// immediately re-routes without extra `context.go()` calls.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  static const _authRoutes = ['/login', '/register', '/forgot-password'];

  static GoRouter build(AuthService authService) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
      redirect: (context, state) {
        final loggedIn = authService.currentUser != null;
        final location = state.matchedLocation;

        // The splash screen makes its own one-time decision by awaiting the
        // first auth event directly, so leave it alone here — otherwise a
        // slow-arriving "logged out" event on launch would yank the user
        // back to /splash from /login mid-transition.
        if (location == '/splash') return null;

        // Same reasoning for onboarding: it's shown to logged-out users on
        // a fresh install, and must not get redirected to /login before
        // it's had a chance to render.
        if (location == '/onboarding') return null;

        final onAuthRoute = _authRoutes.contains(location);
        if (!loggedIn && !onAuthRoute) return '/login';
        if (loggedIn && onAuthRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => AppPageTransitions.fadeUp(context, state, const LoginScreen()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => AppPageTransitions.fadeUp(context, state, const RegisterScreen()),
        ),
        GoRoute(
          path: '/forgot-password',
          pageBuilder: (context, state) => AppPageTransitions.fadeUp(context, state, const ForgotPasswordScreen()),
        ),
        // Pushed over the shell on the root navigator (parentNavigatorKey)
        // so these open full-screen, without the bottom nav bar showing.
        GoRoute(
          path: '/car/:carId',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.scaleIn(
            context,
            state,
            CarDetailsScreen(carId: state.pathParameters['carId']!),
          ),
        ),
        GoRoute(
          path: '/favorites',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.slide(context, state, const FavoritesScreen()),
        ),
        GoRoute(
          path: '/my-cars',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.slide(context, state, const MyCarsScreen()),
        ),
        GoRoute(
          path: '/feed',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.slide(context, state, const PhotoFeedScreen()),
        ),
        GoRoute(
          path: '/notifications',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.slide(context, state, const NotificationsScreen()),
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.slide(context, state, const SettingsScreen()),
        ),
        GoRoute(
          path: '/help-support',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => AppPageTransitions.slide(context, state, const HelpSupportScreen()),
        ),
        // Not `.indexedStack`: a custom container so switching tabs
        // crossfades (AnimatedBranchContainer) instead of snapping, while
        // still keeping every tab's state alive like an IndexedStack.
        StatefulShellRoute(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          navigatorContainerBuilder: (context, navigationShell, children) =>
              AnimatedBranchContainer(currentIndex: navigationShell.currentIndex, children: children),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/post', builder: (context, state) => const PostCarScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/booking',
                  // `extra` carries an initial tab index (0=Renting,
                  // 1=My Cars) when a notification tap routes here wanting
                  // a specific tab open; defaults to 0 for the normal
                  // bottom-nav entry.
                  builder: (context, state) => BookingScreen(initialTabIndex: state.extra as int? ?? 0),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
