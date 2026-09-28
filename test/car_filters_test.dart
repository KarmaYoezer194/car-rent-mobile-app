// Unit tests for CarFilters — Home's filter-sheet state (Section 7).
import 'package:flutter/material.dart' show RangeValues;
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent/features/home/widgets/car_filter_sheet.dart';

void main() {
  group('CarFilters.isEmpty / activeCount', () {
    test('empty by default', () {
      const filters = CarFilters();
      expect(filters.isEmpty, isTrue);
      expect(filters.activeCount, 0);
    });

    test('a price range counts as exactly one active filter', () {
      const filters = CarFilters(minPrice: 500, maxPrice: 2000);
      expect(filters.isEmpty, isFalse);
      expect(filters.activeCount, 1);
    });

    test('each selected chip in every category counts individually', () {
      const filters = CarFilters(
        types: {'Sedan', 'SUV'},
        transmissions: {'Automatic'},
        fuelTypes: {'Petrol', 'Electric', 'Hybrid'},
      );
      expect(filters.activeCount, 6); // 2 + 1 + 3, no price set
    });

    test('price plus chips add up together', () {
      const filters = CarFilters(minPrice: 1000, types: {'Sedan'});
      expect(filters.activeCount, 2);
    });
  });

  group('resolveTypedPriceRange', () {
    test('blank boxes mean the full range', () {
      expect(resolveTypedPriceRange('', '', bound: 10000), const RangeValues(0, 10000));
    });

    test('typed values are used as-is', () {
      expect(resolveTypedPriceRange('800', '2500', bound: 10000), const RangeValues(800, 2500));
    });

    test('values above the bound are clamped to it', () {
      expect(resolveTypedPriceRange('500', '99999', bound: 10000), const RangeValues(500, 10000));
    });

    test('min above max is swapped rather than rejected', () {
      expect(resolveTypedPriceRange('3000', '1000', bound: 10000), const RangeValues(1000, 3000));
    });

    test('non-digits (e.g. pasted "1,500") are ignored', () {
      expect(resolveTypedPriceRange('1,500', '', bound: 10000), const RangeValues(1500, 10000));
    });
  });

  group('CarFilters.copyWith', () {
    test('preserves fields that are not overridden', () {
      const original = CarFilters(minPrice: 500, types: {'SUV'});
      final updated = original.copyWith(maxPrice: 3000);

      expect(updated.minPrice, 500);
      expect(updated.maxPrice, 3000);
      expect(updated.types, {'SUV'});
    });

    test('clearPrice removes both price bounds regardless of other args', () {
      const original = CarFilters(minPrice: 500, maxPrice: 3000);
      final cleared = original.copyWith(clearPrice: true);

      expect(cleared.minPrice, isNull);
      expect(cleared.maxPrice, isNull);
    });
  });
}
