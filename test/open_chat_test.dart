import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/providers/chat_notification_provider.dart';

// ChatScreen registers the conversation it is showing from initState and
// clears it from dispose. riverpod throws "Tried to modify a provider
// while the widget tree was building" if provider *state* is changed from
// either hook - which is why OpenChat is a plain mutable object behind a
// plain Provider rather than a StateProvider.
//
// ChatScreen itself cannot be mounted in a test without firebase, so this
// mirrors the exact lifecycle pattern instead. it fails if anyone converts
// OpenChat back into a StateProvider (crash on opening a chat), or moves
// the ref.read into dispose (crash on leaving one)
class _FakeChatScreen extends ConsumerStatefulWidget {
  const _FakeChatScreen({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_FakeChatScreen> createState() => _FakeChatScreenState();
}

class _FakeChatScreenState extends ConsumerState<_FakeChatScreen> {
  late final OpenChat _openChat;

  @override
  void initState() {
    super.initState();
    // grabbed here because ref cannot be used once dispose has run
    _openChat = ref.read(openChatProvider);
    _openChat.conversationId = widget.conversationId;
  }

  @override
  void dispose() {
    _openChat.conversationId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('OpenChat', () {
    test('starts out with no conversation open', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(openChatProvider).conversationId, isNull);
    });

    testWidgets('is set from initState and cleared on dispose without throwing',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: _FakeChatScreen(conversationId: 'a_b'),
          ),
        ),
      );

      expect(container.read(openChatProvider).conversationId, 'a_b');

      // navigating away disposes the screen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox()),
        ),
      );

      expect(container.read(openChatProvider).conversationId, isNull);
    });
  });
}
