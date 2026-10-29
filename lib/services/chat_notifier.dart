import 'package:tpmentorship/models/conversation.dart';
// the chat data type this decides notifications for

class ChatNotifier {
  // decides which conversations deserve a "new message" notification.
  //
  // deliberately knows nothing about firestore, riverpod or the
  // notifications plugin - it is handed a conversation list and returns
  // the subset worth notifying, which is what makes the rules testable.
  //
  // note this only ever runs while the app process is alive. notifications
  // for a fully closed app would need firebase cloud messaging and a cloud
  // function, which is a different (and paid) approach

  // now() is injectable so tests can control the session baseline
  ChatNotifier({DateTime Function() now = DateTime.now}) : _now = now;

  final DateTime Function() _now;

  // conversation id -> the newest message already reacted to, so one
  // message can never notify twice
  final Map<String, DateTime> _lastSeen = {};

  // whose inbox is being tracked - a change means a different account
  // signed in and everything below is stale
  String? _uid;

  // anything older than this arrived before the app started
  late DateTime _startedAt;

  List<Conversation> conversationsToNotify({
    required List<Conversation> conversations,
    required String myUid,
    required String? openConversationId,
    required bool notificationsEnabled,
  }) {
    if (_uid != myUid) {
      _uid = myUid;
      _lastSeen.clear();
      _startedAt = _now();
    }

    final toNotify = <Conversation>[];
    for (final conversation in conversations) {
      final seenAt = _lastSeen[conversation.id];
      final isNew =
          seenAt == null || conversation.lastMessageAt.isAfter(seenAt);
      // the conversation doc also changes on markAsRead, which rewrites
      // unreadCounts - only a moved lastMessageAt is a new message
      if (!isNew) continue;

      // recorded even when a rule below suppresses the notification, so
      // turning notifications back on doesn't replay everything missed
      _lastSeen[conversation.id] = conversation.lastMessageAt;

      // the launch backlog - without this every unread conversation
      // notifies on app start
      if (!conversation.lastMessageAt.isAfter(_startedAt)) continue;
      // never notify me about my own message; firestore echoes my write
      // back to my own stream immediately
      if (conversation.lastSenderId == myUid) continue;
      // don't interrupt someone reading that exact thread
      if (conversation.id == openConversationId) continue;
      // the per-account toggle session reminders already respect
      if (!notificationsEnabled) continue;

      toNotify.add(conversation);
    }
    return toNotify;
  }
}
