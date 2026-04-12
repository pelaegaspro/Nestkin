import 'package:cloud_firestore/cloud_firestore.dart';

class MealSlotModel {
  final String name;
  final String? recipeId;
  final String? preparedBy;
  final String? preparedByName;

  const MealSlotModel({
    required this.name,
    this.recipeId,
    this.preparedBy,
    this.preparedByName,
  });

  bool get isEmpty => name.trim().isEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'recipeId': recipeId,
        'preparedBy': preparedBy,
        'preparedByName': preparedByName,
      };

  factory MealSlotModel.fromMap(Map<String, dynamic>? map) {
    return MealSlotModel(
      name: map?['name'] ?? '',
      recipeId: map?['recipeId'],
      preparedBy: map?['preparedBy'],
      preparedByName: map?['preparedByName'],
    );
  }
}

class MealPlanModel {
  final String id;
  final Timestamp weekStartDate;
  final Map<String, Map<String, MealSlotModel>> meals;

  const MealPlanModel({
    required this.id,
    required this.weekStartDate,
    required this.meals,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'weekStartDate': weekStartDate,
        'meals': meals.map(
          (day, slots) => MapEntry(
            day,
            slots.map((mealType, slot) => MapEntry(mealType, slot.toMap())),
          ),
        ),
      };

  factory MealPlanModel.fromMap(Map<String, dynamic> map) {
    final rawMeals = Map<String, dynamic>.from(map['meals'] ?? const {});
    return MealPlanModel(
      id: map['id'] ?? '',
      weekStartDate: map['weekStartDate'] ?? Timestamp.now(),
      meals: rawMeals.map(
        (day, value) => MapEntry(
          day,
          Map<String, dynamic>.from(value).map(
            (mealType, slot) => MapEntry(
              mealType,
              MealSlotModel.fromMap(Map<String, dynamic>.from(slot ?? const {})),
            ),
          ),
        ),
      ),
    );
  }
}
