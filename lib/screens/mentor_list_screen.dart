import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/mentor.dart';
// the mentor data type
import 'package:tpmentorship/providers/data_providers.dart';
// the firestore providers
import 'package:tpmentorship/screens/mentor_detail_screen.dart';
// the mentor detail page
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/widgets/mentor_card.dart';
// the small mentor card widget

class MentorListScreen extends ConsumerWidget {
// a reusable results screen that shows mentors matching ONE of the
// advanced firestore queries - which query runs depends on which
// parameter was passed in:
//   subject       -> filter by subject (arrayContains)
//   specialization-> filter by specialization (single field equality)
//   minRating/max -> rating range (two filters on the same field)
//   none of them  -> all mentors sorted by rating
  final String title;
  // the heading shown in the app bar, eg "DAVA Mentors"
  final String? subject;
  final String? specialization;
  final double? minRating;
  final double? maxRating;

  const MentorListScreen({
    super.key,
    required this.title,
    this.subject,
    this.specialization,
    this.minRating,
    this.maxRating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // pick the provider that matches the parameters given
    final AsyncValue<List<Mentor>> mentorsAsync;
    if (subject != null) {
      mentorsAsync = ref.watch(mentorsBySubjectProvider(subject!));
    } else if (specialization != null) {
      mentorsAsync =
          ref.watch(mentorsBySpecializationProvider(specialization!));
    } else if (minRating != null && maxRating != null) {
      mentorsAsync = ref
          .watch(mentorsByRatingProvider((min: minRating!, max: maxRating!)));
    } else {
      mentorsAsync = ref.watch(mentorsProvider);
      // no filters - all mentors sorted by rating
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: mentorsAsync.when(
          data: (mentors) {
            if (mentors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search,
                        color: AppTheme.textSecondary, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No mentors found for this filter',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            }
            // show results in a 3-wide grid of mentor cards
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: mentors.length,
              itemBuilder: (context, index) {
                final mentor = mentors[index];
                return MentorCard(
                  mentor: mentor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MentorDetailScreen(mentor: mentor),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => Center(
              child: CircularProgressIndicator(color: AppTheme.tpRed)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load mentors.\n$e',
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
