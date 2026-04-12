import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/household_member_model.dart';
import '../models/household_model.dart';
import '../models/invitation_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const List<String> householdPalette = [
    '#0B5C68',
    '#E28F2D',
    '#3B8B5A',
    '#AA4A44',
    '#5C6BC0',
    '#9C6644',
  ];

  Future<void> saveUser({
    required String uid,
    required String phone,
    String? email,
    required String displayName,
    String? photoUrl,
    required String fcmToken,
  }) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        final newUser = UserModel(
          id: uid,
          phoneNumber: phone,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          currentHouseholdId: null,
          fcmTokens: fcmToken.isEmpty ? const [] : [fcmToken],
          createdAt: Timestamp.now(),
          lastActiveAt: Timestamp.now(),
        );
        await userRef.set(newUser.toMap());
        return;
      }

      final updateData = <String, dynamic>{
        'lastActiveAt': FieldValue.serverTimestamp(),
        if (phone.isNotEmpty) 'phoneNumber': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (displayName.isNotEmpty) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (fcmToken.isNotEmpty) 'fcmTokens': FieldValue.arrayUnion([fcmToken]),
      };

      await userRef.update(updateData);
    } on FirebaseException {
      rethrow;
    } catch (_) {
      throw Exception(
          'Unable to save your profile right now. Please try again.');
    }
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  Future<void> updateFcmToken({
    required String uid,
    required String token,
  }) async {
    if (token.isEmpty) {
      return;
    }

    try {
      final userRef = _db.collection('users').doc(uid);
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        return;
      }

      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      throw Exception('Could not update notifications right now.');
    }
  }

  Future<HouseholdModel?> getHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    if (!doc.exists) {
      return null;
    }

    return HouseholdModel.fromMap({
      ...doc.data()!,
      'id': doc.id,
    });
  }

  Stream<HouseholdModel?> householdStream(String householdId) {
    return _db.collection('households').doc(householdId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      return HouseholdModel.fromMap({
        ...doc.data()!,
        'id': doc.id,
      });
    });
  }

  Future<String> createHousehold(String name, String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) {
        throw Exception('User not found.');
      }

      await _ensureUserCanCreateHousehold(user);

      final inviteCode = await _generateUniqueInviteCode();
      final householdRef = _db.collection('households').doc();
      final memberId = '${householdRef.id}_$userId';

      final household = HouseholdModel(
        id: householdRef.id,
        name: name,
        adminId: userId,
        admin: {
          'uid': user.id,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
        },
        members: [userId],
        inviteCode: inviteCode,
        createdAt: Timestamp.now(),
      );

      final memberModel = HouseholdMemberModel(
        id: memberId,
        householdId: householdRef.id,
        userId: userId,
        household: {
          'id': householdRef.id,
          'name': name,
          'inviteCode': inviteCode,
        },
        user: {
          'uid': user.id,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'email': user.email,
          'phoneNumber': user.phoneNumber,
        },
        role: 'admin',
        status: 'active',
        color: _memberColorFor(userId),
        totalPoints: 0,
        weeklyPoints: 0,
        badges: const [],
        joinedAt: Timestamp.now(),
      );

      final batch = _db.batch();
      batch.set(householdRef, household.toMap());
      batch.set(_db.collection('householdMembers').doc(memberId),
          memberModel.toMap());
      batch.update(_db.collection('users').doc(userId), {
        'currentHouseholdId': householdRef.id,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return householdRef.id;
    } on FirebaseException {
      throw Exception(
          'Could not create the household right now. Please try again.');
    }
  }

  Future<String?> joinHousehold(String inviteCode, String userId) async {
    try {
      final normalizedCode = inviteCode.trim().toUpperCase();
      final query = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final householdDoc = query.docs.first;
      final householdMap = householdDoc.data();
      final householdId = householdDoc.id;
      final user = await getUser(userId);
      if (user == null) {
        throw Exception('User not found.');
      }

      final memberRef =
          _db.collection('householdMembers').doc('${householdId}_$userId');
      final existingMembership = await memberRef.get();
      if (existingMembership.exists &&
          existingMembership.data()?['status'] == 'active') {
        throw Exception('You are already a member of this household.');
      }

      final memberModel = HouseholdMemberModel(
        id: memberRef.id,
        householdId: householdId,
        userId: userId,
        household: {
          'id': householdId,
          'name': householdMap['name'],
          'inviteCode': normalizedCode,
        },
        user: {
          'uid': user.id,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'email': user.email,
          'phoneNumber': user.phoneNumber,
        },
        role: 'member',
        status: 'active',
        color: _memberColorFor(userId),
        totalPoints: 0,
        weeklyPoints: 0,
        badges: const [],
        joinedAt: Timestamp.now(),
      );

      final batch = _db.batch();
      batch.set(memberRef, memberModel.toMap(), SetOptions(merge: true));
      batch.update(_db.collection('households').doc(householdId), {
        'members': FieldValue.arrayUnion([userId]),
      });
      batch.update(_db.collection('users').doc(userId), {
        'currentHouseholdId': householdId,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return householdId;
    } on FirebaseException {
      throw Exception(
          'Could not join the household right now. Please try again.');
    }
  }

  Future<List<HouseholdMemberModel>> getUserHouseholds(String userId) async {
    final query = await _db
        .collection('householdMembers')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    return query.docs
        .map((d) => HouseholdMemberModel.fromMap(d.data()))
        .toList();
  }

  Future<void> createTask({
    required String householdId,
    required String title,
    String? description,
    required String createdById,
    String? assignedToId,
    int points = 10,
    Timestamp? dueDate,
  }) async {
    try {
      final creator = await getUser(createdById);
      if (creator == null) {
        throw Exception('Could not find the current user.');
      }

      Map<String, dynamic>? assignedToMap;
      String? assignedToName;
      Timestamp? assignedAt;
      if (assignedToId != null) {
        final assigned = await getUser(assignedToId);
        if (assigned == null) {
          throw Exception('The selected assignee is no longer available.');
        }

        assignedToName = assigned.displayName;
        assignedAt = Timestamp.now();
        assignedToMap = {
          'uid': assigned.id,
          'displayName': assigned.displayName,
          'photoUrl': assigned.photoUrl,
        };
      }

      final ref = await _db
          .collection('households')
          .doc(householdId)
          .collection('tasks')
          .add({
        'householdId': householdId,
        'title': title,
        'description': description,
        'createdById': createdById,
        'createdBy': {
          'uid': creator.id,
          'displayName': creator.displayName,
          'photoUrl': creator.photoUrl,
        },
        'assignedToId': assignedToId,
        'assignedTo': assignedToMap,
        'assignedToName': assignedToName,
        'assignedAt': assignedAt,
        'isComplete': false,
        'isCompleted': false,
        'points': points,
        'completedById': null,
        'dueDate': dueDate,
        'createdAt': Timestamp.now(),
        'completedAt': null,
      });

      await ref.update({'id': ref.id});
    } on FirebaseException {
      throw Exception('Could not create the task right now. Please try again.');
    }
  }

  Stream<List<TaskModel>> tasksStream(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => TaskModel.fromMap({
                  ...d.data(),
                  'id': d.id,
                }),
              )
              .toList(),
        );
  }

  Future<void> updateTaskStatus(
    String householdId,
    String taskId,
    bool isComplete, {
    String? updatedById,
  }) async {
    try {
      await _db
          .collection('households')
          .doc(householdId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'isComplete': isComplete,
        'isCompleted': isComplete,
        'completedAt': isComplete ? FieldValue.serverTimestamp() : null,
        'completedById': isComplete ? updatedById : null,
      });
    } on FirebaseException {
      throw Exception('Could not update the task right now. Please try again.');
    }
  }

  Future<List<HouseholdMemberModel>> getHouseholdMembers(
      String householdId) async {
    final query = await _db
        .collection('householdMembers')
        .where('householdId', isEqualTo: householdId)
        .where('status', isEqualTo: 'active')
        .get();

    return query.docs
        .map(
          (d) => HouseholdMemberModel.fromMap({
            ...d.data(),
            'id': d.id,
          }),
        )
        .toList();
  }

  Future<HouseholdMemberModel?> getHouseholdMember({
    required String householdId,
    required String userId,
  }) async {
    final doc = await _db
        .collection('householdMembers')
        .doc('${householdId}_$userId')
        .get();
    if (!doc.exists) {
      return null;
    }

    return HouseholdMemberModel.fromMap({
      ...doc.data()!,
      'id': doc.id,
    });
  }

  Stream<List<HouseholdMemberModel>> householdMembersStream(
      String householdId) {
    return _db
        .collection('householdMembers')
        .where('householdId', isEqualTo: householdId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => HouseholdMemberModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Future<void> sendInvitation({
    required String householdId,
    required String senderId,
    required String recipientPhone,
  }) async {
    try {
      final sender = await getUser(senderId);
      if (sender == null) {
        throw Exception('Current user not found.');
      }

      final normalizedPhone = _normalizePhoneNumber(recipientPhone);
      if (normalizedPhone == null) {
        throw Exception(
            'Enter a valid phone number with country code, for example +917604991136.');
      }

      final ref = _db
          .collection('households')
          .doc(householdId)
          .collection('invitations')
          .doc();
      final invitation = InvitationModel(
        id: ref.id,
        householdId: householdId,
        senderId: senderId,
        sender: {
          'uid': sender.id,
          'displayName': sender.displayName,
          'photoUrl': sender.photoUrl,
        },
        recipientPhoneNumber: normalizedPhone,
        status: 'pending',
        createdAt: Timestamp.now(),
        sentAt: Timestamp.now(),
      );

      final batch = _db.batch();
      batch.set(ref, invitation.toMap());
      batch.set(
          _db.collection('globalInvitations').doc(ref.id), invitation.toMap());
      await batch.commit();
    } on FirebaseException {
      throw Exception(
          'Could not send the invitation right now. Please try again.');
    }
  }

  Stream<List<InvitationModel>> getInvitationsByPhone(String phoneNumber) {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber) ?? phoneNumber;
    return _db
        .collection('globalInvitations')
        .where('recipientPhoneNumber', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => InvitationModel.fromMap(d.data())).toList());
  }

  Future<void> acceptInvitation(String invitationId, String userId) async {
    try {
      final invRef = _db.collection('globalInvitations').doc(invitationId);
      final invDoc = await invRef.get();
      if (!invDoc.exists) {
        throw Exception('Invitation not found.');
      }

      final invData = invDoc.data()!;
      final householdId = invData['householdId'] as String;
      final householdRef = _db.collection('households').doc(householdId);
      final hhDoc = await householdRef.get();
      if (!hhDoc.exists) {
        throw Exception('Household not found.');
      }

      final hhData = hhDoc.data()!;
      final user = await getUser(userId);
      if (user == null) {
        throw Exception('User not found.');
      }

      final memberId = '${householdId}_$userId';
      final member = HouseholdMemberModel(
        id: memberId,
        householdId: householdId,
        userId: userId,
        household: {
          'id': householdId,
          'name': hhData['name'],
          'inviteCode': hhData['inviteCode'],
        },
        user: {
          'uid': user.id,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'email': user.email,
          'phoneNumber': user.phoneNumber,
        },
        role: 'member',
        status: 'active',
        color: _memberColorFor(userId),
        totalPoints: 0,
        weeklyPoints: 0,
        badges: const [],
        joinedAt: Timestamp.now(),
      );

      final batch = _db.batch();
      batch.update(invRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      batch.update(householdRef.collection('invitations').doc(invitationId), {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_db.collection('householdMembers').doc(memberId),
          member.toMap(), SetOptions(merge: true));
      batch.update(householdRef, {
        'members': FieldValue.arrayUnion([userId]),
      });
      batch.update(_db.collection('users').doc(userId), {
        'currentHouseholdId': householdId,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException {
      throw Exception(
          'Could not accept the invitation right now. Please try again.');
    }
  }

  Future<void> _ensureUserCanCreateHousehold(UserModel user) async {
    if (user.currentHouseholdId != null &&
        user.currentHouseholdId!.isNotEmpty) {
      throw Exception('You already belong to a household.');
    }

    final memberships = await getUserHouseholds(user.id);
    if (memberships.isNotEmpty) {
      throw Exception('You already belong to a household.');
    }
  }

  Future<String> _generateUniqueInviteCode() async {
    while (true) {
      final code = _generateCode();
      final existing = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        return code;
      }
    }
  }

  String? _normalizePhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[\s()-]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('+')) {
      return digits;
    }
    if (digits.length == 10) {
      return '+91$digits';
    }
    return null;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _memberColorFor(String seed) {
    if (seed.isEmpty) {
      return householdPalette.first;
    }

    final index = seed.codeUnits
            .fold<int>(0, (accumulator, value) => accumulator + value) %
        householdPalette.length;
    return householdPalette[index];
  }

  Future<void> removeHouseholdMember({
    required String householdId,
    required String actingUserId,
    required String memberUserId,
  }) async {
    try {
      final householdRef = _db.collection('households').doc(householdId);
      final memberRef = _db
          .collection('householdMembers')
          .doc('${householdId}_$memberUserId');
      final userRef = _db.collection('users').doc(memberUserId);

      await _db.runTransaction((transaction) async {
        final householdDoc = await transaction.get(householdRef);
        if (!householdDoc.exists) {
          throw Exception('Household not found.');
        }

        final household = HouseholdModel.fromMap({
          ...householdDoc.data()!,
          'id': householdDoc.id,
        });

        if (household.adminId != actingUserId) {
          throw Exception('Only the household creator can remove members.');
        }

        if (memberUserId == household.adminId) {
          throw Exception('The household creator cannot remove themselves.');
        }

        final memberDoc = await transaction.get(memberRef);
        if (!memberDoc.exists) {
          throw Exception('That member is no longer in this household.');
        }

        transaction.update(householdRef, {
          'members': FieldValue.arrayRemove([memberUserId]),
        });
        transaction.delete(memberRef);

        final userDoc = await transaction.get(userRef);
        if (userDoc.exists &&
            userDoc.data()?['currentHouseholdId'] == householdId) {
          transaction.update(userRef, {
            'currentHouseholdId': null,
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException {
      throw Exception(
          'Could not remove that member right now. Please try again.');
    }
  }
}
