import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineModel {
  final String id;
  final String name;
  final String dosage;
  final String assignedTo;
  final String assignedToName;
  final String assignedToColor;
  final List<String> reminderTimes;
  final Timestamp startDate;
  final Timestamp? endDate;
  final String createdBy;

  const MedicineModel({
    required this.id,
    required this.name,
    required this.dosage,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedToColor,
    required this.reminderTimes,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
  });

  MedicineModel copyWith({
    String? id,
    String? name,
    String? dosage,
    String? assignedTo,
    String? assignedToName,
    String? assignedToColor,
    List<String>? reminderTimes,
    Timestamp? startDate,
    Timestamp? endDate,
    bool clearEndDate = false,
    String? createdBy,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedToColor: assignedToColor ?? this.assignedToColor,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedToColor': assignedToColor,
      'reminderTimes': reminderTimes,
      'startDate': startDate,
      'endDate': endDate,
      'createdBy': createdBy,
    };
  }

  factory MedicineModel.fromMap(Map<String, dynamic> map) {
    return MedicineModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      dosage: (map['dosage'] ?? '') as String,
      assignedTo: (map['assignedTo'] ?? '') as String,
      assignedToName: (map['assignedToName'] ?? '') as String,
      assignedToColor: (map['assignedToColor'] ?? '#0B5C68') as String,
      reminderTimes: List<String>.from(map['reminderTimes'] ?? const []),
      startDate: (map['startDate'] ?? Timestamp.now()) as Timestamp,
      endDate: map['endDate'] as Timestamp?,
      createdBy: (map['createdBy'] ?? map['assignedTo'] ?? '') as String,
    );
  }
}
