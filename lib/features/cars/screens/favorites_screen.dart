import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/car_model.dart';
import '../../../widgets/car_card.dart';
import '../../../widgets/loading_widget.dart';

/// Profile → Favorites (Section 22).
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final carService = context.watch<CarService>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: uid == null
          ? const EmptyStateWidget(icon: LucideIcons.heart, message: AppStrings.noFavorites)
          : StreamBuilder<Set<String>>(
              stream: carService.favoriteCarIds(uid),
              builder: (context, favSnapshot) {
                if (favSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                if (favSnapshot.hasError) {
                  return const ErrorStateWidget(message: AppStrings.genericError);
                }
                final favoriteIds = favSnapshot.data ?? const {};
                if (favoriteIds.isEmpty) {
                  return const EmptyStateWidget(
                    icon: LucideIcons.heart,
                    message: AppStrings.noFavorites,
                  );
                }

                return StreamBuilder<List<CarModel>>(
                  stream: carService.streamCarsByIds(favoriteIds),
                  builder: (context, carsSnapshot) {
                    if (carsSnapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingWidget();
                    }
                    if (carsSnapshot.hasError) {
                      return const ErrorStateWidget(message: AppStrings.genericError);
                    }
                    final cars = carsSnapshot.data ?? const [];
                    if (cars.isEmpty) {
                      // Favorited car(s) were deleted/unavailable — handled
                      // gracefully rather than showing broken entries.
                      return const EmptyStateWidget(
                        icon: LucideIcons.heart,
                        message: AppStrings.noFavorites,
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: cars.length,
                      itemBuilder: (context, index) {
                        final car = cars[index];
                        return Entrance(
                          delay: Entrance.staggerDelay(index),
                          child: CarCard(
                            car: car,
                            isFavorite: true,
                            onTap: () => context.push('/car/${car.id}'),
                            onFavoriteToggle: () => carService.setFavorite(uid, car.id, false),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
