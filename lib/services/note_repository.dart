import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/note_model.dart';

class NoteRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<NoteModel>> notesStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('notes')
        .orderBy('isPinned', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NoteModel.fromMap({
                    ...doc.data(),
                    'id': doc.id,
                  }))
              .toList(),
        );
  }

  Future<void> saveNote({
    required String householdId,
    required NoteModel note,
  }) async {
    try {
      final ref = note.id.isEmpty
          ? _db.collection('households').doc(householdId).collection('notes').doc()
          : _db.collection('households').doc(householdId).collection('notes').doc(note.id);
      final id = note.id.isEmpty ? ref.id : note.id;
      await ref.set(note.toMap()..['id'] = id, SetOptions(merge: true));
    } on FirebaseException {
      throw Exception('Could not save that note right now. Please try again.');
    }
  }

  Future<void> deleteNote({
    required String householdId,
    required String noteId,
  }) async {
    try {
      await _db.collection('households').doc(householdId).collection('notes').doc(noteId).delete();
    } on FirebaseException {
      throw Exception('Could not delete that note right now. Please try again.');
    }
  }

  Future<String> uploadAttachment({
    required String householdId,
    required String noteId,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final ref = _storage.ref('households/$householdId/noteAttachments/$noteId/$fileName');
      await ref.putData(Uint8List.fromList(bytes));
      return ref.getDownloadURL();
    } on FirebaseException {
      throw Exception('Could not upload that attachment right now.');
    }
  }
}
