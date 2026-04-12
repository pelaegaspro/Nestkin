import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';

class PointsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> toggleTaskCompletion({
    required String householdId,
    required TaskModel task,
    required String actingUserId,
  }) async {
    final taskRef = _db.collection('households').doc(householdId).collection('tasks').doc(task.id);
    final memberRef = _db.collection('householdMembers').doc('${householdId}_$actingUserId');

    try {
      await _db.runTransaction((transaction) async {
        final latestTask = await transaction.get(taskRef);
        if (!latestTask.exists) {
          throw Exception('That task no longer exists.');
        }

        final taskData = latestTask.data()!;
        final wasComplete = taskData['isComplete'] ?? false;
        final assignedToId = taskData['assignedToId'] as String?;
        final points = taskData['points'] ?? 10;

        if (!wasComplete) {
          final memberDoc = await transaction.get(memberRef);
          if (!memberDoc.exists) {
            throw Exception('Your household profile could not be found.');
          }

          final completedCount = (memberDoc.data()?['completedTaskCount'] ?? 0) + 1;
          final badges = List<String>.from(memberDoc.data()?['badges'] ?? const []);
          if (completedCount >= 5 && !badges.contains('5 tasks done')) {
            badges.add('5 tasks done');
          }
          if (completedCount >= 15 && !badges.contains('Task Champion')) {
            badges.add('Task Champion');
          }

          transaction.update(taskRef, {
            'isComplete': true,
            'isCompleted': true,
            'completedAt': FieldValue.serverTimestamp(),
            'completedById': actingUserId,
          });
          transaction.update(memberRef, {
            'totalPoints': FieldValue.increment(points),
            'weeklyPoints': FieldValue.increment(points),
            'completedTaskCount': completedCount,
            'badges': badges,
          });
          return;
        }

        transaction.update(taskRef, {
          'isComplete': false,
          'isCompleted': false,
          'completedAt': null,
          'completedById': null,
        });

        if (task.completedById == actingUserId || assignedToId == actingUserId) {
          transaction.update(memberRef, {
            'totalPoints': FieldValue.increment(-points),
            'weeklyPoints': FieldValue.increment(-points),
          });
        }
      });
    } on FirebaseException {
      throw Exception('Could not update the task right now. Please try again.');
    }
  }
}
