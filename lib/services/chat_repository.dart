import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Stream<List<MessageModel>> streamMessages(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MessageModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Stream<int> unreadCountStream({
    required String householdId,
    required String currentUid,
  }) {
    return streamMessages(householdId).map(
      (messages) => messages.where((message) => !message.readBy.contains(currentUid)).length,
    );
  }

  Future<void> sendMessage({
    required String householdId,
    required MessageModel message,
  }) async {
    try {
      final ref = _db.collection('households').doc(householdId).collection('messages').doc();
      await ref.set(message.copyWith(id: ref.id).toMap());
    } on FirebaseException {
      throw Exception('Could not send that message right now. Please try again.');
    }
  }

  Future<String> uploadChatImage({
    required String householdId,
    required Uint8List bytes,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('households/$householdId/chat_images/$fileName');
      await ref.putData(bytes);
      return ref.getDownloadURL();
    } on FirebaseException {
      throw Exception('Could not upload that image right now. Please try again.');
    }
  }

  Future<void> markMessagesAsRead({
    required String householdId,
    required String currentUid,
    required List<MessageModel> messages,
  }) async {
    final unread = messages.where((message) => !message.readBy.contains(currentUid)).toList();
    if (unread.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final message in unread) {
      batch.update(
        _db.collection('households').doc(householdId).collection('messages').doc(message.id),
        {'readBy': FieldValue.arrayUnion([currentUid])},
      );
    }
    await batch.commit();
  }

  Future<void> toggleReaction({
    required String householdId,
    required MessageModel message,
    required String emoji,
    required String currentUid,
  }) async {
    final current = Map<String, List<String>>.from(message.reactions);
    final users = [...(current[emoji] ?? const <String>[])];
    if (users.contains(currentUid)) {
      users.remove(currentUid);
    } else {
      users.add(currentUid);
    }

    if (users.isEmpty) {
      current.remove(emoji);
    } else {
      current[emoji] = users;
    }

    await _db.collection('households').doc(householdId).collection('messages').doc(message.id).update({
      'reactions': current,
    });
  }
}
