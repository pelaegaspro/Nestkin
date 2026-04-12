import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItemModel {
  final String id;
  final String name;
  final String qty;
  final String unit;
  final String addedBy;
  final String addedByName;
  final String addedByColor;
  final bool isChecked;
  final String? checkedBy;
  final Timestamp? checkedAt;
  final Timestamp addedAt;

  const ShoppingItemModel({
    required this.id,
    required this.name,
    required this.qty,
    required this.unit,
    required this.addedBy,
    required this.addedByName,
    required this.addedByColor,
    required this.isChecked,
    this.checkedBy,
    this.checkedAt,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'qty': qty,
        'unit': unit,
        'addedBy': addedBy,
        'addedByName': addedByName,
        'addedByColor': addedByColor,
        'isChecked': isChecked,
        'checkedBy': checkedBy,
        'checkedAt': checkedAt,
        'addedAt': addedAt,
      };

  ShoppingItemModel copyWith({
    String? id,
    String? name,
    String? qty,
    String? unit,
    String? addedBy,
    String? addedByName,
    String? addedByColor,
    bool? isChecked,
    String? checkedBy,
    Timestamp? checkedAt,
    Timestamp? addedAt,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      addedBy: addedBy ?? this.addedBy,
      addedByName: addedByName ?? this.addedByName,
      addedByColor: addedByColor ?? this.addedByColor,
      isChecked: isChecked ?? this.isChecked,
      checkedBy: checkedBy ?? this.checkedBy,
      checkedAt: checkedAt ?? this.checkedAt,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory ShoppingItemModel.fromMap(Map<String, dynamic> map) {
    return ShoppingItemModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      qty: map['qty'] ?? '',
      unit: map['unit'] ?? '',
      addedBy: map['addedBy'] ?? '',
      addedByName: map['addedByName'] ?? 'Member',
      addedByColor: map['addedByColor'] ?? '#0B5C68',
      isChecked: map['isChecked'] ?? false,
      checkedBy: map['checkedBy'],
      checkedAt: map['checkedAt'],
      addedAt: map['addedAt'] ?? Timestamp.now(),
    );
  }
}
