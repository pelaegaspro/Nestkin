import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementModel {
  final String id;
  final String fromUid;
  final String toUid;
  final double amount;
  final Timestamp settledAt;
  final String note;

  const SettlementModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    required this.settledAt,
    required this.note,
  });

  SettlementModel copyWith({
    String? id,
    String? fromUid,
    String? toUid,
    double? amount,
    Timestamp? settledAt,
    String? note,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      amount: amount ?? this.amount,
      settledAt: settledAt ?? this.settledAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUid': fromUid,
      'toUid': toUid,
      'amount': amount,
      'settledAt': settledAt,
      'note': note,
    };
  }

  factory SettlementModel.fromMap(Map<String, dynamic> map) {
    return SettlementModel(
      id: (map['id'] ?? '') as String,
      fromUid: (map['fromUid'] ?? '') as String,
      toUid: (map['toUid'] ?? '') as String,
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      settledAt: (map['settledAt'] ?? Timestamp.now()) as Timestamp,
      note: (map['note'] ?? '') as String,
    );
  }
}
