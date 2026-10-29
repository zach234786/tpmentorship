import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/providers/data_providers.dart';
// live firestore providers
import 'package:tpmentorship/screens/become_mentor_screen.dart';
// the sign-up / edit mentor profile form
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/widgets/mentor_profile_layout.dart';
// the layout shared with mentor_detail_screen.dart (editable here)

class MentorProfileScreen extends ConsumerWidget {
// the user's own mentor profile page
// before signing up as a mentor this shows a "Sign up as a Mentor" call
// to action; afterwards it shows the same layout as viewing any other
// mentor's profile, but editable, plus the reviews students left about them
  final VoidCallback? onBack;
  // run when the back arrow is tapped

  const MentorProfileScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myMentorAsync = ref.watch(myMentorProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // back arrow and title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(Icons.arrow_back_ios,
                    color: AppTheme.textPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'My Mentor Profile',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: myMentorAsync.when(
            data: (mentor) {
              if (mentor == null) {
                // hasn't signed up as a mentor yet
                return _becomeMentorCta(context);
              }
              return MentorProfileLayout(
                mentor: mentor,
                isEditable: true,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BecomeMentorScreen(existingMentor: mentor),
                    ),
                  );
                },
              );
            },
            loading: () => Center(
                child: CircularProgressIndicator(color: AppTheme.tpRed)),
            error: (e, _) => Center(
              child: Text('Could not load your mentor profile',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ),
        ),
      ],
    );
  }

  // shown when the user has never signed up as a mentor
  Widget _becomeMentorCta(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, color: AppTheme.tpRed, size: 56),
            const SizedBox(height: 16),
            Text(
              'Share what you know',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign up as a mentor to appear in search results, get booked '
              'for sessions, and help other students.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BecomeMentorScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Sign up as a Mentor'),
            ),
          ],
        ),
      ),
    );
  }
}
