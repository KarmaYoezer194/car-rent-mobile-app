/// Tuning knobs for live location sharing during an active rental.
///
/// Kept in one place so "change the interval" means editing a number here,
/// not hunting through the tracking code.
class TrackingConfig {
  TrackingConfig._();

  /// How often the renter's device sends its latest position, whether or
  /// not it has moved — a steady heartbeat is what lets the owner tell
  /// "parked" (fresh timestamp, same spot) apart from "phone went offline"
  /// (timestamp stops advancing). Inside the spec's 30-60 s window.
  static const Duration heartbeatInterval = Duration(seconds: 45);

  /// The owner's map flags the location as stale once it's this old —
  /// roughly two and a half missed heartbeats.
  static const Duration staleAfter = Duration(minutes: 2);
}
