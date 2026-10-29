import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:tpmentorship/models/user_profile.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/screens/edit_profile_screen.dart';
import 'package:tpmentorship/services/bio_writer_service.dart';

// a profile with every onboarding-required field already valid, so tests
// can isolate the one behaviour they're checking (e.g. the subjects gate)
// without tripping the form's other validators
UserProfile _validProfile({List<String> subjects = const []}) {
  return UserProfile(
    uid: 'u1',
    fullName: 'Ada Lovelace',
    studentId: '2501587F',
    course: 'Diploma in Applied Artificial Intelligence',
    academicYear: 'Year 1',
    createdAt: DateTime(2026, 1, 1),
    subjects: subjects,
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      // NoSplash avoids Material 3's default ink-sparkle splash, whose
      // fragment shader fails to decode in this test environment
      // ("Unsupported runtime stages format version") whenever a tap
      // animation is left to run to completion
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: child,
    ),
  );
}

// a BioWriterService whose Groq call always fails, so writeBio returns the
// offline template. deterministic, and never touches the network
BioWriterService _fakeBioWriter() {
  return BioWriterService(
    apiKey: 'test-key',
    client: MockClient((_) async => throw Exception('offline')),
  );
}

// same as _wrap, but with the bio writer swapped for the fake
Widget _wrapWithBioWriter(Widget child, BioWriterService service) {
  return ProviderScope(
    overrides: [bioWriterServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: child,
    ),
  );
}

void main() {
  group('EditProfileScreen onboarding lock', () {
    testWidgets('onboarding mode hides the back button and blocks popping',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(profile: _validProfile(), isOnboarding: true),
      ));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('regular edit mode keeps the back button and allows popping',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(profile: _validProfile()),
      ));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isTrue);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isTrue);
    });

    testWidgets('onboarding mode blocks saving with no subjects selected',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(
            profile: _validProfile(subjects: const []), isOnboarding: true),
      ));

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // let the snackbar animate in

      expect(find.text('Please select at least one subject'), findsOneWidget);
      // still on the same screen - Navigator never popped
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets(
        'onboarding mode does not block saving when a subject is selected',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(
            profile: _validProfile(subjects: const ['DAVA']),
            isOnboarding: true),
      ));

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
          find.text('Please select at least one subject'), findsNothing);
    });

    testWidgets('shows the notifications toggle only in onboarding mode',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(profile: _validProfile(), isOnboarding: true),
      ));
      final onboardingSwitch =
          tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(onboardingSwitch.value, isTrue);

      await tester.pumpWidget(_wrap(
        EditProfileScreen(profile: _validProfile()),
      ));
      expect(find.byType(SwitchListTile), findsNothing);
    });
  });

  group('EditProfileScreen school/diploma cascade', () {
    testWidgets(
        'a course matching a known diploma pre-selects School and Diploma',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(profile: _validProfile()),
      ));

      expect(find.text('School of Informatics & IT'), findsOneWidget);
      expect(find.text('Diploma in Applied Artificial Intelligence'),
          findsOneWidget);
    });

    testWidgets('a course matching nothing leaves School and Diploma unset',
        (tester) async {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada Lovelace',
        studentId: '2501587F',
        course: 'Diploma in Underwater Basket Weaving',
        academicYear: 'Year 1',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(_wrap(EditProfileScreen(profile: profile)));

      expect(find.text('Select your school'), findsOneWidget);
      expect(find.text('Select a school first'), findsOneWidget);
    });

    testWidgets(
        'switching School clears a Diploma that belonged to the old school',
        (tester) async {
      await tester.pumpWidget(_wrap(
        EditProfileScreen(profile: _validProfile()),
      ));

      // pre-selected from School of Informatics & IT
      expect(find.text('Diploma in Applied Artificial Intelligence'),
          findsOneWidget);

      await tester.tap(find.text('School of Informatics & IT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('School of Business').last);
      await tester.pumpAndSettle();

      expect(find.text('Diploma in Applied Artificial Intelligence'),
          findsNothing);
      expect(find.text('Select a diploma'), findsOneWidget);
    });

    testWidgets(
        'switching Academic Year from Year 1 to Year 2 clears a selected Common Programme diploma',
        (tester) async {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada Lovelace',
        studentId: '2501587F',
        course: 'Common ICT Programme',
        academicYear: 'Year 1',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(_wrap(EditProfileScreen(profile: profile)));
      expect(find.text('Common ICT Programme'), findsOneWidget);

      await tester.tap(find.text('Year 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 2').last);
      await tester.pumpAndSettle();

      expect(find.text('Common ICT Programme'), findsNothing);
      expect(find.text('Select a diploma'), findsOneWidget);
    });
  });

  group('EditProfileScreen AI bio', () {
    testWidgets('generating fills the Bio field from the service',
        (tester) async {
      await tester.pumpWidget(_wrapWithBioWriter(
        EditProfileScreen(profile: _validProfile()),
        _fakeBioWriter(),
      ));

      await tester.ensureVisible(find.text('Generate with AI'));
      await tester.tap(find.text('Generate with AI'));
      await tester.pumpAndSettle();

      // assert on a phrase only the template produces. checking for the
      // diploma name alone would pass even if nothing generated, because
      // the Diploma dropdown displays that same string
      expect(find.textContaining('Year 1 student in'), findsOneWidget);
    });

    testWidgets('with no Diploma selected it warns instead of generating',
        (tester) async {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada Lovelace',
        studentId: '2501587F',
        course: '',
        academicYear: 'Year 1',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(_wrapWithBioWriter(
        EditProfileScreen(profile: profile),
        _fakeBioWriter(),
      ));

      await tester.ensureVisible(find.text('Generate with AI'));
      await tester.tap(find.text('Generate with AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pick your School and Diploma first'), findsOneWidget);
    });

    testWidgets('a hand-written bio must be confirmed before replacing',
        (tester) async {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada Lovelace',
        studentId: '2501587F',
        course: 'Diploma in Applied Artificial Intelligence',
        academicYear: 'Year 1',
        bio: 'I wrote this myself',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(_wrapWithBioWriter(
        EditProfileScreen(profile: profile),
        _fakeBioWriter(),
      ));

      await tester.ensureVisible(find.text('Generate with AI'));
      await tester.tap(find.text('Generate with AI'));
      await tester.pumpAndSettle();

      expect(find.text('Replace your bio?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // cancelling left the original text alone
      expect(find.text('I wrote this myself'), findsOneWidget);
    });

    testWidgets('regenerating an AI bio does not ask for confirmation',
        (tester) async {
      await tester.pumpWidget(_wrapWithBioWriter(
        EditProfileScreen(profile: _validProfile()),
        _fakeBioWriter(),
      ));

      await tester.ensureVisible(find.text('Generate with AI'));
      await tester.tap(find.text('Generate with AI'));
      await tester.pumpAndSettle();

      // second tap - the box now holds exactly what the generator wrote
      await tester.tap(find.text('Generate with AI'));
      await tester.pumpAndSettle();

      expect(find.text('Replace your bio?'), findsNothing);
    });
  });
}
