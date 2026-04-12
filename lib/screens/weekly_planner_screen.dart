import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household_member_model.dart';
import '../models/meal_plan_model.dart';
import '../models/recipe_model.dart';
import '../services/firestore_service.dart';
import '../services/meal_plan_repository.dart';
import '../widgets/meal_cell_widget.dart';

class WeeklyPlannerScreen extends StatefulWidget {
  final String householdId;

  const WeeklyPlannerScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  final _repository = MealPlanRepository();
  final _fs = FirestoreService();
  late DateTime _weekStart;

  static const _dayKeys = [
    ('monday', 'Mon'),
    ('tuesday', 'Tue'),
    ('wednesday', 'Wed'),
    ('thursday', 'Thu'),
    ('friday', 'Fri'),
    ('saturday', 'Sat'),
    ('sunday', 'Sun'),
  ];

  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];

  @override
  void initState() {
    super.initState();
    _weekStart = _repository.startOfWeek(DateTime.now());
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _showMealEditor({
    required String dayKey,
    required String mealType,
    required MealSlotModel currentSlot,
    required List<RecipeModel> recipes,
    required List<HouseholdMemberModel> members,
  }) async {
    final nameController = TextEditingController(text: currentSlot.name);
    RecipeModel? selectedRecipe = _firstWhereOrNull(recipes, (recipe) => recipe.id == currentSlot.recipeId);
    HouseholdMemberModel? selectedMember =
        _firstWhereOrNull(members, (member) => member.userId == currentSlot.preparedBy);

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Edit ${mealType[0].toUpperCase()}${mealType.substring(1)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Meal name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedRecipe?.id,
                  decoration: const InputDecoration(labelText: 'Recipe'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No recipe')),
                    ...recipes.map(
                      (recipe) => DropdownMenuItem<String?>(
                        value: recipe.id,
                        child: Text(recipe.title),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setLocalState(() {
                      selectedRecipe = _firstWhereOrNull(recipes, (recipe) => recipe.id == value);
                      if (selectedRecipe != null && nameController.text.trim().isEmpty) {
                        nameController.text = selectedRecipe!.title;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedMember?.userId,
                  decoration: const InputDecoration(labelText: 'Who is cooking?'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    ...members.map(
                      (member) => DropdownMenuItem<String?>(
                        value: member.userId,
                        child: Text((member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setLocalState(() {
                      selectedMember = _firstWhereOrNull(members, (member) => member.userId == value);
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final slot = MealSlotModel(
                    name: nameController.text.trim(),
                    recipeId: selectedRecipe?.id,
                    preparedBy: selectedMember?.userId,
                    preparedByName: selectedMember?.user['displayName']?.toString(),
                  );
                  await _repository.saveMealSlot(
                    householdId: widget.householdId,
                    weekStart: _weekStart,
                    dayKey: dayKey,
                    mealType: mealType,
                    slot: slot,
                  );
                  if (selectedRecipe != null) {
                    await _repository.addIngredientsToShoppingList(
                      householdId: widget.householdId,
                      recipe: selectedRecipe!,
                    );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> _showRecipeBox(List<RecipeModel> recipes) async {
    final titleController = TextEditingController();
    final ingredientsController = TextEditingController();
    final stepsController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Recipe Box', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              ...recipes.map(
                (recipe) => ListTile(
                  title: Text(recipe.title),
                  subtitle: Text('${recipe.ingredients.length} ingredients'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await _repository.deleteRecipe(
                        householdId: widget.householdId,
                        recipeId: recipe.id,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
              const Divider(),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Recipe title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ingredientsController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ingredients (one per line)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stepsController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Steps (one per line)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final recipe = RecipeModel(
                      id: '',
                      title: titleController.text.trim(),
                      ingredients: ingredientsController.text
                          .split('\n')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(),
                      steps: stepsController.text
                          .split('\n')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(),
                      imageUrl: null,
                      addedBy: FirebaseAuth.instance.currentUser!.uid,
                      tags: const [],
                      createdAt: Timestamp.now(),
                    );
                    await _repository.addRecipe(
                      householdId: widget.householdId,
                      recipe: recipe,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                      );
                    }
                  }
                },
                child: const Text('Add Recipe'),
              ),
            ],
          ),
        ),
      ),
    );

    titleController.dispose();
    ingredientsController.dispose();
    stepsController.dispose();
  }

  MealSlotModel _slotFor(MealPlanModel? plan, String day, String mealType) {
    return plan?.meals[day]?[mealType] ?? const MealSlotModel(name: '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Meal Planner')),
      body: FutureBuilder<List<HouseholdMemberModel>>(
        future: _fs.getHouseholdMembers(widget.householdId),
        builder: (context, membersSnapshot) {
          final members = membersSnapshot.data ?? const <HouseholdMemberModel>[];
          return StreamBuilder<List<RecipeModel>>(
            stream: _repository.recipesStream(widget.householdId),
            builder: (context, recipesSnapshot) {
              final recipes = recipesSnapshot.data ?? const <RecipeModel>[];
              return StreamBuilder<MealPlanModel?>(
                stream: _repository.mealPlanStream(
                  householdId: widget.householdId,
                  weekStart: _weekStart,
                ),
                builder: (context, planSnapshot) {
                  final plan = planSnapshot.data;
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Week of ${_repository.weekIdFor(_weekStart)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showRecipeBox(recipes),
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('Recipe Box'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._dayKeys.map(
                        (day) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day.$2, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              ..._mealTypes.map(
                                (mealType) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: MealCellWidget(
                                    label: mealType[0].toUpperCase() + mealType.substring(1),
                                    slot: _slotFor(plan, day.$1, mealType),
                                    onTap: () => _showMealEditor(
                                      dayKey: day.$1,
                                      mealType: mealType,
                                      currentSlot: _slotFor(plan, day.$1, mealType),
                                      recipes: recipes,
                                      members: members,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
