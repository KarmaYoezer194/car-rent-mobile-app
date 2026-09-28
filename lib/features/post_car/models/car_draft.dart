import '../../../core/services/vin_decoder_service.dart';
import '../../../models/car_model.dart';

/// Mutable working state for the Post Car wizard (Section 9).
///
/// Deliberately a plain mutable class, not an immutable value type — it's
/// owned by exactly one widget (the wizard screen) and mutated step by step
/// as the user fills in the form, so `copyWith`-everywhere would just add
/// ceremony without buying safety.
class CarDraft {
  CarDraft();

  /// Pre-fills from an existing car when editing (My Cars → Edit).
  CarDraft.fromCar(CarModel car)
      : images = List.of(car.images),
        brand = car.brand,
        model = car.model,
        year = car.year,
        type = car.type,
        transmission = car.transmission,
        fuelType = car.fuelType,
        seats = car.seats,
        airConditioning = car.airConditioning,
        description = car.description,
        pricePerDay = car.pricePerDay,
        availableFrom = car.availableFrom,
        availableUntil = car.availableUntil,
        latitude = car.latitude,
        longitude = car.longitude,
        address = car.address,
        vin = car.vin,
        // A previously verified listing keeps its verification only while
        // brand/model/year stay as they were — rebuilt from the saved
        // values, since the original API response isn't stored.
        vinDecode = car.vinVerified
            ? VinDecodeResult(
                vin: car.vin,
                status: VinDecodeStatus.verified,
                make: car.brand,
                model: car.model,
                year: car.year,
              )
            : null;

  List<String> images = [];

  String brand = '';
  String model = '';
  int? year;
  String? type;
  String? transmission;
  String? fuelType;
  int seats = 5;
  bool airConditioning = true;
  String description = '';

  double? pricePerDay;
  DateTime? availableFrom;
  DateTime? availableUntil;

  double? latitude;
  double? longitude;
  String address = '';

  /// Optional. Whatever the owner typed, normalized on save.
  String vin = '';

  /// Latest vPIC decode for the VIN, or null if none has run yet.
  VinDecodeResult? vinDecode;

  /// Verified = the current VIN decoded cleanly AND brand/model/year still
  /// match what vPIC returned. Editing the make away from the decoded one
  /// drops the badge, so "verified" never vouches for details the API
  /// didn't confirm.
  bool get vinVerified {
    final decode = vinDecode;
    if (decode == null || decode.status != VinDecodeStatus.verified) return false;
    if (decode.vin != VinDecoderService.normalize(vin)) return false;
    String norm(String v) => v.trim().toLowerCase();
    return norm(decode.make) == norm(brand) && norm(decode.model) == norm(model) && decode.year == year;
  }

  bool get hasPhotos => images.isNotEmpty;

  bool get isCarInfoValid =>
      brand.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      year != null &&
      type != null &&
      transmission != null &&
      fuelType != null &&
      description.trim().length >= 10;

  bool get isPricingValid =>
      pricePerDay != null &&
      pricePerDay! > 0 &&
      availableFrom != null &&
      availableUntil != null &&
      availableUntil!.isAfter(availableFrom!);

  bool get isLocationValid => latitude != null && longitude != null && address.trim().isNotEmpty;

  bool get isReadyToPublish => hasPhotos && isCarInfoValid && isPricingValid && isLocationValid;

  CarModel toCarModel({
    required String id,
    required String ownerId,
    String status = 'available',
    double rating = 0,
    int reviewCount = 0,
    required DateTime createdAt,
  }) {
    return CarModel(
      id: id,
      ownerId: ownerId,
      brand: brand.trim(),
      model: model.trim(),
      year: year!,
      type: type!,
      transmission: transmission!,
      fuelType: fuelType!,
      seats: seats,
      airConditioning: airConditioning,
      description: description.trim(),
      pricePerDay: pricePerDay!,
      images: images,
      latitude: latitude!,
      longitude: longitude!,
      address: address.trim(),
      vin: VinDecoderService.normalize(vin),
      vinVerified: vinVerified,
      status: status,
      rating: rating,
      reviewCount: reviewCount,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      createdAt: createdAt,
    );
  }
}
