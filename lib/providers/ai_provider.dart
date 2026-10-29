import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/user_profile.dart';
// the user profile data type
import 'package:tpmentorship/providers/data_providers.dart';
// the mentors and profile providers
import 'package:tpmentorship/services/ai_matching_service.dart';
// the applied AI feature

// one shared instance of the AI matching service
final aiMatchingServiceProvider = Provider<AiMatchingService>((ref) {
  return AiMatchingService();
});

// the AI-ranked mentor recommendations for the logged in student
// FutureProvider caches the result so we dont re-call the AI every rebuild
final mentorMatchesProvider = FutureProvider<List<MentorMatch>>((ref) async {
  // wait for the mentor list and the student's profile to load first
  // (.future turns the stream providers into awaitable values)
  final mentors = await ref.watch(mentorsProvider.future);
  final profile = await ref.watch(userProfileProvider.future);

  // a mentor's own listing shouldn't be recommended to themselves - the
  // mentor doc id is always the owner's auth uid (see becomeMentor)
  final otherMentors = mentors.where((m) => m.id != profile?.uid).toList();

  return ref.watch(aiMatchingServiceProvider).rankMentors(
        // if the profile hasnt been created yet use an empty one -
        // the ranking then simply leans on ratings instead of subjects
        profile: profile ??
            UserProfile(uid: '', fullName: '', createdAt: DateTime.now()),
        mentors: otherMentors,
      );
});
