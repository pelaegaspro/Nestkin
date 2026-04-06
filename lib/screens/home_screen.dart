import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatelessWidget {
  final String householdId;
  final String householdName;

  const HomeScreen({
    super.key,
    required this.householdId,
    required this.householdName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(householdName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: FirestoreService().tasksStream(householdId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (_, i) {
              final task = tasks[i];
              return ListTile(
                title: Text(task.title),
                subtitle: Text(
                    'Due: ${task.dueDate != null ? task.dueDate!.toDate().toString().substring(0, 10) : 'None'}  •  To: ${task.assignedTo?['displayName'] ?? 'Anyone'}'),
                trailing: Chip(
                  label: Text(task.isComplete ? 'Completed' : 'Pending'),
                  backgroundColor: task.isComplete
                      ? Colors.green[100]
                      : Colors.orange[100],
                ),
                onTap: () => _showStatusDialog(context, task),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddTaskScreen(householdId: householdId)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, TaskModel task) {
    // Remove if strictly assignee only: if (task.assignedToId != FirebaseAuth.instance.currentUser?.uid) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(task.title),
        content: Text(task.isComplete ? 'Mark as incomplete?' : 'Mark as completed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirestoreService().updateTaskStatus(householdId, task.id, !task.isComplete);
              Navigator.pop(context);
            },
            child: Text(task.isComplete ? 'Undo' : 'Complete'),
          ),
        ],
      ),
    );
  }
}
