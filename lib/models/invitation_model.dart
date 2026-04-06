import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationModel {
  final String id;
  final String householdId;
  final String senderId;
  final Map<String, dynamic> sender;
  final String recipientPhoneNumber;
  final String status;
  final Timestamp createdAt;
  final Timestamp? sentAt;
  final Timestamp? acceptedAt;

  InvitationModel({
    required this.id,
    required this.householdId,
    required this.senderId,
    required this.sender,
    required this.recipientPhoneNumber,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.acceptedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'householdId': householdId,
        'senderId': senderId,
        'sender': sender,
        'recipientPhoneNumber': recipientPhoneNumber,
        'status': status,
        'createdAt': createdAt,
        'sentAt': sentAt,
        'acceptedAt': acceptedAt,
      };

  factory InvitationModel.fromMap(Map<String, dynamic> map) => InvitationModel(
        id: map['id'] ?? '',
        householdId: map['householdId'] ?? '',
        senderId: map['senderId'] ?? '',
        sender: Map<String, dynamic>.from(map['sender'] ?? {}),
        recipientPhoneNumber: map['recipientPhoneNumber'] ?? '',
        status: map['status'] ?? 'pending',
        createdAt: map['createdAt'] ?? Timestamp.now(),
        sentAt: map['sentAt'] as Timestamp?,
        acceptedAt: map['acceptedAt'] as Timestamp?,
      );
}
