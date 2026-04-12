import 'package:flutter/material.dart';

import '../models/note_model.dart';
import '../services/note_repository.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

class NotesGridScreen extends StatelessWidget {
  final String householdId;

  const NotesGridScreen({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    final repository = NoteRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Household Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(householdId: householdId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: repository.notesStream(householdId),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? const <NoteModel>[];
          if (notes.isEmpty) {
            return const Center(
              child: Text('No notes yet. Tap + to add one.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return NoteCard(
                note: note,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(
                      householdId: householdId,
                      note: note,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
