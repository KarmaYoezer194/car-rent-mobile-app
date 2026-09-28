import 'package:car_rent/core/constants/pricing.dart';
import 'package:car_rent/core/theme/app_theme.dart';
import 'package:car_rent/core/utils/formatters.dart';
import 'package:car_rent/models/booking_model.dart';
import 'package:car_rent/widgets/booking_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformPricing.split', () {
    test('15% commission, payout is the rest', () {
      final s = PlatformPricing.split(999);
      expect(s.commission, 149.85);
      expect(s.payout, 849.15);
    });

    test('commission + payout always equals the total exactly', () {
      for (final total in [1.0, 333.0, 999.0, 1500.0, 8641.5, 12345.67, 0.01]) {
        final s = PlatformPricing.split(total);
        expect(((s.commission + s.payout) * 100).round(), (total * 100).round(), reason: 'total $total');
      }
    });

    test('rounds commission to satang (matches what firestore.rules accepts)', () {
      // 1234.5 x 7. The exact 15% is 1296.225, which as a double is
      // 1296.2249999..., so it rounds down; firestore.rules allows +/-0.01
      // for exactly this. (Checked against the rules via the Rules Testing
      // API with these same amounts.)
      final s = PlatformPricing.split(8641.5);
      expect(s.commission, 1296.22);
      expect(s.payout, 7345.28);
    });
  });

  group('AppFormatters.money', () {
    test('keeps satang only when there are any', () {
      expect(AppFormatters.money(849.15), '฿849.15');
      expect(AppFormatters.money(999), '฿999');
      expect(AppFormatters.money(1296.2), '฿1,296.20');
    });
  });

  group('BookingModel.payoutForOwner', () {
    BookingModel booking({double? payout}) => BookingModel(
          id: 'b1',
          carId: 'c1',
          ownerId: 'o1',
          renterId: 'r1',
          carTitle: 'Ford Mustang',
          carImage: '',
          pricePerDay: 333,
          startDate: DateTime(2026, 9, 28),
          endDate: DateTime(2026, 10, 1),
          totalDays: 3,
          totalPrice: 999,
          status: BookingStatus.completed,
          createdAt: DateTime(2026, 9, 20),
          commissionAmount: payout == null ? null : 999 - payout,
          ownerPayout: payout,
        );

    test('is the stored payout for new bookings', () {
      expect(booking(payout: 849.15).payoutForOwner, 849.15);
    });

    test('is the full total for bookings made before commission existed', () {
      expect(booking().payoutForOwner, 999);
    });

    Future<void> pumpCard(WidgetTester tester, BookingModel b, {required bool owner}) {
      return tester.pumpWidget(MaterialApp(
        theme: AppTheme.of(Brightness.dark),
        home: Scaffold(body: BookingCard(booking: b, showOwnerPayout: owner)),
      ));
    }

    testWidgets('owner card shows the payout, not the total', (tester) async {
      await pumpCard(tester, booking(payout: 849.15), owner: true);
      expect(find.text('฿849.15 payout', findRichText: true), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
    });

    testWidgets('renter card shows the total, never the commission', (tester) async {
      await pumpCard(tester, booking(payout: 849.15), owner: false);
      expect(find.text('฿999 total', findRichText: true), findsOneWidget);
      expect(find.textContaining('849'), findsNothing);
      expect(find.textContaining('149'), findsNothing);
    });
  });
}
