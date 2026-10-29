import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/providers/ai_provider.dart';
// the AI recommendations provider
import 'package:tpmentorship/screens/mentor_detail_screen.dart';
// the single mentor view
import 'package:tpmentorship/services/ai_matching_service.dart';
// the mentor detail page
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class AiMatchesScreen extends ConsumerWidget {
// the applied AI feature's main screen - shows every mentor ranked by
// how well the AI thinks they fit this student, with a match percentage
// and a short reason for each

  const AiMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(mentorMatchesProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('AI Mentor Matches'),
        actions: [
          // re-runs the matching (eg after editing your subjects)
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: () => ref.invalidate(mentorMatchesProvider),
            // invalidate throws away the cached result and re-fetches
          ),
        ],
      ),
      body: SafeArea(
        child: matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return Center(
                child: Text(
                  'No mentors to match yet',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length + 1,
              // +1 for the explainer banner at the top
              itemBuilder: (context, index) {
                if (index == 0) {
                  // small banner explaining what this screen is, and which
                  // engine actually produced the ranking - the Groq call
                  // falls back silently when there is no key or no network,
                  // so this makes that visible instead of hidden
                  final usedGroq = matches.first.source == MatchSource.groq;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.tpRed.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppTheme.tpRed.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: AppTheme.tpRed, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mentors ranked by AI based on your subjects, '
                                'their ratings and availability',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                usedGroq
                                    ? 'Ranked live by Groq (Llama 3.1)'
                                    : 'Offline ranking (no AI key or no '
                                        'connection)',
                                style: TextStyle(
                                  color: AppTheme.tpRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final match = matches[index - 1];
                return GestureDetector(
                  onTap: () {
                    // open the mentor's full profile to book them
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MentorDetailScreen(mentor: match.mentor),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardBg,
                      border: Border.all(color: AppTheme.darkBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // match percentage circle
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.tpRed.withValues(alpha: 0.15),
                            border: Border.all(color: AppTheme.tpRed),
                          ),
                          child: Center(
                            child: Text(
                              '${match.score}%',
                              style: TextStyle(
                                color: AppTheme.tpRed,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // name, specialisation and the AI's reason
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.mentor.name,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                match.mentor.specialization,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                match.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary, size: 18),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.tpRed),
                SizedBox(height: 12),
                Text(
                  'AI is finding your best matches...',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load matches.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
