import 'package:cloud_firestore/cloud_firestore.dart';
// needed for Timestamp, the date type Firestore uses

class Conversation {
  // one 1:1 chat between two users, stored in the "conversations" collection
  // the document id is deterministic (the two uids sorted and joined) so the
  // same pair of people always share exactly one conversation
  final String id;
  final List<String> participants;
  // the two users' auth uids
  final Map<String, String> participantNames;
  // uid -> display name, stored here so the Messages list can show the other
  // person's name without a second lookup
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastSenderId;
  final Map<String, int> unreadCounts;
  // uid -> how many messages that user hasn't read yet. incremented for
  // the recipient on every send, reset to 0 for whoever opens the chat
  // (see ChatService.sendMessage / markAsRead)

  Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    this.unreadCounts = const {},
  });

  // the OTHER participant's uid, given my own - used to open/label a chat
  String otherUid(String myUid) {
    return participants.firstWhere((uid) => uid != myUid, orElse: () => myUid);
  }

  // the OTHER participant's display name, given my own
  String otherName(String myUid) {
    final other = otherUid(myUid);
    final name = participantNames[other];
    return (name == null || name.isEmpty) ? 'Unknown' : name;
  }

  // how many unread messages I (myUid) have in this conversation
  int unreadCountFor(String myUid) => unreadCounts[myUid] ?? 0;

  // builds a Conversation from a Firestore document
  factory Conversation.fromMap(Map<String, dynamic> data, String id) {
    return Conversation(
      id: id,
      participants: List<String>.from((data['participants'] ?? []) as List),
      participantNames: Map<String, String>.from(
        (data['participantNames'] ?? <String, dynamic>{}) as Map,
      ),
      lastMessage: (data['lastMessage'] ?? '') as String,
      lastMessageAt: data['lastMessageAt'] is Timestamp
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSenderId: (data['lastSenderId'] ?? '') as String,
      unreadCounts: (data['unreadCounts'] as Map<String, dynamic>? ?? {}).map(
        (uid, value) => MapEntry(uid, (value as num).toInt()),
      ),
    );
  }
}
