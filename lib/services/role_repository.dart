import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/role_model.dart';

class RoleRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<RoleModel?> roleStream({
    required String householdId,
    required String userId,
  }) {
    return _db
        .collection('householdMembers')
        .doc('${householdId}_$userId')
        .snapshots()
        .map((doc) => doc.exists ? RoleModel.fromMap(doc.data()!) : null);
  }

  Future<RoleModel?> getRole({
    required String householdId,
    required String userId,
  }) async {
    final doc = await _db.collection('householdMembers').doc('${householdId}_$userId').get();
    if (!doc.exists) {
      return null;
    }

    return RoleModel.fromMap(doc.data()!);
  }
}
