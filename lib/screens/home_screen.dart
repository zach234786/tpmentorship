import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/conversation.dart';
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/session.dart';
// the data types
import 'package:tpmentorship/providers/ai_provider.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/chat_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// live firestore + AI providers
import 'package:tpmentorship/screens/chat_screen.dart';
// opens a conversation directly from its preview card
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/widgets/mentor_card.dart';
// the small mentor card widget
import 'package:tpmentorship/widgets/session_card.dart';
// the session card widget

class HomeScreen extends ConsumerWidget {
  // the main landing screen after logging in
  // ConsumerWidget so it can watch the live firestore providers
  final String userName;
  // the logged in username shown in greeting

  // used to handle taps and navigation
  final ValueChanged<Mentor>? onMentorTap;
  final ValueChanged<Session>? onSessionTap;
  final VoidCallback? onViewAllSessions;
  final VoidCallback? onViewAllAiMatches;
  final VoidCallback? onViewAllMessages;
  final VoidCallback? onNavigateToSearch;
  final VoidCallback? onNavigateToMessages;

  const HomeScreen({
    super.key,
    required this.userName,
    this.onMentorTap,
    this.onSessionTap,
    this.onViewAllSessions,
    this.onViewAllAiMatches,
    this.onViewAllMessages,
    this.onNavigateToSearch,
    this.onNavigateToMessages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AI-ranked mentor recommendations (the applied AI feature)
    final matchesAsync = ref.watch(mentorMatchesProvider);
    // this student's booked sessions, live from firestore
    final sessionsAsync = ref.watch(mySessionsProvider);
    // this user's real conversations, live from firestore
    final conversationsAsync = ref.watch(conversationsProvider);
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';

    return SingleChildScrollView(
      // whole screen scrolls
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top bar with the logo, app name and a notification bell
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // the "TP" logo box
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tpRed.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // TP Mentorship title
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'TP ',
                            style: TextStyle(
                              color: AppTheme.tpRed,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: 'Mentorship',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.textPrimary,
                  size: 26,
                ),
              ],
            ),
          ),

          // greeting with the user name in red
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Hello ',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: userName,
                    style: TextStyle(
                      color: AppTheme.tpRed,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Connect. Learn. Grow Together',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),

          // recommended mentors, ranked by the AI, scrolls sideways
          _sectionHeader(
            'Recommended Mentors',
            'View all >',
            onViewAllAiMatches,
            aiBadge: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: matchesAsync.when(
              // the AI ranking gives us loading / error / data states
              data: (matches) {
                if (matches.isEmpty) {
                  return Center(
                    child: Text(
                      'No mentors yet - check back soon!',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: matches.length > 5 ? 5 : matches.length,
                  // only the top 5 matches on the home screen
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 100,
                        child: MentorCard(
                          mentor: match.mentor,
                          onTap: () => onMentorTap?.call(match.mentor),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: AppTheme.tpRed),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load mentors',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.search,
                    title: 'Find a Mentor',
                    subtitle: 'Explore and connect with mentors',
                    onTap: onNavigateToSearch,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.calendar_month,
                    title: 'Upcoming Sessions',
                    subtitle: 'View your upcoming sessions',
                    onTap: onViewAllSessions,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // upcoming sessions list, live from firestore
          _sectionHeader('Upcoming Sessions', 'View all >', onViewAllSessions),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: sessionsAsync.when(
              data: (sessions) {
                // only sessions that havent happened yet, next 2
                final upcoming = sessions
                    .where(
                      (s) =>
                          s.date.isAfter(DateTime.now()) &&
                          s.status != 'Cancelled',
                    )
                    .take(2)
                    .toList();
                if (upcoming.isEmpty) {
                  // friendly empty state instead of a blank gap
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardBg,
                      border: Border.all(color: AppTheme.darkBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          color: AppTheme.textSecondary,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No upcoming sessions - find a mentor and book one!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: upcoming
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SessionCard(
                            session: s,
                            onTap: () => onSessionTap?.call(s),
                          ),
                        ),
                      )
                      .toList(),
                  // one session card per session
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: AppTheme.tpRed),
              ),
              error: (e, _) => Text(
                'Could not load sessions',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // messages preview - the 3 most recent real conversations
          _sectionHeader('Messages', 'View all >', onNavigateToMessages),
          const SizedBox(height: 8),
          conversationsAsync.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No messages yet - reach out to a mentor or student to start chatting!',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return Column(
                children: conversations
                    .take(3)
                    .map(
                      (conversation) =>
                          _messagePreviewCard(context, conversation, myUid),
                    )
                    .toList(),
              );
            },
            loading: () =>
                Center(child: CircularProgressIndicator(color: AppTheme.tpRed)),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Could not load your chats',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // one conversation preview card - tapping it opens that chat directly
  // (not just the Messages tab), same idea as messages_screen.dart's tiles
  Widget _messagePreviewCard(
    BuildContext context,
    Conversation conversation,
    String myUid,
  ) {
    final name = conversation.otherName(myUid);
    final preview = conversation.lastSenderId == myUid
        ? 'You: ${conversation.lastMessage}'
        : conversation.lastMessage;
    final unread = conversation.unreadCountFor(myUid);

    return GestureDetector(
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
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.darkCardBg,
          border: Border.all(color: AppTheme.darkBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.tpRed, width: 2),
                color: AppTheme.darkBg,
              ),
              child: Icon(
                Icons.person,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // sender name and message preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight: unread > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // unread count bubble, only if there are unread messages
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.tpRed,
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String action,
    VoidCallback? onTap, {
    bool aiBadge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (aiBadge) ...[
                // small badge showing this section is AI powered
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tpRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.tpRed.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.tpRed, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        'AI',
                        style: TextStyle(
                          color: AppTheme.tpRed,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: TextStyle(
                color: AppTheme.tpRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.darkCardBg,
          border: Border.all(color: AppTheme.darkBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // the icon box
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.tpRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.tpRed.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(icon, color: AppTheme.tpRed, size: 18),
            ),
            const SizedBox(width: 10),
            // title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
