import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../models/user_model.dart';

class ShoppingListRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ShoppingListModel>> streamLists(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('lists')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShoppingListModel.fromMap({
                    ...doc.data(),
                    'id': doc.id,
                  }))
              .toList(),
        );
  }

  Stream<List<ShoppingItemModel>> streamItems({
    required String householdId,
    required String listId,
  }) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('lists')
        .doc(listId)
        .collection('items')
        .orderBy('addedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShoppingItemModel.fromMap({
                    ...doc.data(),
                    'id': doc.id,
                  }))
              .toList(),
        );
  }

  Future<void> createList({
    required String householdId,
    required String name,
    required String emoji,
    required UserModel user,
  }) async {
    try {
      final ref = _db
          .collection('households')
          .doc(householdId)
          .collection('lists')
          .doc();
      final list = ShoppingListModel(
        id: ref.id,
        name: name,
        createdBy: user.id,
        createdByName: user.displayName,
        createdAt: Timestamp.now(),
        emoji: emoji,
      );
      await ref.set(list.toMap());
    } on FirebaseException {
      throw Exception(
          'Could not create that list right now. Please try again.');
    }
  }

  Future<void> addItem({
    required String householdId,
    required String listId,
    required ShoppingItemModel item,
  }) async {
    try {
      final ref = _db
          .collection('households')
          .doc(householdId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc();
      await ref.set(item.copyWith(id: ref.id).toMap());
    } on FirebaseException {
      throw Exception('Could not add that item right now. Please try again.');
    }
  }

  Future<void> updateItem({
    required String householdId,
    required String listId,
    required ShoppingItemModel item,
  }) async {
    try {
      await _db
          .collection('households')
          .doc(householdId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(item.id)
          .set(item.toMap(), SetOptions(merge: true));
    } on FirebaseException {
      throw Exception(
          'Could not update that item right now. Please try again.');
    }
  }

  Future<void> deleteItem({
    required String householdId,
    required String listId,
    required String itemId,
  }) async {
    try {
      await _db
          .collection('households')
          .doc(householdId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .delete();
    } on FirebaseException {
      throw Exception(
          'Could not delete that item right now. Please try again.');
    }
  }

  Future<void> deleteItems({
    required String householdId,
    required String listId,
    required Iterable<String> itemIds,
  }) async {
    final ids = itemIds.where((itemId) => itemId.isNotEmpty).toList();
    if (ids.isEmpty) {
      return;
    }

    try {
      final batch = _db.batch();
      for (final itemId in ids) {
        batch.delete(
          _db
              .collection('households')
              .doc(householdId)
              .collection('lists')
              .doc(listId)
              .collection('items')
              .doc(itemId),
        );
      }
      await batch.commit();
    } on FirebaseException {
      throw Exception(
          'Could not delete those items right now. Please try again.');
    }
  }

  Future<void> clearChecked({
    required String householdId,
    required String listId,
  }) async {
    try {
      final checked = await _db
          .collection('households')
          .doc(householdId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .where('isChecked', isEqualTo: true)
          .get();

      final batch = _db.batch();
      for (final doc in checked.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException {
      throw Exception(
          'Could not clear checked items right now. Please try again.');
    }
  }
}
