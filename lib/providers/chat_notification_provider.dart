import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/conversation.dart';
// the chat data type
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/chat_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// the logged in user, the conversation stream, and the profile (for the
// notifications toggle)
import 'package:tpmentorship/services/chat_notifier.dart';
import 'package:tpmentorship/services/notification_service.dart';
// the decision logic, and the thing that actually shows a notification

// which conversation is on screen right now, or null when none is.
// ChatScreen sets this on open and clears it on dispose so we never
// interrupt someone reading the thread the message belongs to
//
// deliberately a plain mutable object rather than a StateProvider:
// riverpod throws "Tried to modify a provider while the widget tree was
// building" if provider state is changed from initState or dispose, which
// is exactly where this has to happen. nothing rebuilds on this value
// either - the watcher below just reads it when a message lands - so the
// reactive machinery would buy nothing
class OpenChat {
  String? conversationId;
}

final openChatProvider = Provider<OpenChat>((ref) => OpenChat());

// the function that actually posts a notification. behind a provider so
// tests can swap it for a recorder - the watcher below used to call the
// NotificationService singleton directly, which left the entire
// stream -> decision -> notification path with no test coverage at all
typedef ShowChatNotification =
    Future<void> Function({
      required String conversationId,
      required String senderUid,
      required String senderName,
      required String text,
    });

final showChatNotificationProvider = Provider<ShowChatNotification>((ref) {
  return NotificationService.instance.showMessageNotification;
});

// watches the conversation stream and turns whatever ChatNotifier flags
// into a real notification.
//
// this only works while the app process is alive - foreground, and
// backgrounded for as long as android keeps the firestore listener
// running. a fully closed app would need firebase cloud messaging plus a
// cloud function, which needs the paid blaze plan
final chatNotificationWatcherProvider = Provider<ChatNotifier>((ref) {
  final notifier = ChatNotifier();

  // subscribe to these now, at watcher-creation time, so they are loaded
  // before any message arrives. reading a stream provider for the very
  // first time returns "loading" with a null value, so without this the
  // first incoming message would find a null uid or profile and be
  // dropped without a notification. ref.listen rather than ref.watch -
  // watch would rebuild this provider and throw away ChatNotifier's
  // bookkeeping every time the profile changed
  ref.listen(authStateProvider, (_, _) {});
  ref.listen(userProfileProvider, (_, _) {});

  ref.listen<AsyncValue<List<Conversation>>>(conversationsProvider, (
    previous,
    next,
  ) {
    final conversations = next.value;
    if (conversations == null) return;
    // still loading, or the stream errored - nothing to notify either way
    final myUid = ref.read(authStateProvider).value?.uid;
    if (myUid == null) return;

    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;
    // the profile carries this account's notifications toggle. it is a
    // stream, so early on it has not loaded yet - and defaulting to "on"
    // there would notify someone who deliberately turned notifications
    // off. waiting costs nothing: messages that arrive before the profile
    // loads are backlog, which the start-time baseline suppresses anyway

    final toNotify = notifier.conversationsToNotify(
      conversations: conversations,
      myUid: myUid,
      openConversationId: ref.read(openChatProvider).conversationId,
      notificationsEnabled: profile.notificationsEnabled,
    );

    final show = ref.read(showChatNotificationProvider);
    for (final conversation in toNotify) {
      show(
        conversationId: conversation.id,
        senderUid: conversation.otherUid(myUid),
        senderName: conversation.otherName(myUid),
        text: conversation.lastMessage,
      );
    }
  });

  return notifier;
});
