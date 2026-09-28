/// Platform commission on bookings — display/tracking only (no payment
/// routing). The split is computed once, when a booking is created, and the
/// resulting amounts are stored on the booking, so a later rate change never
/// rewrites existing bookings.
///
/// The rate is also enforced by `firestore.rules` (`isValidBookingPricing`);
/// change both together.
class PlatformPricing {
  PlatformPricing._();

  static const double commissionRate = 0.15;

  /// Splits a renter's [total] into the platform's commission and the
  /// owner's payout. Commission is rounded to 2 decimals (satang), and
  /// payout is the remainder, so `commission + payout == total` exactly.
  static ({double commission, double payout}) split(double total) {
    final commission = _toCents(total * commissionRate);
    return (commission: commission, payout: _toCents(total - commission));
  }

  static double _toCents(double value) => (value * 100).round() / 100;
}
