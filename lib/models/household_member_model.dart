import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdMemberModel {
  final String id;
  final String householdId;
  final String userId;
  final Map<String, dynamic> household;
  final Map<String, dynamic> user;
  final String role;
  final String status;
  final Timestamp joinedAt;

  HouseholdMemberModel({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.household,
    required this.user,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'householdId': householdId,
        'userId': userId,
        'household': household,
        'user': user,
        'role': role,
        'status': status,
        'joinedAt': joinedAt,
      };

  factory HouseholdMemberModel.fromMap(Map<String, dynamic> map) => HouseholdMemberModel(
        id: map['id'] ?? '',
        householdId: map['householdId'] ?? '',
        userId: map['userId'] ?? '',
        household: Map<String, dynamic>.from(map['household'] ?? {}),
        user: Map<String, dynamic>.from(map['user'] ?? {}),
        role: map['role'] ?? 'member',
        status: map['status'] ?? 'active',
        joinedAt: map['joinedAt'] ?? Timestamp.now(),
      );
}
