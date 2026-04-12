import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyLocationModel {
  final String userId;
  final GeoPoint geopoint;
  final String geohash;
  final String memberName;
  final String memberColor;
  final int? battery;
  final Timestamp lastUpdated;
  final bool isVisible;

  const FamilyLocationModel({
    required this.userId,
    required this.geopoint,
    required this.geohash,
    required this.memberName,
    required this.memberColor,
    this.battery,
    required this.lastUpdated,
    required this.isVisible,
  });

  factory FamilyLocationModel.fromMap(Map<String, dynamic> map) {
    return FamilyLocationModel(
      userId: map['userId'] ?? '',
      geopoint: map['geopoint'] ?? const GeoPoint(0, 0),
      geohash: map['geohash'] ?? '',
      memberName: map['memberName'] ?? 'Member',
      memberColor: map['memberColor'] ?? '#0B5C68',
      battery: map['battery'],
      lastUpdated: map['lastUpdated'] ?? Timestamp.now(),
      isVisible: map['isVisible'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'geopoint': geopoint,
        'geohash': geohash,
        'memberName': memberName,
        'memberColor': memberColor,
        'battery': battery,
        'lastUpdated': lastUpdated,
        'isVisible': isVisible,
      };
}
