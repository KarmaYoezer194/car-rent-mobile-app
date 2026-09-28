import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/car_options.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../core/widgets/motion/shimmer_box.dart';
import '../../../models/car_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/brand_header.dart';
import '../../../widgets/car_card.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/user_avatar.dart';
import '../widgets/car_filter_sheet.dart';
import 'cars_map_screen.dart';

/// The marketplace — the app's landing tab (Section 6), in the Obsidian
/// Velocity layout: brand header, greeting, search + filters, category
/// chips, then the car grid (with a Map View of the same results).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _gridAspectRatio = 0.74;

  final _searchController = TextEditingController();
  String _query = '';
  CarFilters _filters = const CarFilters();
  String? _selectedType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CarModel> _applyFilters(List<CarModel> cars) {
    final query = _query.trim().toLowerCase();
    return cars.where((car) {
      // "Search make, model, or city" — the address covers area and city.
      if (query.isNotEmpty &&
          !car.brand.toLowerCase().contains(query) &&
          !car.model.toLowerCase().contains(query) &&
          !car.address.toLowerCase().contains(query)) {
        return false;
      }
      if (_selectedType != null && car.type != _selectedType) return false;
      if (_filters.minPrice != null && car.pricePerDay < _filters.minPrice!) return false;
      if (_filters.maxPrice != null && car.pricePerDay > _filters.maxPrice!) return false;
      if (_filters.types.isNotEmpty && !_filters.types.contains(car.type)) return false;
      if (_filters.transmissions.isNotEmpty && !_filters.transmissions.contains(car.transmission)) {
        return false;
      }
      if (_filters.fuelTypes.isNotEmpty && !_filters.fuelTypes.contains(car.fuelType)) return false;
      return true;
    }).toList();
  }

  Future<void> _openFilters() async {
    final result = await showCarFilterSheet(context, _filters);
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final carService = context.watch<CarService>();
    final uid = authService.currentUser?.uid;

    final topSlivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
          child: _Greeting(authService: authService, uid: uid),
        ).animate().fadeIn(duration: 360.ms).moveY(begin: -10, end: 0, duration: 360.ms, curve: Curves.easeOutCubic),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.md),
          child: _SearchRow(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            onFilterTap: _openFilters,
            activeFilterCount: _filters.activeCount,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _CategoryStrip(selected: _selectedType, onSelected: (type) => setState(() => _selectedType = type)),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const BrandHeader(subtitle: 'Explore'),
            Expanded(
              child: StreamBuilder<List<CarModel>>(
                stream: carService.streamAvailableCars(),
                builder: (context, carsSnapshot) {
                  final List<Widget> content;
                  if (carsSnapshot.connectionState == ConnectionState.waiting) {
                    content = [const _GridSkeleton(aspectRatio: _gridAspectRatio)];
                  } else if (carsSnapshot.hasError) {
                    content = [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ErrorStateWidget(message: AppStrings.genericError, onRetry: () => setState(() {})),
                      ),
                    ];
                  } else if ((carsSnapshot.data ?? const []).isEmpty) {
                    content = [
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateWidget(icon: LucideIcons.car, message: AppStrings.noCarsAvailable),
                      ),
                    ];
                  } else {
                    final cars = _applyFilters(carsSnapshot.data!);
                    content = [
                      SliverToBoxAdapter(child: _ResultsHeader(cars: cars)),
                      if (cars.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyStateWidget(icon: LucideIcons.searchX, message: 'No cars match your search.'),
                        )
                      else
                        _CarGrid(cars: cars, uid: uid, carService: carService, aspectRatio: _gridAspectRatio),
                    ];
                  }
                  return CustomScrollView(slivers: [...topSlivers, ...content]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.authService, required this.uid});

  final AuthService authService;
  final String? uid;

  static String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: uid == null ? const Stream.empty() : authService.userDoc(uid!),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final firstName = (user == null || user.name.trim().isEmpty) ? null : user.name.trim().split(' ').first;

        return Row(
          children: [
            // Amber ring around the photo, plus a green "you're signed in"
            // presence dot.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.35)]),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                    child: UserAvatar(name: user?.name ?? '', photoUrl: user?.profileImage, size: 46),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName == null ? '$_greeting,' : '$_greeting, $firstName',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Find your ride',
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    required this.activeFilterCount,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.search, color: AppColors.textMuted, size: 21),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: AppTextStyles.bodyMedium,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Search make, model, or city...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isCollapsed: true,
                    ),
                  ),
                ),
                // Clear button once something's typed — the mockup's mic
                // slot, used for something this app can actually do.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () {
                            controller.clear();
                            onChanged('');
                          },
                          child: Icon(LucideIcons.x, color: AppColors.textMuted, size: 19),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: activeFilterCount > 0 ? AppColors.accent : AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: onFilterTap,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(LucideIcons.slidersHorizontal, color: AppColors.textPrimary, size: 22),
                ),
              ),
            ),
            if (activeFilterCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                  child: Text(
                    '$activeFilterCount',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  final String? selected;

  /// Called with the chosen type, or null for "All".
  final ValueChanged<String?> onSelected;

  static IconData? _iconFor(String type) => switch (type) {
    'Sedan' => Icons.directions_car_rounded,
    'SUV' => Icons.airport_shuttle_rounded,
    'Pickup' => Icons.local_shipping_rounded,
    'Van' => Icons.airport_shuttle_outlined,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...CarOptions.types];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final type = options[index];
          return _CategoryChip(
            label: type ?? 'All',
            icon: type == null ? null : _iconFor(type),
            selected: selected == type,
            onTap: () => onSelected(type),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent : AppColors.textSecondary;
    return PressFeedback(
      scale: 0.95,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accent : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.cars});

  final List<CarModel> cars;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen - 8, 0),
      child: Row(
        children: [
          Text('Available Cars', style: AppTextStyles.h3.copyWith(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '${cars.length} found',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: cars.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarsMapScreen(cars: cars))),
            iconAlignment: IconAlignment.end,
            icon: const Icon(LucideIcons.map, size: 17),
            label: Text(
              'Map View',
              style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarGrid extends StatelessWidget {
  const _CarGrid({required this.cars, required this.uid, required this.carService, required this.aspectRatio});

  final List<CarModel> cars;
  final String? uid;
  final CarService carService;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: uid != null ? carService.favoriteCarIds(uid!) : Stream.value(const {}),
      builder: (context, favSnapshot) {
        final favoriteIds = favSnapshot.data ?? const {};
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: aspectRatio,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final car = cars[index];
              return Entrance(
                delay: Entrance.staggerDelay(index),
                child: CarCard(
                  car: car,
                  isFavorite: favoriteIds.contains(car.id),
                  onTap: () => context.push('/car/${car.id}'),
                  onFavoriteToggle: uid == null
                      ? () {}
                      : () => carService.setFavorite(uid!, car.id, !favoriteIds.contains(car.id)),
                ),
              );
            }, childCount: cars.length),
          ),
        );
      },
    );
  }
}

/// Shown while the first car snapshot is still loading — a grid of
/// [CarCardSkeleton]s in the exact shape the real grid will take.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xl),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate((context, index) => const CarCardSkeleton(), childCount: 4),
      ),
    );
  }
}
