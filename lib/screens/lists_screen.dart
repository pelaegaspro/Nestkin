import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../services/firestore_service.dart';
import '../services/shopping_list_repository.dart';
import 'shopping_list_screen.dart';

class ListsScreen extends StatefulWidget {
  final String householdId;

  const ListsScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  final _repository = ShoppingListRepository();
  final _firestoreService = FirestoreService();

  Future<void> _showCreateListDialog() async {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '\u{1F6D2}');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'List name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final user = await _firestoreService
                    .getUser(FirebaseAuth.instance.currentUser!.uid);
                if (user == null) {
                  throw Exception('Could not find your profile.');
                }
                await _repository.createList(
                  householdId: widget.householdId,
                  name: nameController.text.trim(),
                  emoji: emojiController.text.trim().isEmpty
                      ? '\u{1F6D2}'
                      : emojiController.text.trim(),
                  user: user,
                );
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                      content: Text(
                          error.toString().replaceFirst('Exception: ', ''))),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    emojiController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lists')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateListDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ShoppingListModel>>(
        stream: _repository.streamLists(widget.householdId),
        builder: (context, listsSnapshot) {
          if (listsSnapshot.hasError) {
            return const Center(
              child: Text('Could not load shopping lists right now.'),
            );
          }
          if (listsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lists = listsSnapshot.data ?? const <ShoppingListModel>[];
          if (lists.isEmpty) {
            return const Center(
              child: Text('No lists yet. Tap + to create one.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final list = lists[index];
              return StreamBuilder<List<ShoppingItemModel>>(
                stream: _repository.streamItems(
                  householdId: widget.householdId,
                  listId: list.id,
                ),
                builder: (context, itemsSnapshot) {
                  final items =
                      itemsSnapshot.data ?? const <ShoppingItemModel>[];
                  final checkedCount =
                      items.where((item) => item.isChecked).length;
                  final progress =
                      items.isEmpty ? 0.0 : checkedCount / items.length;

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Text(list.emoji,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(list.name)),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(value: progress),
                            ),
                            const SizedBox(width: 12),
                            Text('$checkedCount/${items.length}'),
                          ],
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShoppingListScreen(
                            householdId: widget.householdId,
                            list: list,
                          ),
                        ),
                      ),
                    ),
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
