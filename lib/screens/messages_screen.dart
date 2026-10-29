import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/conversation.dart';
// the conversation data type
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/chat_provider.dart';
// the live messaging providers
import 'package:tpmentorship/screens/chat_screen.dart';
// the chat thread opened when a conversation is tapped
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class MessagesScreen extends ConsumerStatefulWidget {
  // screen showing the list of the logged in user's real conversations,
  // streamed live from Firestore (see chat_provider.dart)
  final VoidCallback? onBack;
  // run when the back arrow is tapped

  const MessagesScreen({super.key, this.onBack});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  // grabs whatever the user types into the search box
  String _query = '';
  // current search text, filters the conversation list by the other
  // person's name as the user types

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // turns a DateTime into a short relative string like "2d" or "just now"
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final conversationsAsync = ref.watch(conversationsProvider);

    return Column(
      children: [
        // back arrow, title and subtitle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Messages',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Chat with your mentors and students',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // search box - filters the conversation list live
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            // shows a "search" key instead of a newline key on the keyboard
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search your chats....',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              fillColor: AppTheme.darkCardBg,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.tpRed, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // the live list of conversations
        Expanded(
          child: conversationsAsync.when(
            data: (conversations) {
              // filter by the other person's name when searching
              final lower = _query.toLowerCase();
              final results = _query.isEmpty
                  ? conversations
                  : conversations
                        .where(
                          (c) =>
                              c.otherName(myUid).toLowerCase().contains(lower),
                        )
                        .toList();

              if (results.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _query.isEmpty
                          ? 'No conversations yet - reach out to a mentor or student to start chatting!'
                          : 'No chats match "$_query"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: results.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) =>
                    _conversationTile(results[index], myUid),
              );
            },
            loading: () =>
                Center(child: CircularProgressIndicator(color: AppTheme.tpRed)),
            error: (e, _) => Center(
              child: Text(
                'Could not load your chats',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // one row in the conversation list (avatar, name, last message, time)
  Widget _conversationTile(Conversation conversation, String myUid) {
    final name = conversation.otherName(myUid);
    // show "You: ..." when the last message was sent by me
    final preview = conversation.lastSenderId == myUid
        ? 'You: ${conversation.lastMessage}'
        : conversation.lastMessage;

    final unread = conversation.unreadCountFor(myUid);

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUid: conversation.otherUid(myUid),
              otherName: name,
            ),
          ),
        );
      },
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.tpRed, width: 2),
          color: AppTheme.darkBg,
        ),
        child: Icon(Icons.person, color: AppTheme.textSecondary, size: 24),
      ),
      title: Text(
        name,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeAgo(conversation.lastMessageAt),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          if (unread > 0) ...[const SizedBox(height: 6), _unreadBadge(unread)],
        ],
      ),
    );
  }

  // the small red circle showing how many unread messages are in a chat
  Widget _unreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: AppTheme.tpRed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
