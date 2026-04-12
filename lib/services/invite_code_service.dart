import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/household_member_model.dart';
import '../models/user_model.dart';

class InviteCodeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> ensureInviteCode({
    required String householdId,
    required String createdBy,
    required String role,
    String? preferredCode,
    Duration expiresIn = const Duration(days: 2),
  }) async {
    final normalizedPreferred = preferredCode?.trim().toUpperCase();
    if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
      final inviteRef = _db
          .collection('households')
          .doc(householdId)
          .collection('inviteCodes')
          .doc(normalizedPreferred);
      final existingInvite = await inviteRef.get();
      if (existingInvite.exists) {
        return normalizedPreferred;
      }

      final duplicate = await _db
          .collectionGroup('inviteCodes')
          .where('code', isEqualTo: normalizedPreferred)
          .limit(1)
          .get();
      if (duplicate.docs.isEmpty) {
        await inviteRef.set({
          'code': normalizedPreferred,
          'createdBy': createdBy,
          'role': role,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(expiresIn)),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return normalizedPreferred;
      }
    }

    return createInviteCode(
      householdId: householdId,
      createdBy: createdBy,
      role: role,
      expiresIn: expiresIn,
    );
  }

  Future<String> createInviteCode({
    required String householdId,
    required String createdBy,
    required String role,
    Duration expiresIn = const Duration(days: 2),
  }) async {
    final code = await _generateUniqueCode();
    await _db
        .collection('households')
        .doc(householdId)
        .collection('inviteCodes')
        .doc(code)
        .set({
      'code': code,
      'createdBy': createdBy,
      'role': role,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(expiresIn)),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<Map<String, dynamic>?> validateInviteCode({
    required String code,
  }) async {
    final query = await _db
        .collectionGroup('inviteCodes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final data = doc.data();
    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      return null;
    }

    return {
      ...data,
      'householdId': doc.reference.parent.parent?.id,
    };
  }

  Future<String?> redeemInviteCode({
    required String code,
    required UserModel user,
  }) async {
    final invite = await validateInviteCode(code: code);
    if (invite == null) {
      return null;
    }

    final householdId = invite['householdId'] as String?;
    if (householdId == null || householdId.isEmpty) {
      return null;
    }

    final role = invite['role'] as String? ?? 'member';
    final memberId = '${householdId}_${user.id}';
    final householdDoc =
        await _db.collection('households').doc(householdId).get();
    if (!householdDoc.exists) {
      return null;
    }

    final householdData = householdDoc.data()!;
    final member = HouseholdMemberModel(
      id: memberId,
      householdId: householdId,
      userId: user.id,
      household: {
        'id': householdId,
        'name': householdData['name'],
        'inviteCode': householdData['inviteCode'],
      },
      user: {
        'uid': user.id,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'email': user.email,
        'phoneNumber': user.phoneNumber,
      },
      role: role,
      status: 'active',
      color: _memberColorFor(user.id),
      totalPoints: 0,
      weeklyPoints: 0,
      badges: const [],
      joinedAt: Timestamp.now(),
    );

    final batch = _db.batch();
    batch.set(_db.collection('householdMembers').doc(memberId), member.toMap(),
        SetOptions(merge: true));
    batch.update(_db.collection('households').doc(householdId), {
      'members': FieldValue.arrayUnion([user.id]),
    });
    batch.update(_db.collection('users').doc(user.id), {
      'currentHouseholdId': householdId,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return householdId;
  }

  Future<String> _generateUniqueCode() async {
    while (true) {
      final code = _randomCode();
      final existing = await _db
          .collectionGroup('inviteCodes')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        return code;
      }
    }
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _memberColorFor(String seed) {
    const householdPalette = [
      '#0B5C68',
      '#E28F2D',
      '#3B8B5A',
      '#AA4A44',
      '#5C6BC0',
      '#9C6644',
    ];
    final index = seed.codeUnits
            .fold<int>(0, (accumulator, value) => accumulator + value) %
        householdPalette.length;
    return householdPalette[index];
  }
}
