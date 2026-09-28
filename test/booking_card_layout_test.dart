import 'package:car_rent/core/theme/app_theme.dart';
import 'package:car_rent/models/booking_model.dart';
import 'package:car_rent/widgets/booking_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The redesigned booking card packs a title, status chip, dates, price and
/// action buttons into one card. Render it at a small phone's content width
/// (320 px wide screen minus the 20 px side padding) in every status, with
/// a long car name and all its buttons — any RenderFlex overflow fails the
/// test.
void main() {
  BookingModel booking(String status) => BookingModel(
        id: 'b1',
        carId: 'c1',
        ownerId: 'o1',
        renterId: 'r1',
        carTitle: 'Mercedes-Benz GLE Coupe AMG Line Edition',
        carImage: '',
        pricePerDay: 12500,
        startDate: DateTime.now().add(const Duration(days: 6)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        totalDays: 4,
        totalPrice: 50000,
        status: status,
        createdAt: DateTime(2026, 1, 1),
      );

  for (final brightness in Brightness.values) {
    for (final status in [
      BookingStatus.pending,
      BookingStatus.confirmed,
      BookingStatus.active,
      BookingStatus.returnRequested,
      BookingStatus.completed,
      BookingStatus.rejected,
      BookingStatus.cancelled,
    ]) {
      testWidgets('BookingCard fits a narrow phone — $status, ${brightness.name}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.of(brightness),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 280,
                  child: BookingCard(
                    booking: booking(status),
                    onTap: () {},
                    onAccept: status == BookingStatus.pending ? () {} : null,
                    onReject: status == BookingStatus.pending ? () {} : null,
                    onStart: status == BookingStatus.confirmed ? () {} : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
