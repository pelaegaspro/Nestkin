import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeModel {
  final String id;
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String? imageUrl;
  final String addedBy;
  final List<String> tags;
  final Timestamp createdAt;

  const RecipeModel({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.steps,
    this.imageUrl,
    required this.addedBy,
    required this.tags,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'ingredients': ingredients,
        'steps': steps,
        'imageUrl': imageUrl,
        'addedBy': addedBy,
        'tags': tags,
        'createdAt': createdAt,
      };

  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    return RecipeModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      ingredients: List<String>.from(map['ingredients'] ?? const []),
      steps: List<String>.from(map['steps'] ?? const []),
      imageUrl: map['imageUrl'],
      addedBy: map['addedBy'] ?? '',
      tags: List<String>.from(map['tags'] ?? const []),
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }
}
