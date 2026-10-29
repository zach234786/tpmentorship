import 'package:cloud_firestore/cloud_firestore.dart';
// the firestore database package
import 'package:tpmentorship/models/chat_message.dart';
import 'package:tpmentorship/models/conversation.dart';
// the chat data types

class ChatService {
  // handles the "conversations" collection and its "messages" subcollection
  // in Firestore - the in-app messaging feature (see chat_screen.dart and
  // messages_screen.dart)

  final CollectionReference<Map<String, dynamic>> _conversations =
      FirebaseFirestore.instance.collection('conversations');

  // deterministic conversation id for a pair of users: the two uids sorted
  // and joined, so tapping "message" on the same person always resolves to
  // the same conversation instead of creating duplicates
  static String conversationIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // SELECT ALL (for me) - every conversation the logged in user is part of
  // sorted newest-first in Dart so no composite index is needed alongside
  // the arrayContains filter (same approach as the other services).
  // conversations with no lastMessage yet (created by ensureConversation
  // when a chat is opened, but nothing sent) are left out of the list -
  // they're not a real conversation until someone actually says something
  Stream<List<Conversation>> streamConversations(String myUid) {
    return _conversations
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => Conversation.fromMap(doc.data(), doc.id))
              .where((c) => c.lastMessage.isNotEmpty)
              .toList();
          conversations.sort(
            (a, b) => b.lastMessageAt.compareTo(a.lastMessageAt),
          );
          return conversations;
        });
  }

  // UPSERT - makes sure the conversation document exists (with just the
  // participants) before the messages subcollection is read. the messages
  // read rule looks up this parent doc with get() to check membership, and
  // get() on a document that doesn't exist fails the whole read - so a
  // brand new chat (opened but nothing sent yet) needs this doc to exist
  // first, otherwise the message list errors out immediately and never
  // recovers. merge:true so it never overwrites lastMessage etc if the
  // conversation already has messages
  Future<void> ensureConversation({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
  }) {
    final conversationId = conversationIdFor(myUid, otherUid);
    return _conversations.doc(conversationId).set({
      'participants': [myUid, otherUid],
      'participantNames': {myUid: myName, otherUid: otherName},
    }, SetOptions(merge: true));
  }

  // SELECT ALL - the messages in one conversation, oldest first so the
  // thread reads top to bottom. single-field orderBy, no index needed
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // INSERT - sends a message. writes the message document, and (with a
  // merge-set) updates or creates the parent conversation with the latest
  // preview info. the merge means the very first message also creates the
  // conversation, so there is no separate "start conversation" step
  Future<void> sendMessage({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
    required String text,
  }) async {
    final conversationId = conversationIdFor(myUid, otherUid);
    final convRef = _conversations.doc(conversationId);
    final now = Timestamp.now();

    await convRef.set({
      'participants': [myUid, otherUid],
      'participantNames': {myUid: myName, otherUid: otherName},
      'lastMessage': text,
      'lastMessageAt': now,
      'lastSenderId': myUid,
      // a nested map, not a dotted-string key - SetOptions(merge: true)
      // deep-merges nested maps, so this only touches the recipient's
      // count and leaves the rest of unreadCounts alone (same pattern
      // already relied on above for participantNames)
      'unreadCounts': {otherUid: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    await convRef.collection('messages').add({
      'senderId': myUid,
      'text': text,
      'createdAt': now,
    });
  }

  // UPDATE - clears my unread count for this conversation, eg when I open
  // the chat. nested map (not a dotted key) so it merges in and only
  // resets my own count - see the comment in sendMessage above
  Future<void> markAsRead({required String myUid, required String otherUid}) {
    final conversationId = conversationIdFor(myUid, otherUid);
    return _conversations.doc(conversationId).set({
      'unreadCounts': {myUid: 0},
    }, SetOptions(merge: true));
  }
}
