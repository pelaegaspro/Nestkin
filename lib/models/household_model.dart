import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdModel {
  final String id;
  final String name;
  final String adminId;
  final Map<String, dynamic> admin;
  final String? description;
  final String inviteCode;
  final Timestamp createdAt;

  HouseholdModel({
    required this.id,
    required this.name,
    required this.adminId,
    required this.admin,
    this.description,
    required this.inviteCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'adminId': adminId,
        'admin': admin,
        'description': description,
        'inviteCode': inviteCode,
        'createdAt': createdAt,
      };

  factory HouseholdModel.fromMap(Map<String, dynamic> map) => HouseholdModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        adminId: map['adminId'] ?? '',
        admin: Map<String, dynamic>.from(map['admin'] ?? {}),
        description: map['description'],
        inviteCode: map['inviteCode'] ?? '',
        createdAt: map['createdAt'] ?? Timestamp.now(),
      );
}
