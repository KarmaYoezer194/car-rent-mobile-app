/// User-facing copy that is reused across multiple screens (empty states,
/// generic errors, nav labels). Feature-specific copy stays local to that
/// feature's screen file.
class AppStrings {
  AppStrings._();

  static const String appName = 'CarRent';

  // Bottom navigation
  static const String navHome = 'Home';
  static const String navPost = 'Post';
  static const String navBooking = 'Booking';
  static const String navProfile = 'Profile';

  // Generic states
  static const String loading = 'Loading…';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String retry = 'Retry';

  // Empty states (Section 28)
  static const String noCarsAvailable = 'No cars available yet.';
  static const String noActiveRentals = "You don't have any active rentals.";
  static const String noBookingRequests = 'No booking requests.';
  static const String noCarsPosted = "You haven't posted a car yet.";
  static const String noFavorites = "You haven't favorited any cars yet.";
  static const String noNotifications = "You're all caught up.";
  static const String noReviews = 'No reviews yet.';
}
