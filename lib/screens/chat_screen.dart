import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/chat_message.dart';
// the message data type
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/chat_notification_provider.dart';
import 'package:tpmentorship/providers/chat_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// the app's providers (auth, chat, and the user profile for my name).
// chat_notification_provider lets this screen mute notifications for the
// thread being read
import 'package:tpmentorship/services/chat_service.dart';
// for the deterministic conversation id
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// the shared snackbar feedback helper
import 'package:tpmentorship/utils/validators.dart';
// helper to show popup messages

class ChatScreen extends ConsumerStatefulWidget {
  // a live 1:1 chat thread with one other user
  // opened from "Reach Out" (student directory) and "Message" (mentor profile)
  // the conversation id is worked out here from my uid + the other person's,
  // so callers only need to pass who they want to talk to
  final String otherUid;
  final String otherName;

  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  final _composerKey = GlobalKey<FormState>();
  // lets _send() run the message box's validator before sending
  late final Future<void> _readyFuture;
  // resolves once the conversation doc is guaranteed to exist - the
  // message list isn't subscribed to until this completes (see
  // ChatService.ensureConversation for why)
  String? _lastMarkedMessageId;
  // the newest message id we've already reacted to, so we don't call
  // markAsRead again on every rebuild - only when a genuinely new message
  // arrives
  String _conversationId = '';
  // worked out once in initState so both initState and dispose can use it
  late final OpenChat _openChat;
  // grabbed in initState because ref cannot be used from dispose

  @override
  void initState() {
    super.initState();
    final myUid = ref.read(authStateProvider).value?.uid ?? '';
    _conversationId = ChatService.conversationIdFor(myUid, widget.otherUid);
    _readyFuture = _ensureConversation();
    // tell the notification watcher not to notify for the thread I'm
    // reading. set now rather than after _readyFuture resolves, so a
    // message landing while ensureConversation is still in flight doesn't
    // slip through
    _openChat = ref.read(openChatProvider);
    _openChat.conversationId = _conversationId;
  }

  @override
  void dispose() {
    _openChat.conversationId = null;
    // back to notifying normally for this thread
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // the name to show as "sent by me" - prefers the firestore profile name,
  // falls back to the auth display name
  String _myName() {
    final profile = ref.read(userProfileProvider).value;
    if (profile?.fullName.isNotEmpty ?? false) return profile!.fullName;
    final displayName = ref.read(authServiceProvider).displayName;
    return displayName.isEmpty ? 'Me' : displayName;
  }

  Future<void> _ensureConversation() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final chatService = ref.read(chatServiceProvider);
    await chatService.ensureConversation(
      myUid: user.uid,
      myName: _myName(),
      otherUid: widget.otherUid,
      otherName: widget.otherName,
    );
    // opening the chat counts as reading it - clear my unread badge
    await chatService.markAsRead(myUid: user.uid, otherUid: widget.otherUid);
  }

  // clears my unread badge again - called whenever a new incoming message
  // arrives while this screen is already open, so the badge doesn't creep
  // back up for messages I'm actively looking at
  void _markAsReadIfNeeded(String myUid) {
    ref
        .read(chatServiceProvider)
        .markAsRead(myUid: myUid, otherUid: widget.otherUid);
  }

  // jumps the list to the newest message (called after sending / new data)
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    if (_sending) return;

    // validate the box like every other form in the app - this shows the
    // error under the field instead of the send button doing nothing
    if (!(_composerKey.currentState?.validate() ?? false)) return;

    final text = _messageController.text.trim();
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    // should never happen - this screen is behind the auth gate

    setState(() => _sending = true);
    // clear the box straight away so it feels responsive
    _messageController.clear();
    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(
            myUid: user.uid,
            myName: _myName(),
            otherUid: widget.otherUid,
            otherName: widget.otherName,
            text: text,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      // put the text back so the user doesn't lose it
      _messageController.text = text;
      showAppSnackBar(context, 'Could not send. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final myUid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(title: Text(widget.otherName)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // wait for ensureConversation (see initState) before
              // subscribing to messages - otherwise the parent doc might
              // not exist yet and the read rule's get() on it fails
              child: FutureBuilder<void>(
                future: _readyFuture,
                builder: (context, readySnapshot) {
                  if (readySnapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(color: AppTheme.tpRed),
                    );
                  }
                  final messagesAsync = ref.watch(
                    messagesProvider(_conversationId),
                  );
                  return messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No messages yet - say hello to ${widget.otherName}!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }
                      // once new messages arrive, slide down to the newest
                      // and clear the unread badge if the newest one is
                      // incoming (only once per message, not every rebuild)
                      final newest = messages.last;
                      if (newest.id != _lastMarkedMessageId) {
                        _lastMarkedMessageId = newest.id;
                        if (newest.senderId != myUid) {
                          _markAsReadIfNeeded(myUid);
                        }
                      }
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            _messageBubble(messages[index], myUid),
                      );
                    },
                    loading: () => Center(
                      child: CircularProgressIndicator(color: AppTheme.tpRed),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Could not load messages',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                },
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  // one chat bubble - mine on the right in red, theirs on the left in grey
  Widget _messageBubble(ChatMessage message, String myUid) {
    final isMine = message.senderId == myUid;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.tpRed : AppTheme.darkCardBg,
          border: isMine ? null : Border.all(color: AppTheme.darkBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isMine ? Colors.white : AppTheme.textPrimary,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  // the text box + send button pinned to the bottom
  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCardBg,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Form(
              key: _composerKey,
              child: TextFormField(
              controller: _messageController,
              style: TextStyle(color: AppTheme.textPrimary),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              maxLength: Validators.maxChatMessageLength,
              // hides the "0/500" counter until the message gets long
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  currentLength < (maxLength ?? 0) - 50
                      ? null
                      : Text(
                          '$currentLength/$maxLength',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
              validator: Validators.chatMessage,
              onFieldSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppTheme.darkBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.tpRed, width: 2),
                ),
              ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // send button - a filled red circle
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tpRed,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
