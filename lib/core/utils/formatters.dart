import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Shared number/date formatting so "฿1,500/day" looks the same everywhere
/// a price is shown (car cards, details, booking totals in later phases).
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currency = NumberFormat('#,##0', 'en_US');

  static String currency(num amount) => '฿${_currency.format(amount)}';

  static String pricePerDay(num amount) => '${currency(amount)}/day';

  static final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');

  /// Like [currency], but keeps satang when the amount has them — for
  /// computed amounts such as commission and owner payout (฿149.85), where
  /// rounding to whole baht would misstate the split. Whole amounts still
  /// print without decimals (฿999).
  static String money(num amount) {
    final isWhole = (amount * 100).round() % 100 == 0;
    return isWhole ? currency(amount) : '฿${_money.format(amount)}';
  }
}

/// Capitalizes the first letter of the text and of every word after a
/// space, as the user types — e.g. "toyota c" -> "Toyota C". Leaves the
/// rest of each word untouched so intentional casing (e.g. "BMW") survives.
///
/// Used on short, name-like fields of the Post Car form (brand, model,
/// pickup address) so listings read consistently without forcing owners
/// to reach for Shift.
class CapitalizeWordsFormatter extends TextInputFormatter {
  static final _wordStart = RegExp(r'(^|\s)([a-z])');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final formatted = text.replaceAllMapped(
      _wordStart,
      (match) => '${match[1]}${match[2]!.toUpperCase()}',
    );
    return newValue.copyWith(text: formatted);
  }
}

/// Capitalizes the first letter of the text and the first letter after
/// sentence-ending punctuation (". ", "! ", "? "), as the user types.
/// Unlike [CapitalizeWordsFormatter] it leaves mid-sentence words alone,
/// which suits free-form prose like the car description.
class CapitalizeSentencesFormatter extends TextInputFormatter {
  static final _sentenceStart = RegExp(r'(^|[.!?]\s+)([a-z])');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final formatted = text.replaceAllMapped(
      _sentenceStart,
      (match) => '${match[1]}${match[2]!.toUpperCase()}',
    );
    return newValue.copyWith(text: formatted);
  }
}
