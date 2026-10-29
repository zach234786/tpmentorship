import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/student.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/screens/search_screen.dart';

// builds the SearchScreen with every Firestore-backed provider it reads
// stubbed out, so the widget tree can build without a real Firebase app
Widget _buildTestApp({required bool isMentor}) {
  return ProviderScope(
    overrides: [
      isMentorProvider.overrideWithValue(isMentor),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      mentorsProvider.overrideWith((ref) => Stream.value(<Mentor>[])),
      studentsProvider.overrideWith((ref) => Stream.value(<Student>[])),
      mentorsByRatingProvider.overrideWith(
          (ref, range) => Stream.value(<Mentor>[])),
    ],
    child: MaterialApp(
      // NoSplash avoids Material 3's default ink-sparkle splash, whose
      // fragment shader fails to decode in this test environment
      // ("Unsupported runtime stages format version") whenever a tap
      // animation is left to run to completion via pumpAndSettle
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(body: SearchScreen()),
    ),
  );
}

void main() {
  group('SearchScreen hamburger menu', () {
    testWidgets('menu icon is visible even when the user is not a mentor',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(isMentor: false));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets(
        'non-mentor sees a locked student option and tapping it shows a snackbar without switching mode',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(isMentor: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // locked visual state
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.ancestor(
        of: find.text('A Student to Mentor'),
        matching: find.byType(Tooltip),
      ));
      expect(tooltip.message, 'Sign up as a mentor to unlock this');

      await tester.tap(find.text('A Student to Mentor'));
      await tester.pump(); // start the snackbar animation
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sign up as a mentor to unlock this'), findsWidgets);
      // sheet stays open - the "Looking for..." header is still present
      expect(find.text('Looking for...'), findsOneWidget);
      // mode did not change
      expect(find.text('Find Mentors, Topics and Availability slots'),
          findsOneWidget);
    });

    testWidgets(
        'mentor can tap the student option to switch mode and close the sheet',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(isMentor: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await tester.tap(find.text('A Student to Mentor'));
      await tester.pumpAndSettle();

      // sheet closed
      expect(find.text('Looking for...'), findsNothing);
      // mode switched
      expect(find.text('Find students looking for mentoring help'),
          findsOneWidget);
    });
  });
}
