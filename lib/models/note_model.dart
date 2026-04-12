import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String title;
  final String body;
  final String createdBy;
  final String createdByName;
  final String? authorPhotoUrl;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool isPinned;
  final String color;
  final List<String> attachments;

  const NoteModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdByName,
    this.authorPhotoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.color,
    required this.attachments,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'authorPhotoUrl': authorPhotoUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isPinned': isPinned,
        'color': color,
        'attachments': attachments,
      };

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? 'User',
      authorPhotoUrl: map['authorPhotoUrl'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      isPinned: map['isPinned'] ?? false,
      color: map['color'] ?? '#FFF8B8',
      attachments: List<String>.from(map['attachments'] ?? const []),
    );
  }
}
