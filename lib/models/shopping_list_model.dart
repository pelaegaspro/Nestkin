import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListModel {
  final String id;
  final String name;
  final String createdBy;
  final String createdByName;
  final Timestamp createdAt;
  final String emoji;

  const ShoppingListModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.emoji,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt,
        'emoji': emoji,
      };

  factory ShoppingListModel.fromMap(Map<String, dynamic> map) {
    return ShoppingListModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? 'Member',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      emoji: map['emoji'] ?? '\u{1F6D2}',
    );
  }
}
