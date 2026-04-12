import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

import '../models/household_member_model.dart';

class SOSAlertModel {
  final String uid;
  final bool isActive;
  final Timestamp triggeredAt;
  final Timestamp? resolvedAt;
  final double lat;
  final double lng;
  final String triggeredByName;
  final String triggeredByColor;
  final String message;

  const SOSAlertModel({
    required this.uid,
    required this.isActive,
    required this.triggeredAt,
    required this.resolvedAt,
    required this.lat,
    required this.lng,
    required this.triggeredByName,
    required this.triggeredByColor,
    required this.message,
  });

  factory SOSAlertModel.fromMap(String uid, Map<String, dynamic> map) {
    return SOSAlertModel(
      uid: uid,
      isActive: (map['isActive'] ?? false) as bool,
      triggeredAt: (map['triggeredAt'] ?? Timestamp.now()) as Timestamp,
      resolvedAt: map['resolvedAt'] as Timestamp?,
      lat: ((map['lat'] ?? 0) as num).toDouble(),
      lng: ((map['lng'] ?? 0) as num).toDouble(),
      triggeredByName: (map['triggeredByName'] ?? 'Family member') as String,
      triggeredByColor: (map['triggeredByColor'] ?? '#C62828') as String,
      message: (map['message'] ?? 'I need help!') as String,
    );
  }
}

class SOSService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SOSAlertModel>> activeAlertsStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('sos')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SOSAlertModel.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt)),
        );
  }

  Stream<List<SOSAlertModel>> historyStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('sos')
        .orderBy('triggeredAt', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SOSAlertModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> triggerSOS({
    required String householdId,
    required HouseholdMemberModel member,
    String message = 'I need help!',
  }) async {
    try {
      final position = await _getCurrentPosition();
      await _db
          .collection('households')
          .doc(householdId)
          .collection('sos')
          .doc(member.userId)
          .set({
        'isActive': true,
        'triggeredAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'lat': position.latitude,
        'lng': position.longitude,
        'triggeredByName': (member.user['displayName'] ??
                member.user['phoneNumber'] ??
                'Member')
            .toString(),
        'triggeredByColor': member.color ?? '#C62828',
        'message': message,
      }, SetOptions(merge: true));

      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: const [0, 700, 250, 700, 250, 700],
          repeat: 0,
        );
      }
    } on FirebaseException {
      throw Exception('Could not send your SOS right now. Please try again.');
    }
  }

  Future<void> resolveSOS({
    required String householdId,
    required String uid,
  }) async {
    try {
      await _db
          .collection('households')
          .doc(householdId)
          .collection('sos')
          .doc(uid)
          .set({
        'isActive': false,
        'resolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await Vibration.cancel();
    } on FirebaseException {
      throw Exception(
          'Could not resolve that SOS right now. Please try again.');
    }
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to send an SOS.');
    }

    return Geolocator.getCurrentPosition();
  }
}
