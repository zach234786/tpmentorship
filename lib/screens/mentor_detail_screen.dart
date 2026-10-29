import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/mentor.dart';
// the mentor data type
import 'package:tpmentorship/providers/auth_provider.dart';
// gives us the logged in user, to detect "this is your own mentor listing"
import 'package:tpmentorship/providers/data_providers.dart';
// canMessageMentorProvider - the premium gate on the Message button
import 'package:tpmentorship/screens/premium_screen.dart';
// where the upgrade prompt sends you
import 'package:tpmentorship/screens/become_mentor_screen.dart';
// the edit-mentor form, opened instead of booking when viewing yourself
import 'package:tpmentorship/screens/book_session_screen.dart';
// the booking form
import 'package:tpmentorship/screens/chat_screen.dart';
// the in-app chat thread opened by the "Message" button
import 'package:tpmentorship/services/share_service.dart';
// additional feature: sharing and opening web links
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/widgets/mentor_profile_layout.dart';
// the layout shared with "My Mentor Profile" (read-only here)

class MentorDetailScreen extends ConsumerWidget {
// shows ONE mentor's full details with a button to book a session
// (this is where tapping a mentor card anywhere in the app leads)
// uses the same MentorProfileLayout as "My Mentor Profile" - read-only
// with a book-session button, unless the mentor being viewed is the
// logged in user's own listing (eg found via search), in which case it
// shows a "this is you" banner and edit controls instead of booking
  final Mentor mentor;
  // the mentor to show

  const MentorDetailScreen({super.key, required this.mentor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    final isSelf = mentor.id == myUid;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Mentor Profile'),
        actions: [
          // additional feature: share this mentor by email
          IconButton(
            icon: Icon(Icons.share, color: AppTheme.textPrimary),
            onPressed: () async {
              final ok = await ShareService.shareMentorByEmail(mentor);
              if (!ok && context.mounted) {
                showAppSnackBar(context, 'Could not open your email app');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isSelf)
              // lets a user who found themselves in search results (or
              // tapped their own recommendation) know why there's no
              // book-a-session button here
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.tpRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.tpRed.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.tpRed, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'This is you',
                      style: TextStyle(
                        color: AppTheme.tpRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: MentorProfileLayout(
                mentor: mentor,
                isEditable: isSelf,
                onEdit: isSelf
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BecomeMentorScreen(existingMentor: mentor),
                          ),
                        );
                      }
                    : null,
                onBookSession: isSelf
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookSessionScreen(mentor: mentor),
                          ),
                        );
                      },
                extraContent: [
                  // message this mentor (not shown on your own profile,
                  // where the layout is editable instead)
                  if (!isSelf) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        // premium members message any mentor straight away.
                        // everyone else books first - that is the free path,
                        // and what the premium plan is actually selling
                        if (ref.read(canMessageMentorProvider(mentor.id))) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                otherUid: mentor.id,
                                otherName: mentor.name,
                              ),
                            ),
                          );
                          return;
                        }
                        // the button stays visible and explains itself -
                        // a hidden button teaches nobody why it is missing
                        _showUpgradePrompt(context, mentor);
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // additional feature: open the TP website inside the app
                  GestureDetector(
                    onTap: () async {
                      final ok = await ShareService.openStudyResources();
                      if (!ok && context.mounted) {
                        showAppSnackBar(context, 'Could not open the link');
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.link, color: AppTheme.tpRed, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'View TP study resources',
                          style: TextStyle(
                            color: AppTheme.tpRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.tpRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // shown when a free member taps Message on a mentor they have not booked.
  // offers both ways out: book them (free) or subscribe
  void _showUpgradePrompt(BuildContext context, Mentor mentor) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCardBg,
        title: Text('Premium feature',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Messaging a mentor without booking first is part of Premium.\n\n'
          'Book a session with ${mentor.name} to chat for free, or go '
          'Premium to message any mentor instantly.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookSessionScreen(mentor: mentor),
                ),
              );
            },
            child: const Text('Book a session'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              );
            },
            child: Text('Go Premium',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
