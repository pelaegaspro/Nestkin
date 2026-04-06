import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String? photoUrl;
  final List<String> fcmTokens;
  final Timestamp createdAt;
  final Timestamp lastActiveAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.photoUrl,
    required this.fcmTokens,
    required this.createdAt,
    required this.lastActiveAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'fcmTokens': fcmTokens,
        'createdAt': createdAt,
        'lastActiveAt': lastActiveAt,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] ?? '',
        phoneNumber: map['phoneNumber'] ?? '',
        displayName: map['displayName'] ?? 'User',
        photoUrl: map['photoUrl'],
        fcmTokens: List<String>.from(map['fcmTokens'] ?? []),
        createdAt: map['createdAt'] ?? Timestamp.now(),
        lastActiveAt: map['lastActiveAt'] ?? Timestamp.now(),
      );
}
