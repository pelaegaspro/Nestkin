import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String createdById;
  final Map<String, dynamic> createdBy;
  final String? assignedToId;
  final Map<String, dynamic>? assignedTo;
  final bool isComplete;
  final Timestamp? dueDate;
  final Timestamp createdAt;
  final Timestamp? completedAt;

  TaskModel({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.createdById,
    required this.createdBy,
    this.assignedToId,
    this.assignedTo,
    required this.isComplete,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'householdId': householdId,
        'title': title,
        'description': description,
        'createdById': createdById,
        'createdBy': createdBy,
        'assignedToId': assignedToId,
        'assignedTo': assignedTo,
        'isComplete': isComplete,
        'dueDate': dueDate,
        'createdAt': createdAt,
        'completedAt': completedAt,
      };

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
        id: map['id'] ?? '',
        householdId: map['householdId'] ?? '',
        title: map['title'] ?? '',
        description: map['description'],
        createdById: map['createdById'] ?? '',
        createdBy: Map<String, dynamic>.from(map['createdBy'] ?? {}),
        assignedToId: map['assignedToId'],
        assignedTo: map['assignedTo'] != null ? Map<String, dynamic>.from(map['assignedTo']) : null,
        isComplete: map['isComplete'] ?? false,
        dueDate: map['dueDate'] as Timestamp?,
        createdAt: map['createdAt'] ?? Timestamp.now(),
        completedAt: map['completedAt'] as Timestamp?,
      );
}
