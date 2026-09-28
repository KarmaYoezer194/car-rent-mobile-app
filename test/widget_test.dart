// Basic smoke test for a Firebase-independent widget. Screens like
// HomeScreen now depend on live Firebase services (AuthService,
// CarService), which isn't available under `flutter test`'s fake platform —
// full app boot testing belongs to Phase 10 with proper mocks (e.g.
// firebase_auth_mocks, fake_cloud_firestore) wired in.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent/core/theme/app_theme.dart';
import 'package:car_rent/models/car_model.dart';
import 'package:car_rent/widgets/car_card.dart';

void main() {
  testWidgets('CarCard shows title, price, and address', (WidgetTester tester) async {
    final car = CarModel(
      id: 'car1',
      ownerId: 'owner1',
      brand: 'Toyota',
      model: 'Camry',
      year: 2022,
      type: 'Sedan',
      transmission: 'Automatic',
      fuelType: 'Petrol',
      seats: 4,
      airConditioning: true,
      description: 'A reliable sedan.',
      pricePerDay: 1500,
      images: const [],
      latitude: 13.75,
      longitude: 100.5,
      address: 'Bangkok',
      status: 'available',
      rating: 4.8,
      reviewCount: 12,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          // Sized like its real home: a cell in Home/Favorites' 2-column
          // grid (childAspectRatio: 0.74 at a ~173px cell width) — CarCard
          // is never actually given a free-form, unconstrained box like a
          // bare Scaffold body would, and testing it that way previously
          // masked a real overflow bug in the card's layout.
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 173,
              height: 173 / 0.74,
              child: CarCard(
                car: car,
                isFavorite: false,
                onTap: () {},
                onFavoriteToggle: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Toyota Camry'), findsOneWidget);
    // Price is one rich text: the amount, then a muted " /day".
    expect(find.text('฿1,500 /day', findRichText: true), findsOneWidget);
    expect(find.text('Bangkok'), findsOneWidget);
    // Rating: a star icon next to the number.
    expect(find.text('4.8'), findsOneWidget);
    expect(find.byIcon(LucideIcons.star), findsOneWidget);
  });
}
