import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal_plan_model.dart';
import '../models/recipe_model.dart';

class MealPlanRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<MealPlanModel?> mealPlanStream({
    required String householdId,
    required DateTime weekStart,
  }) {
    final weekId = weekIdFor(weekStart);
    return _db
        .collection('households')
        .doc(householdId)
        .collection('mealPlan')
        .doc(weekId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }

      return MealPlanModel.fromMap({
        ...doc.data()!,
        'id': doc.id,
      });
    });
  }

  Stream<List<RecipeModel>> recipesStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('recipes')
        .orderBy('title')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecipeModel.fromMap({
                    ...doc.data(),
                    'id': doc.id,
                  }))
              .toList(),
        );
  }

  Future<void> saveMealSlot({
    required String householdId,
    required DateTime weekStart,
    required String dayKey,
    required String mealType,
    required MealSlotModel slot,
  }) async {
    try {
      final weekId = weekIdFor(weekStart);
      await _db
          .collection('households')
          .doc(householdId)
          .collection('mealPlan')
          .doc(weekId)
          .set({
        'id': weekId,
        'weekStartDate': Timestamp.fromDate(weekStart),
        'meals': {
          dayKey: {mealType: slot.toMap()},
        },
      }, SetOptions(merge: true));
    } on FirebaseException {
      throw Exception('Could not save that meal right now. Please try again.');
    }
  }

  Future<void> addRecipe({
    required String householdId,
    required RecipeModel recipe,
  }) async {
    try {
      final ref = _db.collection('households').doc(householdId).collection('recipes').doc();
      await ref.set(recipe.toMap()..['id'] = ref.id);
    } on FirebaseException {
      throw Exception('Could not save that recipe right now. Please try again.');
    }
  }

  Future<void> deleteRecipe({
    required String householdId,
    required String recipeId,
  }) async {
    try {
      await _db.collection('households').doc(householdId).collection('recipes').doc(recipeId).delete();
    } on FirebaseException {
      throw Exception('Could not delete that recipe right now. Please try again.');
    }
  }

  Future<void> addIngredientsToShoppingList({
    required String householdId,
    required RecipeModel recipe,
  }) async {
    try {
      await _db.collection('households').doc(householdId).collection('lists').doc('grocery').set({
        'items': FieldValue.arrayUnion(recipe.ingredients),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      throw Exception('Could not add ingredients to the shopping list right now.');
    }
  }

  String weekIdFor(DateTime date) {
    final weekStart = startOfWeek(date);
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  DateTime startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
  }
}
