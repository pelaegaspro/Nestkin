import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
}

class MessageModel {
  final String id;
  final String text;
  final String imageUrl;
  final MessageType type;
  final String senderId;
  final String senderName;
  final String senderColor;
  final Timestamp timestamp;
  final List<String> readBy;
  final Map<String, List<String>> reactions;

  const MessageModel({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderColor,
    required this.timestamp,
    required this.readBy,
    required this.reactions,
  });

  DateTime get sentAt => timestamp.toDate();

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'imageUrl': imageUrl,
        'type': type.name,
        'senderId': senderId,
        'senderName': senderName,
        'senderColor': senderColor,
        'timestamp': timestamp,
        'readBy': readBy,
        'reactions': reactions,
      };

  MessageModel copyWith({
    String? id,
    String? text,
    String? imageUrl,
    MessageType? type,
    String? senderId,
    String? senderName,
    String? senderColor,
    Timestamp? timestamp,
    List<String>? readBy,
    Map<String, List<String>>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderColor: senderColor ?? this.senderColor,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      reactions: reactions ?? this.reactions,
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final rawReactions = Map<String, dynamic>.from(map['reactions'] ?? const {});
    return MessageModel(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      type: MessageType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => MessageType.text,
      ),
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Member',
      senderColor: map['senderColor'] ?? '#0B5C68',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      readBy: List<String>.from(map['readBy'] ?? const []),
      reactions: rawReactions.map(
        (key, value) => MapEntry(key, List<String>.from(value ?? const [])),
      ),
    );
  }
}
