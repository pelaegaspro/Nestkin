import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final String? currentHouseholdId;
  final List<String> fcmTokens;
  final Timestamp createdAt;
  final Timestamp lastActiveAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.displayName,
    this.photoUrl,
    this.currentHouseholdId,
    required this.fcmTokens,
    required this.createdAt,
    required this.lastActiveAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'currentHouseholdId': currentHouseholdId,
        'fcmTokens': fcmTokens,
        'createdAt': createdAt,
        'lastActiveAt': lastActiveAt,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] ?? '',
        phoneNumber: map['phoneNumber'] ?? '',
        email: map['email'],
        displayName: map['displayName'] ?? 'User',
        photoUrl: map['photoUrl'],
        currentHouseholdId: map['currentHouseholdId'],
        fcmTokens: List<String>.from(map['fcmTokens'] ?? []),
        createdAt: map['createdAt'] ?? Timestamp.now(),
        lastActiveAt: map['lastActiveAt'] ?? Timestamp.now(),
      );
}
