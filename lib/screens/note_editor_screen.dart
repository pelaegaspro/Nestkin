import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../models/note_model.dart';
import '../services/firestore_service.dart';
import '../services/note_repository.dart';

class NoteEditorScreen extends StatefulWidget {
  final String householdId;
  final NoteModel? note;

  const NoteEditorScreen({
    super.key,
    required this.householdId,
    this.note,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _repository = NoteRepository();
  final _fs = FirestoreService();
  late quill.QuillController _controller;
  bool _isPinned = false;
  String _color = '#FFF8B8';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.note?.title ?? '';
    _isPinned = widget.note?.isPinned ?? false;
    _color = widget.note?.color ?? '#FFF8B8';
    _controller = quill.QuillController(
      document: _documentFromBody(widget.note?.body),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  quill.Document _documentFromBody(String? body) {
    if (body == null || body.isEmpty) {
      final document = quill.Document();
      document.insert(0, '\n');
      return document;
    }

    try {
      return quill.Document.fromJson(jsonDecode(body));
    } catch (_) {
      final document = quill.Document();
      document.insert(0, body);
      return document;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = await _fs.getUser(FirebaseAuth.instance.currentUser!.uid);
      if (user == null) {
        throw Exception('Could not find your profile.');
      }

      final note = NoteModel(
        id: widget.note?.id ?? '',
        title: _titleController.text.trim(),
        body: jsonEncode(_controller.document.toDelta().toJson()),
        createdBy: widget.note?.createdBy ?? user.id,
        createdByName: widget.note?.createdByName ?? user.displayName,
        authorPhotoUrl: widget.note?.authorPhotoUrl ?? user.photoUrl,
        createdAt: widget.note?.createdAt ?? Timestamp.now(),
        updatedAt: Timestamp.now(),
        isPinned: _isPinned,
        color: _color,
        attachments: widget.note?.attachments ?? const [],
      );
      await _repository.saveNote(householdId: widget.householdId, note: note);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isPinned = !_isPinned),
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  children: ['#FFF8B8', '#FFD6E7', '#DDF5FF', '#E1F7D5', '#FFE4C2']
                      .map(
                        (hex) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _color = hex),
                            borderRadius: BorderRadius.circular(20),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)),
                              child: _color == hex ? const Icon(Icons.check, size: 16) : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          quill.QuillSimpleToolbar(controller: _controller),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: quill.QuillEditor.basic(
                controller: _controller,
                config: const quill.QuillEditorConfig(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
