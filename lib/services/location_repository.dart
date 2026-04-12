import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../models/family_location_model.dart';

class LocationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<FamilyLocationModel>> locationStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('locations')
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FamilyLocationModel.fromMap({
                    ...doc.data(),
                    'userId': doc.id,
                  }))
              .toList(),
        );
  }

  Future<void> updateLocation({
    required String householdId,
    required String userId,
    required double latitude,
    required double longitude,
    required String memberName,
    required String memberColor,
    int? battery,
    required bool isVisible,
  }) async {
    try {
      final geo = GeoFirePoint(GeoPoint(latitude, longitude));
      await _db.collection('households').doc(householdId).collection('locations').doc(userId).set({
        'userId': userId,
        'geopoint': geo.geopoint,
        'geohash': geo.geohash,
        'memberName': memberName,
        'memberColor': memberColor,
        'battery': battery,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isVisible': isVisible,
      }, SetOptions(merge: true));
    } on FirebaseException {
      throw Exception('Could not update your location right now.');
    }
  }

  Future<void> setVisibility({
    required String householdId,
    required String userId,
    required bool isVisible,
  }) async {
    try {
      await _db.collection('households').doc(householdId).collection('locations').doc(userId).set({
        'isVisible': isVisible,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      throw Exception('Could not update location sharing right now.');
    }
  }

  Future<GeoPoint?> getHomeLocation(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).collection('settings').doc('location').get();
    return doc.data()?['homeLocation'] as GeoPoint?;
  }
}
