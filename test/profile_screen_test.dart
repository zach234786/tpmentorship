import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/screens/profile_screen.dart';

// builds ProfileScreen with the Firestore-backed providers stubbed out
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      userProfileProvider.overrideWith(
        (ref) => Stream.error(Exception('UNAVAILABLE: no network')),
      ),
      mySessionsProvider.overrideWith((ref) => Stream.value(const [])),
      completedSessionsCountProvider.overrideWith(
        (ref) => Future.error(Exception('UNAVAILABLE: no network')),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(body: ProfileScreen(userName: 'Fallback Name')),
    ),
  );
}

void main() {
  testWidgets(
      'ProfileScreen falls back gracefully when Firestore is unavailable',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // a Firestore UNAVAILABLE error must not crash the screen with an
    // uncaught exception - it should just show the same fallbacks used
    // while the profile hasn't loaded yet
    expect(tester.takeException(), isNull);
    expect(find.text('Fallback Name'), findsOneWidget);
  });
}
