import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/session.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/screens/my_sessions_screen.dart';

Session _session(String title, String status) {
  return Session(
    id: title,
    title: title,
    mentorName: 'Damian Tan',
    date: DateTime(2026, 8, 20),
    time: '3:00 PM',
    status: status,
  );
}

// builds MySessionsScreen with the Firestore-backed providers stubbed out.
// mySessionsByStatusProvider is a .family, so the override filters the
// canned list the same way the real different-fields query would
Widget _buildTestApp(List<Session> sessions) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      mySessionsProvider.overrideWith((ref) => Stream.value(sessions)),
      mySessionsByStatusProvider.overrideWith(
        (ref, status) => Stream.value(
          sessions.where((s) => s.status == status).toList(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const MySessionsScreen(),
    ),
  );
}

// a session someone else booked WITH me, so it carries a student name the
// mentor view is expected to show
Session _bookedWithMe(String title, String status, String studentName) {
  return Session(
    id: title,
    title: title,
    mentorName: 'Me',
    date: DateTime(2026, 8, 20),
    time: '3:00 PM',
    status: status,
    studentName: studentName,
  );
}

// same as _buildTestApp but the logged in account is a mentor, so the
// mentor-side providers and the swap toggle come into play
Widget _buildMentorTestApp({
  required List<Session> mySessions,
  required List<Session> mentorSessions,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      isMentorProvider.overrideWithValue(true),
      mySessionsProvider.overrideWith((ref) => Stream.value(mySessions)),
      mySessionsByStatusProvider.overrideWith(
        (ref, status) => Stream.value(
          mySessions.where((s) => s.status == status).toList(),
        ),
      ),
      mentorSessionsProvider.overrideWith((ref) => Stream.value(mentorSessions)),
      mentorSessionsByStatusProvider.overrideWith(
        (ref, status) => Stream.value(
          mentorSessions.where((s) => s.status == status).toList(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const MySessionsScreen(),
    ),
  );
}

void main() {
  group('MySessionsScreen status tabs', () {
    testWidgets('uses a DefaultTabController with one tab per status',
        (tester) async {
      await tester.pumpWidget(_buildTestApp([]));
      await tester.pumpAndSettle();

      expect(find.byType(DefaultTabController), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.tabs.length, 5);
    });

    testWidgets('the first tab shows every session', (tester) async {
      await tester.pumpWidget(_buildTestApp([
        _session('Flutter Basics', 'Pending'),
        _session('Data Analytics', 'Completed'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Data Analytics'), findsOneWidget);
    });

    testWidgets('switching to a status tab runs the filtered query',
        (tester) async {
      await tester.pumpWidget(_buildTestApp([
        _session('Flutter Basics', 'Pending'),
        _session('Data Analytics', 'Completed'),
      ]));
      await tester.pumpAndSettle();

      // scoped to the TabBar - "Completed" also appears on the session
      // card's status badge, so a bare text finder is ambiguous
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Completed'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Data Analytics'), findsOneWidget);
      expect(find.text('Flutter Basics'), findsNothing);
    });

    testWidgets('a status tab with no sessions shows its empty state',
        (tester) async {
      await tester.pumpWidget(_buildTestApp([
        _session('Flutter Basics', 'Pending'),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Cancelled'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Cancelled sessions'), findsOneWidget);
    });
  });

  group('MySessionsScreen mentor mode', () {
    testWidgets('an account that is not a mentor gets no toggle',
        (tester) async {
      await tester.pumpWidget(_buildTestApp([]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      expect(find.text('My Sessions'), findsOneWidget);
    });

    testWidgets('a mentor can switch to the requests students sent them',
        (tester) async {
      await tester.pumpWidget(_buildMentorTestApp(
        mySessions: [_session('I booked this', 'Pending')],
        mentorSessions: [
          _bookedWithMe('Student booked me', 'Pending', 'Ada Lovelace'),
        ],
      ));
      await tester.pumpAndSettle();

      // starts on the student side
      expect(find.text('I booked this'), findsOneWidget);
      expect(find.text('Student booked me'), findsNothing);

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Session Requests'), findsOneWidget);
      expect(find.text('Student booked me'), findsOneWidget);
      expect(find.text('I booked this'), findsNothing);
      // the mentor is told who booked, not shown a raw uid
      expect(find.text('Booked by Ada Lovelace'), findsOneWidget);
    });

    testWidgets('a pending request offers Accept and Reject', (tester) async {
      await tester.pumpWidget(_buildMentorTestApp(
        mySessions: const [],
        mentorSessions: [
          _bookedWithMe('Needs an answer', 'Pending', 'Ada Lovelace'),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('an already answered request offers no buttons',
        (tester) async {
      await tester.pumpWidget(_buildMentorTestApp(
        mySessions: const [],
        mentorSessions: [
          _bookedWithMe('Already accepted', 'Confirmed', 'Ada Lovelace'),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Already accepted'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('the booking button is hidden while reviewing requests',
        (tester) async {
      await tester.pumpWidget(_buildMentorTestApp(
        mySessions: const [],
        mentorSessions: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      // booking is a student action, so it goes away in mentor mode
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
