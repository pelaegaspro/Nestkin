import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../services/firestore_service.dart';
import '../services/shopping_list_repository.dart';
import '../widgets/add_item_field.dart';
import '../widgets/item_tile.dart';

class ShoppingListScreen extends StatefulWidget {
  final String householdId;
  final ShoppingListModel list;

  const ShoppingListScreen({
    super.key,
    required this.householdId,
    required this.list,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _repository = ShoppingListRepository();
  final _firestoreService = FirestoreService();
  final Set<String> _selectedItemIds = <String>{};

  String get householdId => widget.householdId;
  ShoppingListModel get list => widget.list;
  bool get _selectionMode => _selectedItemIds.isNotEmpty;

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedItemIds.isEmpty) {
      return;
    }
    setState(_selectedItemIds.clear);
  }

  Future<void> _toggleItem({
    required BuildContext context,
    required ShoppingListRepository repository,
    required ShoppingItemModel item,
    required bool checked,
  }) async {
    await repository.updateItem(
      householdId: householdId,
      listId: list.id,
      item: item.copyWith(
        isChecked: checked,
        checkedBy: checked ? FirebaseAuth.instance.currentUser!.uid : null,
        checkedAt: checked ? Timestamp.now() : null,
      ),
    );
  }

  Future<void> _addItem(
    FirestoreService firestoreService,
    ShoppingListRepository repository,
    String name,
    String qty,
    String unit,
  ) async {
    final user =
        await firestoreService.getUser(FirebaseAuth.instance.currentUser!.uid);
    final householdMember = await firestoreService.getHouseholdMember(
      householdId: householdId,
      userId: FirebaseAuth.instance.currentUser!.uid,
    );
    if (user == null) {
      throw Exception('Could not find your profile.');
    }

    await repository.addItem(
      householdId: householdId,
      listId: list.id,
      item: ShoppingItemModel(
        id: '',
        name: name,
        qty: qty,
        unit: unit,
        addedBy: user.id,
        addedByName: user.displayName,
        addedByColor: householdMember?.color ?? '#0B5C68',
        isChecked: false,
        checkedBy: null,
        checkedAt: null,
        addedAt: Timestamp.now(),
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    ShoppingListRepository repository,
    ShoppingItemModel item,
  ) async {
    final qtyController = TextEditingController(text: item.qty);
    final unitController = TextEditingController(text: item.unit);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await repository.updateItem(
                householdId: householdId,
                listId: list.id,
                item: item.copyWith(
                  qty: qtyController.text.trim(),
                  unit: unitController.text.trim(),
                ),
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    qtyController.dispose();
    unitController.dispose();
  }

  Future<void> _deleteSingleItem(ShoppingItemModel item) async {
    try {
      await _repository.deleteItem(
        householdId: householdId,
        listId: list.id,
        itemId: item.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _repository.addItem(
                householdId: householdId,
                listId: list.id,
                item: item.copyWith(id: ''),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteSelectedItems() async {
    final selectedIds = _selectedItemIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected items'),
        content: Text('Delete ${selectedIds.length} selected item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _repository.deleteItems(
        householdId: householdId,
        listId: list.id,
        itemIds: selectedIds,
      );
      if (!mounted) {
        return;
      }
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedIds.length} item(s) deleted')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        title: Text(_selectionMode
            ? '${_selectedItemIds.length} selected'
            : '${list.emoji} ${list.name}'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete selected',
              onPressed: _deleteSelectedItems,
            )
          else
            TextButton(
              onPressed: () async {
                try {
                  await _repository.clearChecked(
                    householdId: householdId,
                    listId: list.id,
                  );
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            error.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              },
              child: const Text('Clear Checked'),
            ),
        ],
      ),
      bottomNavigationBar: AddItemField(
        onSubmit: (name, qty, unit) =>
            _addItem(_firestoreService, _repository, name, qty, unit),
      ),
      body: StreamBuilder<List<ShoppingItemModel>>(
        stream:
            _repository.streamItems(householdId: householdId, listId: list.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load this shopping list right now.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const <ShoppingItemModel>[];
          final validIds = items.map((item) => item.id).toSet();
          final staleIds = _selectedItemIds.difference(validIds);
          if (staleIds.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _selectedItemIds.removeAll(staleIds);
              });
            });
          }

          final pending = items.where((item) => !item.isChecked).toList();
          final checked = items.where((item) => item.isChecked).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (pending.isNotEmpty) ...[
                Text('Pending', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...pending.map(
                  (item) => ItemTile(
                    item: item,
                    selected: _selectedItemIds.contains(item.id),
                    selectionMode: _selectionMode,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(item.id);
                      }
                    },
                    onLongPress: () => _toggleSelection(item.id),
                    onChecked: (value) => _toggleItem(
                      context: context,
                      repository: _repository,
                      item: item,
                      checked: value ?? false,
                    ),
                    onDelete: () => _deleteSingleItem(item),
                    onEdit: () => _editItem(context, _repository, item),
                  ),
                ),
              ],
              if (checked.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Checked', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...checked.map(
                  (item) => ItemTile(
                    item: item,
                    selected: _selectedItemIds.contains(item.id),
                    selectionMode: _selectionMode,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(item.id);
                      }
                    },
                    onLongPress: () => _toggleSelection(item.id),
                    onChecked: (value) => _toggleItem(
                      context: context,
                      repository: _repository,
                      item: item,
                      checked: value ?? false,
                    ),
                    onDelete: () => _deleteSingleItem(item),
                    onEdit: () => _editItem(context, _repository, item),
                  ),
                ),
              ],
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('No items yet. Add one below.')),
                ),
            ],
          );
        },
      ),
    );
  }
}
