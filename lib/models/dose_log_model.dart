import 'package:cloud_firestore/cloud_firestore.dart';

class DoseLogModel {
  final String id;
  final Timestamp scheduledTime;
  final Timestamp? takenAt;
  final String status;
  final String householdId;
  final String medicineId;

  const DoseLogModel({
    required this.id,
    required this.scheduledTime,
    required this.takenAt,
    required this.status,
    required this.householdId,
    required this.medicineId,
  });

  DoseLogModel copyWith({
    String? id,
    Timestamp? scheduledTime,
    Timestamp? takenAt,
    bool clearTakenAt = false,
    String? status,
    String? householdId,
    String? medicineId,
  }) {
    return DoseLogModel(
      id: id ?? this.id,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      takenAt: clearTakenAt ? null : (takenAt ?? this.takenAt),
      status: status ?? this.status,
      householdId: householdId ?? this.householdId,
      medicineId: medicineId ?? this.medicineId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheduledTime': scheduledTime,
      'takenAt': takenAt,
      'status': status,
      'householdId': householdId,
      'medicineId': medicineId,
    };
  }

  factory DoseLogModel.fromMap(Map<String, dynamic> map) {
    return DoseLogModel(
      id: (map['id'] ?? '') as String,
      scheduledTime: (map['scheduledTime'] ?? Timestamp.now()) as Timestamp,
      takenAt: map['takenAt'] as Timestamp?,
      status: (map['status'] ?? 'pending') as String,
      householdId: (map['householdId'] ?? '') as String,
      medicineId: (map['medicineId'] ?? '') as String,
    );
  }
}
