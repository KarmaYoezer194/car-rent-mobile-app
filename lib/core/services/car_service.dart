import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/car_model.dart';
import '../constants/car_options.dart';

/// All `cars` and `favorites` collection access goes through here — mirrors
/// [AuthService]'s role for `users`.
class CarService {
  CarService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _carsRef => _firestore.collection('cars');
  CollectionReference<Map<String, dynamic>> get _favoritesRef => _firestore.collection('favorites');

  /// All cars currently listed as available, newest first. Home applies
  /// search text and filter chips to this list client-side — the catalog
  /// is small enough for that to be simpler and cheaper than composing many
  /// Firestore composite indexes for every filter combination.
  Stream<List<CarModel>> streamAvailableCars() {
    return _carsRef
        .where('status', isEqualTo: CarStatus.available)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CarModel.fromSnapshot).toList());
  }

  Stream<CarModel?> streamCar(String carId) {
    return _carsRef.doc(carId).snapshots().map(
          (doc) => doc.exists ? CarModel.fromSnapshot(doc) : null,
        );
  }

  /// Live set of car ids the given user has favorited.
  Stream<Set<String>> favoriteCarIds(String uid) {
    return _favoritesRef.doc(uid).snapshots().map(
          (doc) => Set<String>.from(doc.data()?['carIds'] as List? ?? const []),
        );
  }

  Future<void> setFavorite(String uid, String carId, bool isFavorite) {
    return _favoritesRef.doc(uid).set(
      {
        'carIds': isFavorite
            ? FieldValue.arrayUnion([carId])
            : FieldValue.arrayRemove([carId]),
      },
      SetOptions(merge: true),
    );
  }

  /// Fetches the cars for a set of favorited ids.
  ///
  /// `whereIn` caps out at 10 values, which is a real limitation once
  /// someone favorites more than that — acceptable for now given the app
  /// has no way to accumulate many favorites yet; revisit (chunk into
  /// batches of 10) if that becomes a real usage pattern.
  Stream<List<CarModel>> streamCarsByIds(Set<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    final limited = ids.take(10).toList();
    return _carsRef
        .where(FieldPath.documentId, whereIn: limited)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CarModel.fromSnapshot).toList());
  }

  /// All cars owned by [ownerId], any status — backs "My Cars" (Section 10).
  Stream<List<CarModel>> streamCarsByOwner(String ownerId) {
    return _carsRef
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CarModel.fromSnapshot).toList());
  }

  /// Publishes a new listing (Section 9, step 5) and returns its id.
  Future<String> createCar(CarModel car) async {
    final doc = await _carsRef.add({
      ...car.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Saves edits to an existing listing. Rules only let the actual owner do
  /// this (Section 26).
  Future<void> updateCar(String carId, Map<String, dynamic> data) {
    return _carsRef.doc(carId).update(data);
  }

  Future<void> setCarStatus(String carId, String status) {
    return _carsRef.doc(carId).update({'status': status});
  }

  Future<void> deleteCar(String carId) {
    return _carsRef.doc(carId).delete();
  }
}
