// Unit tests for CarDraft's per-step validation gates (Section 9's 5-step
// wizard) — pure Dart logic, no Firebase involved, so these can run without
// any mocking.
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent/features/post_car/models/car_draft.dart';

void main() {
  group('CarDraft.hasPhotos', () {
    test('false with no images, true once one is added', () {
      final draft = CarDraft();
      expect(draft.hasPhotos, isFalse);

      draft.images = ['https://example.com/photo.jpg'];
      expect(draft.hasPhotos, isTrue);
    });
  });

  group('CarDraft.isCarInfoValid', () {
    CarDraft validDraft() => CarDraft()
      ..brand = 'Toyota'
      ..model = 'Camry'
      ..year = 2022
      ..type = 'Sedan'
      ..transmission = 'Automatic'
      ..fuelType = 'Petrol'
      ..description = 'A reliable and comfortable sedan.';

    test('true when every field is filled and description is long enough', () {
      expect(validDraft().isCarInfoValid, isTrue);
    });

    test('false when brand is blank/whitespace-only', () {
      final draft = validDraft()..brand = '   ';
      expect(draft.isCarInfoValid, isFalse);
    });

    test('false when a choice field (type/transmission/fuelType) is unset', () {
      expect((validDraft()..type = null).isCarInfoValid, isFalse);
      expect((validDraft()..transmission = null).isCarInfoValid, isFalse);
      expect((validDraft()..fuelType = null).isCarInfoValid, isFalse);
    });

    test('false when description is shorter than the 10-character minimum', () {
      final draft = validDraft()..description = 'too short';
      expect(draft.description.length, lessThan(10));
      expect(draft.isCarInfoValid, isFalse);
    });
  });

  group('CarDraft.isPricingValid', () {
    test('false until price and both dates are set', () {
      final draft = CarDraft();
      expect(draft.isPricingValid, isFalse);

      draft.pricePerDay = 1500;
      expect(draft.isPricingValid, isFalse);

      draft.availableFrom = DateTime(2026, 1, 1);
      draft.availableUntil = DateTime(2026, 3, 1);
      expect(draft.isPricingValid, isTrue);
    });

    test('false when price is zero or negative', () {
      final draft = CarDraft()
        ..pricePerDay = 0
        ..availableFrom = DateTime(2026, 1, 1)
        ..availableUntil = DateTime(2026, 3, 1);
      expect(draft.isPricingValid, isFalse);
    });

    test('false when availableUntil is not after availableFrom', () {
      final draft = CarDraft()
        ..pricePerDay = 1500
        ..availableFrom = DateTime(2026, 3, 1)
        ..availableUntil = DateTime(2026, 1, 1);
      expect(draft.isPricingValid, isFalse);
    });
  });

  group('CarDraft.isLocationValid', () {
    test('requires coordinates and a non-empty address', () {
      final draft = CarDraft();
      expect(draft.isLocationValid, isFalse);

      draft.latitude = 13.75;
      draft.longitude = 100.5;
      expect(draft.isLocationValid, isFalse, reason: 'address still empty');

      draft.address = 'Sukhumvit, Bangkok';
      expect(draft.isLocationValid, isTrue);
    });
  });

  group('CarDraft.isReadyToPublish', () {
    test('true only once every step is individually valid', () {
      final draft = CarDraft()
        ..images = ['https://example.com/photo.jpg']
        ..brand = 'Toyota'
        ..model = 'Camry'
        ..year = 2022
        ..type = 'Sedan'
        ..transmission = 'Automatic'
        ..fuelType = 'Petrol'
        ..description = 'A reliable and comfortable sedan.'
        ..pricePerDay = 1500
        ..availableFrom = DateTime(2026, 1, 1)
        ..availableUntil = DateTime(2026, 3, 1)
        ..latitude = 13.75
        ..longitude = 100.5
        ..address = 'Sukhumvit, Bangkok';

      expect(draft.isReadyToPublish, isTrue);

      draft.images = [];
      expect(draft.isReadyToPublish, isFalse);
    });
  });
}
