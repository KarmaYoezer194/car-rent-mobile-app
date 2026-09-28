import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/car_model.dart';
import '../../../models/review_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/car_3d_viewer.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/osm_map_view.dart';
import '../../../widgets/review_card.dart';
import '../../../widgets/vin_verified_badge.dart';
import '../../booking/screens/book_car_screen.dart';
import 'full_screen_map_screen.dart';
import '../../../widgets/user_avatar.dart';

/// Car Details (Section 8) — everything a renter needs to decide, with
/// "Rent Now" always visible at the bottom.
class CarDetailsScreen extends StatelessWidget {
  const CarDetailsScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context) {
    final carService = context.watch<CarService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: StreamBuilder<CarModel?>(
        stream: carService.streamCar(carId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }
          final car = snapshot.data;
          if (car == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const ErrorStateWidget(message: 'This car is no longer available.'),
            );
          }
          return _CarDetailsBody(car: car, authService: authService);
        },
      ),
    );
  }
}

class _CarDetailsBody extends StatelessWidget {
  const _CarDetailsBody({required this.car, required this.authService});

  final CarModel car;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final uid = authService.currentUser?.uid;
    final isOwnCar = uid != null && uid == car.ownerId;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 300,
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroSection(car: car, uid: uid),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${car.title} · ${car.year}', style: AppTextStyles.h2),
                              if (car.vinVerified) ...[
                                const SizedBox(height: AppSpacing.xs),
                                const VinVerifiedBadge(),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Icon(LucideIcons.star, color: AppColors.star, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    car.reviewCount > 0
                                        ? '${car.rating.toStringAsFixed(1)} (${car.reviewCount} reviews)'
                                        : 'No reviews yet',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(AppFormatters.pricePerDay(car.pricePerDay), style: AppTextStyles.priceLarge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(delay: Entrance.staggerDelay(0), child: _SpecsGrid(car: car)),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      delay: Entrance.staggerDelay(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Description', style: AppTextStyles.h3),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            car.description.isNotEmpty ? car.description : 'No description provided.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      delay: Entrance.staggerDelay(2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pickup location', style: AppTextStyles.h3),
                          const SizedBox(height: AppSpacing.sm),
                          _PickupLocationMap(car: car),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      delay: Entrance.staggerDelay(3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hosted by', style: AppTextStyles.h3),
                          const SizedBox(height: AppSpacing.sm),
                          _OwnerCard(ownerId: car.ownerId, authService: authService),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      delay: Entrance.staggerDelay(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reviews', style: AppTextStyles.h3),
                          const SizedBox(height: AppSpacing.sm),
                          _ReviewsSection(carId: car.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _RentNowBar(car: car, isOwnCar: isOwnCar),
        ),
      ],
    );
  }
}

/// The SliverAppBar's collapsible photo hero, plus the back/favorite
/// buttons floating over it and a "3D Preview" toggle that swaps the photo
/// carousel for [Car3dViewer] — a genuinely interactive (drag-to-orbit)
/// showroom moment rather than another static image.
class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.car, required this.uid});

  final CarModel car;
  final String? uid;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  bool _show3d = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _show3d
              ? ColoredBox(
                  key: const ValueKey('3d'),
                  color: AppColors.surfaceMuted,
                  child: Car3dViewer(height: 300),
                )
              : KeyedSubtree(
                  key: const ValueKey('photos'),
                  child: _ImageCarousel(images: widget.car.images, carId: widget.car.id),
                ),
        ),
        Positioned(
          left: AppSpacing.lg,
          top: AppSpacing.md,
          child: _FloatingIconButton(
            icon: LucideIcons.chevronLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          top: AppSpacing.md,
          child: _FavoriteToggle(car: widget.car, uid: widget.uid),
        ),
        if (Car3dViewer.isSupported)
          Positioned(
            bottom: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _View3dToggle(
              active: _show3d,
              onTap: () => setState(() => _show3d = !_show3d),
            ),
          ),
      ],
    );
  }
}

class _View3dToggle extends StatelessWidget {
  const _View3dToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.box,
                size: 18,
                color: active ? AppColors.onPrimary : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'Photos' : '3D Preview',
                style: AppTextStyles.bodySmall.copyWith(
                  color: active ? AppColors.onPrimary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms).scaleXY(begin: 0.8, end: 1, delay: 200.ms, duration: 300.ms, curve: Curves.easeOutBack);
  }
}

class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(13),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 18, color: color ?? AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _FavoriteToggle extends StatelessWidget {
  const _FavoriteToggle({required this.car, required this.uid});

  final CarModel car;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final carService = context.watch<CarService>();
    if (uid == null) {
      return _FloatingIconButton(icon: LucideIcons.heart, onTap: () {});
    }
    return StreamBuilder<Set<String>>(
      stream: carService.favoriteCarIds(uid!),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.contains(car.id) ?? false;
        return _FloatingIconButton(
          icon: isFavorite ? LucideIcons.heart : LucideIcons.heart,
          color: isFavorite ? AppColors.heart : AppColors.textPrimary,
          onTap: () => carService.setFavorite(uid!, car.id, !isFavorite),
        );
      },
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.images, required this.carId});

  final List<String> images;
  final String carId;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return ColoredBox(
        color: AppColors.surfaceMuted,
        child: Icon(LucideIcons.car, color: AppColors.textMuted, size: 64),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            final image = CachedImage(url: widget.images[index], iconSize: 40);
            // Only the first photo carries the Hero tag shared with the car
            // card it was tapped from — a matching tag on every page would
            // collide (Hero requires a unique tag per active route).
            return index == 0 ? Hero(tag: 'car_image_${widget.carId}', child: image) : image;
          },
        ),
        if (widget.images.length > 1)
          Positioned(
            bottom: AppSpacing.md,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final specs = [
      (LucideIcons.car, car.type),
      (LucideIcons.settings, car.transmission),
      (LucideIcons.fuel, car.fuelType),
      (LucideIcons.armchair, '${car.seats} seats'),
      (LucideIcons.snowflake, car.airConditioning ? 'A/C' : 'No A/C'),
    ];

    return Row(
      children: specs.map((spec) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Icon(spec.$1, size: 19, color: AppColors.textSecondary),
                const SizedBox(height: 7),
                Text(
                  spec.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Section 8: "Include Google Maps showing the pickup location" — an OSM
/// map (see README on why not literally Google Maps) with a single pin at
/// the car's declared pickup point, plus the address underneath.
///
/// The embedded map is a static preview (`interactive: false`) — it lives
/// inside a scrolling page, and an interactive map there means a scroll
/// gesture that starts over it gets partly consumed as a pinch/pan instead
/// of scrolling the page (reported directly: "when I scroll... the map
/// gets zoomed"). The expand button is the only way to actually zoom/pan —
/// [FullScreenMapScreen] isn't inside anything scrollable, so full
/// interactivity there is free of that conflict.
class _PickupLocationMap extends StatelessWidget {
  const _PickupLocationMap({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final pin = MapPins.pickup(car.latitude, car.longitude);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                OsmMapView(center: pin, interactive: false),
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullScreenMapScreen(title: 'Pickup Location', pin: pin),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(LucideIcons.maximize, size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: AppColors.surface,
            child: Row(
              children: [
                Icon(LucideIcons.mapPin, color: AppColors.accent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    car.address.isNotEmpty ? car.address : 'Location not specified',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reviews left on this car (Section 8), newest first. `car.rating`/
/// `reviewCount` shown up top are the denormalized aggregate this list adds
/// up to — [ReviewService.submitReview] is what keeps them in sync.
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context) {
    final reviewService = context.watch<ReviewService>();

    return StreamBuilder<List<ReviewModel>>(
      stream: reviewService.streamReviewsForCar(carId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 48, child: LoadingWidget());
        }
        if (snapshot.hasError) {
          return Text(AppStrings.genericError, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary));
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return Text(AppStrings.noReviews, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary));
        }
        return Column(
          children: reviews.map((review) => ReviewCard(review: review)).toList(),
        );
      },
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.ownerId, required this.authService});

  final String ownerId;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: authService.userDoc(ownerId),
      builder: (context, snapshot) {
        final owner = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            children: [
              UserAvatar(name: owner?.name ?? '', photoUrl: owner?.profileImage, size: 46, borderRadius: 15),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(owner?.name ?? 'Car owner', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(LucideIcons.star, color: AppColors.star, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          owner != null && owner.rating > 0
                              ? owner.rating.toStringAsFixed(1)
                              : 'No ratings yet',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RentNowBar extends StatelessWidget {
  const _RentNowBar({required this.car, required this.isOwnCar});

  final CarModel car;
  final bool isOwnCar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background.withValues(alpha: 0), AppColors.background],
          stops: const [0, 0.35],
        ),
      ),
      child: SafeArea(
        top: false,
        child: isOwnCar
            ? const CustomButton(label: 'This Is Your Car', onPressed: null, isOutlined: true)
            : CustomButton(
                label: car.isAvailable ? 'Rent Now' : 'Currently Unavailable',
                onPressed: !car.isAvailable
                    ? null
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookCarScreen(car: car))),
              ),
      ),
    );
  }
}
