import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/providers/ai_provider.dart';
import 'package:tpmentorship/screens/ai_matches_screen.dart';
import 'package:tpmentorship/services/ai_matching_service.dart';

MentorMatch _match(MatchSource source) {
  return MentorMatch(
    mentor: Mentor(
      id: '1',
      name: 'Damian Tan',
      specialization: 'Development',
      rating: 4.8,
      reviewCount: 45,
      isOnline: true,
      subjects: const ['DAVA'],
    ),
    score: 90,
    reason: 'Teaches DAVA which you need help with',
    source: source,
  );
}

Widget _buildTestApp(MatchSource source) {
  return ProviderScope(
    overrides: [
      mentorMatchesProvider.overrideWith((ref) async => [_match(source)]),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const AiMatchesScreen(),
    ),
  );
}

void main() {
  group('AiMatchesScreen shows where the ranking came from', () {
    testWidgets('says the ranking is live from Groq', (tester) async {
      await tester.pumpWidget(_buildTestApp(MatchSource.groq));
      await tester.pumpAndSettle();

      expect(find.textContaining('Groq'), findsOneWidget);
    });

    testWidgets('says the ranking used the offline formula', (tester) async {
      await tester.pumpWidget(_buildTestApp(MatchSource.localFallback));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.textContaining('Groq'), findsNothing);
    });
  });
}
