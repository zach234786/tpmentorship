import 'package:cloud_firestore/cloud_firestore.dart';
// needed for Timestamp, the date type Firestore uses

class ChatMessage {
// one message inside a conversation, stored in the
// conversations/{id}/messages subcollection
  final String id;
  final String senderId;
  // auth uid of whoever sent this message
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  // builds a ChatMessage from a Firestore document
  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      senderId: (data['senderId'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // converts this message into a plain map so Firestore can save it
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
