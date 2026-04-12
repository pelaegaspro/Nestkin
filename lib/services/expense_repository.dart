import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense_model.dart';
import '../models/settlement_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<ExpenseModel>> streamExpenses(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      final expenses = <ExpenseModel>[];
      for (final doc in snapshot.docs) {
        try {
          expenses.add(
            ExpenseModel.fromMap({
              ...doc.data(),
              'id': doc.id,
            }),
          );
        } catch (_) {
          // Skip malformed records so one bad document doesn't break the whole screen.
        }
      }
      return expenses;
    });
  }

  Stream<List<SettlementModel>> streamSettlements(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('settlements')
        .orderBy('settledAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final settlements = <SettlementModel>[];
      for (final doc in snapshot.docs) {
        try {
          settlements.add(
            SettlementModel.fromMap({
              ...doc.data(),
              'id': doc.id,
            }),
          );
        } catch (_) {
          // Skip malformed records so one bad document doesn't break the summary tab.
        }
      }
      return settlements;
    });
  }

  Future<void> saveExpense({
    required String householdId,
    required ExpenseModel expense,
    XFile? receiptImage,
  }) async {
    try {
      final expenseRef = expense.id.isEmpty
          ? _db
              .collection('households')
              .doc(householdId)
              .collection('expenses')
              .doc()
          : _db
              .collection('households')
              .doc(householdId)
              .collection('expenses')
              .doc(expense.id);

      String? receiptImageUrl = expense.receiptImageUrl;
      if (receiptImage != null) {
        final receiptRef = _storage.ref(
          'households/$householdId/receipts/${expenseRef.id}.jpg',
        );
        await receiptRef.putFile(
          File(receiptImage.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        receiptImageUrl = await receiptRef.getDownloadURL();
      }

      await expenseRef.set(
        expense
            .copyWith(
              id: expenseRef.id,
              receiptImageUrl: receiptImageUrl,
            )
            .toMap(),
        SetOptions(merge: true),
      );
    } on FirebaseException {
      throw Exception(
          'Could not save that expense right now. Please try again.');
    }
  }

  Future<void> deleteExpense({
    required String householdId,
    required String expenseId,
  }) async {
    try {
      await _db
          .collection('households')
          .doc(householdId)
          .collection('expenses')
          .doc(expenseId)
          .delete();
      try {
        await _storage
            .ref('households/$householdId/receipts/$expenseId.jpg')
            .delete();
      } on FirebaseException {
        // Receipt may not exist.
      }
    } on FirebaseException {
      throw Exception(
          'Could not delete that expense right now. Please try again.');
    }
  }

  Future<void> logSettlement({
    required String householdId,
    required SettlementModel settlement,
  }) async {
    try {
      final settlementRef = settlement.id.isEmpty
          ? _db
              .collection('households')
              .doc(householdId)
              .collection('settlements')
              .doc()
          : _db
              .collection('households')
              .doc(householdId)
              .collection('settlements')
              .doc(settlement.id);

      await settlementRef.set(
        settlement.copyWith(id: settlementRef.id).toMap(),
        SetOptions(merge: true),
      );
    } on FirebaseException {
      throw Exception(
          'Could not log that settlement right now. Please try again.');
    }
  }
}
