import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a document in the top-level `cars` collection (Section 24).
///
/// `rating`/`reviewCount` are denormalized aggregates — Phase 8 (reviews)
/// updates them whenever a review is created so Home/Car Details never need
/// to scan the `reviews` collection just to show a star rating.
///
/// `availableFrom`/`availableUntil` aren't in Section 24's compact schema
/// listing, but Section 9 explicitly requires storing an owner-defined
/// availability window ("The system must prevent users from booking
/// unavailable dates") — Phase 5's booking overlap check reads them.
class CarModel {
  const CarModel({
    required this.id,
    required this.ownerId,
    required this.brand,
    required this.model,
    required this.year,
    required this.type,
    required this.transmission,
    required this.fuelType,
    required this.seats,
    required this.airConditioning,
    required this.description,
    required this.pricePerDay,
    required this.images,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    this.rating = 0,
    this.reviewCount = 0,
    this.availableFrom,
    this.availableUntil,
    required this.createdAt,
    this.vin = '',
    this.vinVerified = false,
  });

  final String id;
  final String ownerId;
  final String brand;
  final String model;
  final int year;
  final String type;
  final String transmission;
  final String fuelType;
  final int seats;
  final bool airConditioning;
  final String description;
  final double pricePerDay;
  final List<String> images;
  final double latitude;
  final double longitude;
  final String address;
  final String status;
  final double rating;
  final int reviewCount;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final DateTime createdAt;

  /// Uppercased 17-character VIN, or '' if the owner didn't enter one.
  /// Stored but never displayed in the app — only [vinVerified] is shown.
  final String vin;

  /// True only if NHTSA's vPIC decoded [vin] cleanly and the listing's
  /// brand/model/year still matched that decode when it was saved. Set by
  /// the owner's client (there's no backend to re-check it), so it's a
  /// trust signal, not a guarantee — see README.
  final bool vinVerified;

  String get title => '$brand $model';
  String get coverImage => images.isNotEmpty ? images.first : '';
  bool get isAvailable => status == 'available';

  factory CarModel.fromMap(Map<String, dynamic> map, String id) {
    return CarModel(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: (map['year'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? '',
      transmission: map['transmission'] as String? ?? '',
      fuelType: map['fuelType'] as String? ?? '',
      seats: (map['seats'] as num?)?.toInt() ?? 0,
      airConditioning: map['airConditioning'] as bool? ?? false,
      description: map['description'] as String? ?? '',
      pricePerDay: (map['pricePerDay'] as num?)?.toDouble() ?? 0,
      images: List<String>.from(map['images'] as List? ?? const []),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String? ?? '',
      status: map['status'] as String? ?? 'available',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      availableFrom: (map['availableFrom'] as Timestamp?)?.toDate(),
      availableUntil: (map['availableUntil'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      vin: map['vin'] as String? ?? '',
      vinVerified: map['vinVerified'] as bool? ?? false,
    );
  }

  factory CarModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return CarModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'brand': brand,
      'model': model,
      'year': year,
      'type': type,
      'transmission': transmission,
      'fuelType': fuelType,
      'seats': seats,
      'airConditioning': airConditioning,
      'description': description,
      'pricePerDay': pricePerDay,
      'images': images,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'vin': vin,
      'vinVerified': vinVerified,
      'status': status,
      'rating': rating,
      'reviewCount': reviewCount,
      if (availableFrom != null) 'availableFrom': Timestamp.fromDate(availableFrom!),
      if (availableUntil != null) 'availableUntil': Timestamp.fromDate(availableUntil!),
    };
  }
}
