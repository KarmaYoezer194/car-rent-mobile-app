/// Fixed vocabularies for car listings — shared between the Home filter
/// sheet (Phase 3) and the Post Car form (Phase 4) so both always offer the
/// same choices as what's actually stored in Firestore.
class CarOptions {
  CarOptions._();

  static const List<String> types = [
    'Sedan',
    'SUV',
    'Hatchback',
    'Pickup',
    'Van',
    'Coupe',
    'Convertible',
  ];

  static const List<String> transmissions = ['Automatic', 'Manual'];

  static const List<String> fuelTypes = ['Petrol', 'Diesel', 'Electric', 'Hybrid'];
}

/// Values stored in a car document's `status` field (Section 9/10).
class CarStatus {
  CarStatus._();

  static const String available = 'available';
  static const String rented = 'rented';
  static const String disabled = 'disabled';
}
