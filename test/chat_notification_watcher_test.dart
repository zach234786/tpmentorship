import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/conversation.dart';
import 'package:tpmentorship/models/user_profile.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/chat_notification_provider.dart';
import 'package:tpmentorship/providers/chat_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';

// end-to-end cover for the watcher: a conversation stream goes in, a
// notification call comes out. this is the path that was shipped with no
// coverage - ChatNotifier was tested on its own, but nothing proved the
// provider actually wired the stream to the notification
//
// User cannot be constructed outside firebase, so authStateProvider is
// overridden with a stand-in that only has to satisfy `.value?.uid`
class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final t0 = DateTime(2026, 8, 10, 12, 0, 0);

  Conversation conv({
    String id = 'me_them',
    required DateTime lastMessageAt,
    String lastSenderId = 'them',
    String lastMessage = 'hello there',
  }) {
    return Conversation(
      id: id,
      participants: const ['me', 'them'],
      participantNames: const {'me': 'Me', 'them': 'Alex'},
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastSenderId: lastSenderId,
    );
  }

  UserProfile profile({bool notificationsEnabled = true}) {
    return UserProfile(
      uid: 'me',
      fullName: 'Me',
      createdAt: t0,
      notificationsEnabled: notificationsEnabled,
    );
  }

  // one recorded call to showMessageNotification
  late List<Map<String, String>> shown;
  late StreamController<List<Conversation>> conversations;

  ProviderContainer harness({bool notificationsEnabled = true}) {
    return ProviderContainer(
      overrides: [
        conversationsProvider.overrideWith((ref) => conversations.stream),
        authStateProvider.overrideWith(
          (ref) => Stream.value(_FakeUser('me')),
        ),
        userProfileProvider.overrideWith(
          (ref) => Stream.value(
            profile(notificationsEnabled: notificationsEnabled),
          ),
        ),
        showChatNotificationProvider.overrideWithValue(({
          required String conversationId,
          required String senderUid,
          required String senderName,
          required String text,
        }) async {
          shown.add({
            'conversationId': conversationId,
            'senderUid': senderUid,
            'senderName': senderName,
            'text': text,
          });
        }),
      ],
    );
  }

  setUp(() {
    shown = [];
    conversations = StreamController<List<Conversation>>.broadcast();
  });

  tearDown(() => conversations.close());

  group('chatNotificationWatcherProvider', () {
    test('posts a notification for an incoming message', () async {
      final container = harness();
      addTearDown(container.dispose);
      container.read(chatNotificationWatcherProvider);

      // the launch snapshot establishes the baseline
      conversations.add([conv(lastMessageAt: t0)]);
      await pumpEventQueue();

      // then someone messages me
      conversations.add([
        conv(lastMessageAt: DateTime.now().add(const Duration(seconds: 1))),
      ]);
      await pumpEventQueue();

      expect(shown, hasLength(1));
      expect(shown.single['senderName'], 'Alex');
      expect(shown.single['text'], 'hello there');
      expect(shown.single['conversationId'], 'me_them');
      expect(shown.single['senderUid'], 'them');
    });

    test('posts nothing for the launch backlog', () async {
      final container = harness();
      addTearDown(container.dispose);
      container.read(chatNotificationWatcherProvider);

      conversations.add([
        conv(id: 'old', lastMessageAt: t0.subtract(const Duration(days: 1))),
      ]);
      await pumpEventQueue();

      expect(shown, isEmpty);
    });

    test('posts nothing when the account has notifications off', () async {
      final container = harness(notificationsEnabled: false);
      addTearDown(container.dispose);
      container.read(chatNotificationWatcherProvider);

      conversations.add([conv(lastMessageAt: t0)]);
      await pumpEventQueue();
      conversations.add([
        conv(lastMessageAt: DateTime.now().add(const Duration(seconds: 1))),
      ]);
      await pumpEventQueue();

      expect(shown, isEmpty);
    });

    test('posts nothing for the chat that is open on screen', () async {
      final container = harness();
      addTearDown(container.dispose);
      container.read(chatNotificationWatcherProvider);
      container.read(openChatProvider).conversationId = 'me_them';

      conversations.add([conv(lastMessageAt: t0)]);
      await pumpEventQueue();
      conversations.add([
        conv(lastMessageAt: DateTime.now().add(const Duration(seconds: 1))),
      ]);
      await pumpEventQueue();

      expect(shown, isEmpty);
    });
  });
}
