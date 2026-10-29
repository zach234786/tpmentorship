import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/conversation.dart';
import 'package:tpmentorship/services/chat_notifier.dart';

void main() {
  // the moment the watcher starts - messages older than this belong to
  // before the app launched
  final t0 = DateTime(2026, 8, 10, 12, 0, 0);

  Conversation conv({
    String id = 'me_them',
    DateTime? lastMessageAt,
    String lastSenderId = 'them',
    String lastMessage = 'hello',
  }) {
    return Conversation(
      id: id,
      participants: const ['me', 'them'],
      participantNames: const {'me': 'Me', 'them': 'Alex'},
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt ?? t0.add(const Duration(seconds: 5)),
      lastSenderId: lastSenderId,
    );
  }

  // most tests only need a clock frozen at t0
  ChatNotifier frozen() => ChatNotifier(now: () => t0);

  List<String> ids(List<Conversation> conversations) =>
      conversations.map((c) => c.id).toList();

  group('ChatNotifier', () {
    test('notifies for a message from the other participant', () {
      final result = frozen().conversationsToNotify(
        conversations: [conv()],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(ids(result), ['me_them']);
    });

    test('stays silent for a message I sent myself', () {
      final result = frozen().conversationsToNotify(
        conversations: [conv(lastSenderId: 'me')],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(result, isEmpty);
    });

    test('stays silent for messages that predate the app starting', () {
      // the launch backlog: unread conversations from a previous session
      final result = frozen().conversationsToNotify(
        conversations: [
          conv(id: 'old_1', lastMessageAt: t0.subtract(const Duration(days: 2))),
          conv(
            id: 'old_2',
            lastMessageAt: t0.subtract(const Duration(hours: 1)),
          ),
        ],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(result, isEmpty);
    });

    test('stays silent when the same conversation is re-emitted unchanged', () {
      // the doc also changes on markAsRead, which rewrites unreadCounts
      final notifier = frozen();
      final conversation = conv();

      final first = notifier.conversationsToNotify(
        conversations: [conversation],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );
      final second = notifier.conversationsToNotify(
        conversations: [conversation],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(ids(first), ['me_them']);
      expect(second, isEmpty);
    });

    test('stays silent for the conversation currently open on screen', () {
      final result = frozen().conversationsToNotify(
        conversations: [conv()],
        myUid: 'me',
        openConversationId: 'me_them',
        notificationsEnabled: true,
      );

      expect(result, isEmpty);
    });

    test('does not replay a muted message after notifications are re-enabled', () {
      final notifier = frozen();
      final conversation = conv();

      final whileOff = notifier.conversationsToNotify(
        conversations: [conversation],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: false,
      );
      final afterOn = notifier.conversationsToNotify(
        conversations: [conversation],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(whileOff, isEmpty);
      expect(afterOn, isEmpty);
    });

    test('notifies for a conversation that first appears mid-session', () {
      final notifier = frozen();
      notifier.conversationsToNotify(
        conversations: [conv()],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      final result = notifier.conversationsToNotify(
        conversations: [
          conv(),
          conv(
            id: 'me_new',
            lastMessageAt: t0.add(const Duration(seconds: 10)),
          ),
        ],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(ids(result), ['me_new']);
    });

    test('re-baselines when a different account signs in', () {
      // a moving clock, so the second account's baseline is genuinely later
      var clock = t0;
      final notifier = ChatNotifier(now: () => clock);

      final first = notifier.conversationsToNotify(
        conversations: [conv()],
        myUid: 'me',
        openConversationId: null,
        notificationsEnabled: true,
      );
      expect(ids(first), ['me_them']);

      // someone else logs in five minutes later - their existing inbox is
      // backlog to them, not new mail
      clock = t0.add(const Duration(minutes: 5));
      final second = notifier.conversationsToNotify(
        conversations: [
          conv(
            id: 'other_x',
            lastMessageAt: t0.add(const Duration(minutes: 1)),
          ),
        ],
        myUid: 'other',
        openConversationId: null,
        notificationsEnabled: true,
      );

      expect(second, isEmpty);
    });
  });
}
