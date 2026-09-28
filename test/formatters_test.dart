// Unit tests for AppFormatters — the currency formatting used everywhere a
// price is shown (car cards, booking totals, filter labels).
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent/core/utils/formatters.dart';

void main() {
  group('AppFormatters.currency', () {
    test('adds the ฿ symbol and thousands separators', () {
      expect(AppFormatters.currency(1500), '฿1,500');
      expect(AppFormatters.currency(4500), '฿4,500');
      expect(AppFormatters.currency(900), '฿900');
      expect(AppFormatters.currency(120000), '฿120,000');
    });

    test('handles zero', () {
      expect(AppFormatters.currency(0), '฿0');
    });
  });

  group('AppFormatters.pricePerDay', () {
    test('appends "/day" to the formatted currency', () {
      expect(AppFormatters.pricePerDay(1500), '฿1,500/day');
    });
  });
}
