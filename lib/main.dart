import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/booking_service.dart';
import 'core/services/car_service.dart';
import 'core/services/cloudinary_image_upload_service.dart';
import 'core/services/image_upload_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/onboarding_service.dart';
import 'core/services/post_service.dart';
import 'core/services/review_service.dart';
import 'core/services/theme_controller.dart';
import 'core/services/vin_decoder_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Web only: Firebase Auth's default LOCAL persistence stores the session
  // in IndexedDB, which every tab on the same origin shares — so signing in
  // or out in one tab switched every other tab to that same account, and
  // two tabs could never be signed in as two different users. SESSION
  // scopes the login to the tab (sessionStorage): a refresh keeps you
  // signed in, a duplicated tab starts with a copy of the session but is
  // independent from then on, and closing the tab signs out. Must run
  // before anything signs in. Android/iOS are one user per app anyway.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

  // Plus Jakarta Sans is bundled locally (see pubspec.yaml's `fonts:` section), so
  // GoogleFonts.plusJakartaSans() calls everywhere in AppTextStyles should resolve
  // straight to that bundled asset rather than reaching out to Google's
  // CDN — this is what makes the typeface reliable offline and on the very
  // first frame, instead of racing a network fetch.
  GoogleFonts.config.allowRuntimeFetching = false;

  final themeController = ThemeController();
  await themeController.load();

  // Swap this for a Firebase Storage implementation later if the project
  // ever moves off the Spark plan — everything that uploads images
  // (AuthService's profile photo, Post Car's car photos, PostService's
  // photo posts) only depends on
  // the abstract ImageUploadService interface, resolved once here.
  final imageUploadService = CloudinaryImageUploadService();
  final authService = AuthService(imageUploadService: imageUploadService);
  final carService = CarService();
  final notificationService = NotificationService();
  final bookingService = BookingService(notificationService: notificationService);
  final reviewService = ReviewService(notificationService: notificationService);
  final onboardingService = OnboardingService();
  final postService = PostService(imageUploadService: imageUploadService);
  final router = AppRouter.build(authService);

  runApp(CarRentApp(
    authService: authService,
    carService: carService,
    bookingService: bookingService,
    reviewService: reviewService,
    notificationService: notificationService,
    imageUploadService: imageUploadService,
    onboardingService: onboardingService,
    postService: postService,
    themeController: themeController,
    router: router,
  ));
}

class CarRentApp extends StatelessWidget {
  const CarRentApp({
    super.key,
    required this.authService,
    required this.carService,
    required this.bookingService,
    required this.reviewService,
    required this.notificationService,
    required this.imageUploadService,
    required this.onboardingService,
    required this.postService,
    required this.themeController,
    required this.router,
  });

  final AuthService authService;
  final CarService carService;
  final BookingService bookingService;
  final ReviewService reviewService;
  final NotificationService notificationService;
  final ImageUploadService imageUploadService;
  final OnboardingService onboardingService;
  final PostService postService;
  final ThemeController themeController;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<CarService>.value(value: carService),
        Provider<BookingService>.value(value: bookingService),
        Provider<ReviewService>.value(value: reviewService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<ImageUploadService>.value(value: imageUploadService),
        Provider<OnboardingService>.value(value: onboardingService),
        Provider<PostService>.value(value: postService),
        // Stateless apart from its HTTP client; one shared instance is fine.
        Provider<VinDecoderService>(create: (_) => VinDecoderService()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          // Resolve "system" ourselves (rather than handing Flutter both a
          // theme and a darkTheme) so AppColors — read directly by feature
          // widgets, not just by ThemeData — stays in sync with whichever
          // brightness is actually on screen.
          final platformBrightness = MediaQuery.platformBrightnessOf(context);
          final brightness = switch (themeController.mode) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => platformBrightness,
          };

          return MaterialApp.router(
            // `StatefulShellRoute.indexedStack` (see AppRouter) keeps every
            // bottom-nav tab's Navigator alive for performance, so once a
            // screen like Profile has painted once, rebuilding this Consumer
            // alone does NOT re-run that cached screen's build() — it would
            // keep showing whatever AppColors.x values it read the first
            // time, regardless of what ThemeController.mode is now. Keying
            // the whole router subtree on brightness forces Flutter to tear
            // it down and remount it fresh on every theme change, so every
            // screen — cached tabs included — re-reads AppColors correctly.
            // GoRouter itself (not recreated here) still restores the exact
            // current location, so this doesn't lose the user's place.
            key: ValueKey(brightness),
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.of(brightness),
            routerConfig: router,
            builder: (context, child) => _ThemeRefresh(brightness: brightness, child: child!),
          );
        },
      ),
    );
  }
}

/// Backstop for the keyed remount above: GoRouter's navigators hold
/// GlobalKeys, so on a theme change their subtrees are *reparented* into the
/// new MaterialApp rather than rebuilt — and any widget with no inherited
/// dependency (e.g. `const BrandHeader`) keeps the colors it read under the
/// old brightness. After each brightness change this marks every element in
/// the subtree dirty, so everything re-reads [AppColors] on the next frame.
class _ThemeRefresh extends StatefulWidget {
  const _ThemeRefresh({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  State<_ThemeRefresh> createState() => _ThemeRefreshState();
}

class _ThemeRefreshState extends State<_ThemeRefresh> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
  }

  @override
  void didUpdateWidget(_ThemeRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
  }

  void _rebuildAll() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
