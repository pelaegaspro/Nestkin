import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkin/services/firestore_service.dart';

void main() {
  group('FirestoreService', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = FirestoreService(db: firestore);
    });

    test('saveUser creates a new user profile with the initial FCM token',
        () async {
      await service.saveUser(
        uid: 'user-1',
        phone: '+919876543210',
        email: 'user1@example.com',
        displayName: 'User One',
        photoUrl: 'https://example.com/user-1.png',
        fcmToken: 'token-1',
      );

      final snapshot = await firestore.collection('users').doc('user-1').get();
      final data = snapshot.data();

      expect(snapshot.exists, isTrue);
      expect(data?['phoneNumber'], '+919876543210');
      expect(data?['email'], 'user1@example.com');
      expect(data?['displayName'], 'User One');
      expect(data?['photoUrl'], 'https://example.com/user-1.png');
      expect(data?['currentHouseholdId'], isNull);
      expect(data?['fcmTokens'], ['token-1']);
      expect(data?['createdAt'], isA<Timestamp>());
      expect(data?['lastActiveAt'], isA<Timestamp>());
    });

    test('saveUser updates an existing profile and merges a new FCM token',
        () async {
      await _seedUser(
        firestore,
        uid: 'user-1',
        phone: '+911111111111',
        email: 'old@example.com',
        displayName: 'Old Name',
        photoUrl: 'https://example.com/old.png',
        fcmTokens: const ['token-1'],
      );

      await service.saveUser(
        uid: 'user-1',
        phone: '+922222222222',
        email: 'new@example.com',
        displayName: 'New Name',
        photoUrl: 'https://example.com/new.png',
        fcmToken: 'token-2',
      );

      final snapshot = await firestore.collection('users').doc('user-1').get();
      final data = snapshot.data();

      expect(data?['phoneNumber'], '+922222222222');
      expect(data?['email'], 'new@example.com');
      expect(data?['displayName'], 'New Name');
      expect(data?['photoUrl'], 'https://example.com/new.png');
      expect(List<String>.from(data?['fcmTokens'] ?? const []),
          containsAll(['token-1', 'token-2']));
      expect(data?['lastActiveAt'], isA<Timestamp>());
    });

    test(
        'createHousehold creates household, membership, and updates the user profile',
        () async {
      await _seedUser(
        firestore,
        uid: 'admin-1',
        phone: '+919999999999',
        email: 'admin@example.com',
        displayName: 'Admin User',
        photoUrl: 'https://example.com/admin.png',
      );

      final householdId =
          await service.createHousehold('Nestkin Home', 'admin-1');

      final householdSnapshot =
          await firestore.collection('households').doc(householdId).get();
      final memberSnapshot = await firestore
          .collection('householdMembers')
          .doc('${householdId}_admin-1')
          .get();
      final userSnapshot =
          await firestore.collection('users').doc('admin-1').get();

      final householdData = householdSnapshot.data();
      final memberData = memberSnapshot.data();
      final userData = userSnapshot.data();

      expect(householdSnapshot.exists, isTrue);
      expect(householdData?['name'], 'Nestkin Home');
      expect(householdData?['adminId'], 'admin-1');
      expect(List<String>.from(householdData?['members'] ?? const []),
          ['admin-1']);
      expect((householdData?['inviteCode'] as String).length, 6);

      expect(memberSnapshot.exists, isTrue);
      expect(memberData?['role'], 'admin');
      expect(memberData?['status'], 'active');
      expect(memberData?['household']['id'], householdId);
      expect(memberData?['user']['uid'], 'admin-1');

      expect(userData?['currentHouseholdId'], householdId);
    });

    test('joinHousehold normalizes the invite code and links the new member',
        () async {
      await _seedUser(
        firestore,
        uid: 'admin-1',
        phone: '+919999999999',
        email: 'admin@example.com',
        displayName: 'Admin User',
        photoUrl: 'https://example.com/admin.png',
      );
      await _seedUser(
        firestore,
        uid: 'member-1',
        phone: '+918888888888',
        email: 'member@example.com',
        displayName: 'Member User',
        photoUrl: 'https://example.com/member.png',
      );

      final householdId =
          await service.createHousehold('Nestkin Home', 'admin-1');
      final householdSnapshot =
          await firestore.collection('households').doc(householdId).get();
      final inviteCode = householdSnapshot.data()?['inviteCode'] as String;

      final joinedHouseholdId =
          await service.joinHousehold(inviteCode.toLowerCase(), 'member-1');

      final updatedHouseholdSnapshot =
          await firestore.collection('households').doc(householdId).get();
      final memberSnapshot = await firestore
          .collection('householdMembers')
          .doc('${householdId}_member-1')
          .get();
      final userSnapshot =
          await firestore.collection('users').doc('member-1').get();

      expect(joinedHouseholdId, householdId);
      expect(
          List<String>.from(
              updatedHouseholdSnapshot.data()?['members'] ?? const []),
          containsAll(['admin-1', 'member-1']));
      expect(memberSnapshot.data()?['role'], 'member');
      expect(memberSnapshot.data()?['household']['inviteCode'], inviteCode);
      expect(userSnapshot.data()?['currentHouseholdId'], householdId);
    });
  });
}

Future<void> _seedUser(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String phone,
  required String email,
  required String displayName,
  required String photoUrl,
  List<String> fcmTokens = const [],
  String? currentHouseholdId,
}) async {
  await firestore.collection('users').doc(uid).set({
    'id': uid,
    'phoneNumber': phone,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'currentHouseholdId': currentHouseholdId,
    'fcmTokens': fcmTokens,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'lastActiveAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}
