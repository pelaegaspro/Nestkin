import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String paidBy;
  final String paidByName;
  final String paidByColor;
  final List<String> splitBetween;
  final String category;
  final String categoryEmoji;
  final Timestamp date;
  final String? receiptImageUrl;
  final String? note;
  final bool isSettled;
  final String createdBy;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.paidByColor,
    required this.splitBetween,
    required this.category,
    required this.categoryEmoji,
    required this.date,
    this.receiptImageUrl,
    this.note,
    required this.isSettled,
    required this.createdBy,
  });

  ExpenseModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? paidBy,
    String? paidByName,
    String? paidByColor,
    List<String>? splitBetween,
    String? category,
    String? categoryEmoji,
    Timestamp? date,
    String? receiptImageUrl,
    String? note,
    bool? isSettled,
    String? createdBy,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      paidByName: paidByName ?? this.paidByName,
      paidByColor: paidByColor ?? this.paidByColor,
      splitBetween: splitBetween ?? this.splitBetween,
      category: category ?? this.category,
      categoryEmoji: categoryEmoji ?? this.categoryEmoji,
      date: date ?? this.date,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'paidByColor': paidByColor,
      'splitBetween': splitBetween,
      'category': category,
      'categoryEmoji': categoryEmoji,
      'date': date,
      'receiptImageUrl': receiptImageUrl,
      'note': note,
      'isSettled': isSettled,
      'createdBy': createdBy,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    final splitBetweenRaw = map['splitBetween'];
    final splitBetween = splitBetweenRaw is Iterable
        ? splitBetweenRaw
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList()
        : const <String>[];

    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    return ExpenseModel(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      amount: amount,
      paidBy: (map['paidBy'] ?? '') as String,
      paidByName: (map['paidByName'] ?? '') as String,
      paidByColor: (map['paidByColor'] ?? '#0B5C68') as String,
      splitBetween: splitBetween,
      category: (map['category'] ?? 'Other') as String,
      categoryEmoji: (map['categoryEmoji'] ?? '\u{1F4E6}') as String,
      date: (map['date'] ?? Timestamp.now()) as Timestamp,
      receiptImageUrl: map['receiptImageUrl']?.toString(),
      note: map['note']?.toString(),
      isSettled: (map['isSettled'] ?? false) as bool,
      createdBy: (map['createdBy'] ?? map['paidBy'] ?? '') as String,
    );
  }
}
