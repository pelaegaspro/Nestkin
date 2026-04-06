import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/household_model.dart';
import '../models/household_member_model.dart';
import '../models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── USER ──────────────────────────────────────────────────
  Future<void> saveUser({
    required String uid,
    required String phone,
    required String displayName,
    String? photoUrl,
    required String fcmToken,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      final newUser = UserModel(
        id: uid,
        phoneNumber: phone,
        displayName: displayName,
        photoUrl: photoUrl,
        fcmTokens: [fcmToken],
        createdAt: Timestamp.now(),
        lastActiveAt: Timestamp.now(),
      );
      await userRef.set(newUser.toMap());
    } else {
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        'lastActiveAt': FieldValue.serverTimestamp(),
        // Only update if not null (e.g., from Google auth)
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (displayName.isNotEmpty) 'displayName': displayName,
      });
    }
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  // ── HOUSEHOLDS ────────────────────────────────────────────
  Future<String> createHousehold(String name, String userId) async {
    final user = await getUser(userId);
    if (user == null) throw Exception('User not found');

    final inviteCode = _generateCode();
    final hRef = _db.collection('households').doc();
    
    final household = HouseholdModel(
      id: hRef.id,
      name: name,
      adminId: userId,
      admin: {'uid': user.id, 'displayName': user.displayName, 'photoUrl': user.photoUrl},
      inviteCode: inviteCode,
      createdAt: Timestamp.now(),
    );

    // Write household
    await hRef.set(household.toMap());

    // Write top-level member link
    final memberId = '${hRef.id}_$userId';
    final memberModel = HouseholdMemberModel(
      id: memberId,
      householdId: hRef.id,
      userId: userId,
      household: {'id': hRef.id, 'name': name, 'inviteCode': inviteCode},
      user: {'uid': user.id, 'displayName': user.displayName, 'photoUrl': user.photoUrl, 'phoneNumber': user.phoneNumber},
      role: 'admin',
      status: 'active',
      joinedAt: Timestamp.now(),
    );

    await _db.collection('householdMembers').doc(memberId).set(memberModel.toMap());

    return hRef.id;
  }

  Future<String?> joinHousehold(String inviteCode, String userId) async {
    final query = await _db
        .collection('households')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    
    final householdMap = query.docs.first.data();
    final hRefId = householdMap['id'];

    final user = await getUser(userId);
    if (user == null) throw Exception('User not found');

    final memberId = '${hRefId}_$userId';
    
    final memberModel = HouseholdMemberModel(
      id: memberId,
      householdId: hRefId,
      userId: userId,
      household: {'id': hRefId, 'name': householdMap['name'], 'inviteCode': inviteCode},
      user: {'uid': user.id, 'displayName': user.displayName, 'photoUrl': user.photoUrl, 'phoneNumber': user.phoneNumber},
      role: 'member',
      status: 'active',
      joinedAt: Timestamp.now(),
    );

    await _db.collection('householdMembers').doc(memberId).set(memberModel.toMap(), SetOptions(merge: true));
    return hRefId;
  }

  Future<List<HouseholdMemberModel>> getUserHouseholds(String userId) async {
    final query = await _db
        .collection('householdMembers')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();
    
    return query.docs.map((d) => HouseholdMemberModel.fromMap(d.data())).toList();
  }

  // ── TASKS ─────────────────────────────────────────────────
  Future<void> createTask({
    required String householdId,
    required String title,
    String? description,
    required String createdById,
    String? assignedToId,
    Timestamp? dueDate,
  }) async {
    final creator = await getUser(createdById);
    if (creator == null) return;
    
    Map<String, dynamic>? assignedToMap;
    if (assignedToId != null) {
      final assigned = await getUser(assignedToId);
      if (assigned != null) {
        assignedToMap = {'uid': assigned.id, 'displayName': assigned.displayName, 'photoUrl': assigned.photoUrl};
      }
    }

    final ref = _db.collection('households').doc(householdId).collection('tasks').doc();
    final task = TaskModel(
      id: ref.id,
      householdId: householdId,
      title: title,
      description: description,
      createdById: createdById,
      createdBy: {'uid': creator.id, 'displayName': creator.displayName, 'photoUrl': creator.photoUrl},
      assignedToId: assignedToId,
      assignedTo: assignedToMap,
      isComplete: false,
      dueDate: dueDate,
      createdAt: Timestamp.now(),
    );

    await ref.set(task.toMap());
  }

  Stream<List<TaskModel>> tasksStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => TaskModel.fromMap(d.data())).toList());
  }

  Future<void> updateTaskStatus(String householdId, String taskId, bool isComplete) async {
    await _db.collection('households').doc(householdId).collection('tasks').doc(taskId).update({
      'isComplete': isComplete,
      'completedAt': isComplete ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<List<HouseholdMemberModel>> getHouseholdMembers(String householdId) async {
    final query = await _db
        .collection('householdMembers')
        .where('householdId', isEqualTo: householdId)
        .where('status', isEqualTo: 'active')
        .get();
    
    return query.docs.map((d) => HouseholdMemberModel.fromMap(d.data())).toList();
  }

  // ── HELPERS ───────────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
