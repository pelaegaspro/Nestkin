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
  final String? assignedToName;
  final Timestamp? assignedAt;
  final bool isComplete;
  final int points;
  final String? completedById;
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
    this.assignedToName,
    this.assignedAt,
    required this.isComplete,
    required this.points,
    this.completedById,
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
        'assignedToName': assignedToName,
        'assignedAt': assignedAt,
        'isComplete': isComplete,
        'isCompleted': isComplete,
        'points': points,
        'completedById': completedById,
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
        assignedToName: map['assignedToName'] ?? map['assignedTo']?['displayName'],
        assignedAt: map['assignedAt'] as Timestamp?,
        isComplete: map['isComplete'] ?? map['isCompleted'] ?? false,
        points: map['points'] ?? 10,
        completedById: map['completedById'],
        dueDate: map['dueDate'] as Timestamp?,
        createdAt: map['createdAt'] ?? Timestamp.now(),
        completedAt: map['completedAt'] as Timestamp?,
      );
}
