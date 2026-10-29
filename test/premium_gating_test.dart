import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/session.dart';
import 'package:tpmentorship/models/user_profile.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';

Session _withMentor(String mentorId, String status,
    {bool studentIsPremium = false}) {
  return Session(
    id: '$mentorId-$status',
    title: 'A session',
    mentorName: 'Damian Tan',
    date: DateTime(2026, 8, 20),
    time: '3:00 PM',
    status: status,
    mentorId: mentorId,
    studentIsPremium: studentIsPremium,
  );
}

UserProfile _profile({bool isPremium = false}) {
  return UserProfile(
    uid: 'u1',
    fullName: 'Ada Lovelace',
    createdAt: DateTime(2026, 1, 1),
    isPremium: isPremium,
  );
}

// a container with the two providers canMessageMentorProvider reads
ProviderContainer _container({
  required bool isPremium,
  required List<Session> sessions,
}) {
  return ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      userProfileProvider
          .overrideWith((ref) => Stream.value(_profile(isPremium: isPremium))),
      mySessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    ],
  );
}

// canMessageMentorProvider reads BOTH streams, and a StreamProvider's
// first read is always loading - so both have to deliver a value before
// the answer means anything. awaiting only one silently reads an empty
// session list and every "booked" case wrongly reports locked
Future<void> _settle(ProviderContainer container) async {
  await container.read(userProfileProvider.future);
  await container.read(mySessionsProvider.future);
}

void main() {
  group('canMessageMentorProvider', () {
    test('a premium member can message a mentor they never booked', () async {
      final container = _container(isPremium: true, sessions: const []);
      addTearDown(container.dispose);
      // let the overridden streams deliver their first value
      await _settle(container);

      expect(container.read(canMessageMentorProvider('mentor-1')), isTrue);
    });

    test('a free member cannot message a mentor they never booked', () async {
      final container = _container(isPremium: false, sessions: const []);
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(canMessageMentorProvider('mentor-1')), isFalse);
    });

    test('booking unlocks the mentor for a free member', () async {
      final container = _container(
        isPremium: false,
        sessions: [_withMentor('mentor-1', 'Pending')],
      );
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(canMessageMentorProvider('mentor-1')), isTrue);
    });

    test('a completed session keeps the mentor unlocked', () async {
      final container = _container(
        isPremium: false,
        sessions: [_withMentor('mentor-1', 'Completed')],
      );
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(canMessageMentorProvider('mentor-1')), isTrue);
    });

    test('a cancelled session does not unlock the mentor', () async {
      final container = _container(
        isPremium: false,
        sessions: [_withMentor('mentor-1', 'Cancelled')],
      );
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(canMessageMentorProvider('mentor-1')), isFalse);
    });

    test('booking one mentor does not unlock a different mentor', () async {
      final container = _container(
        isPremium: false,
        sessions: [_withMentor('mentor-1', 'Confirmed')],
      );
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(canMessageMentorProvider('mentor-2')), isFalse);
    });
  });

  group('Session studentIsPremium', () {
    test('defaults to false when not provided', () {
      expect(_withMentor('mentor-1', 'Pending').studentIsPremium, isFalse);
    });

    test('round-trips through toMap/fromMap', () {
      final session = _withMentor('mentor-1', 'Pending', studentIsPremium: true);

      final rebuilt = Session.fromMap(session.toMap(), session.id);

      expect(rebuilt.studentIsPremium, isTrue);
    });

    test('fromMap defaults to false when the field is missing', () {
      final rebuilt = Session.fromMap(const <String, dynamic>{}, 'x');

      expect(rebuilt.studentIsPremium, isFalse);
    });
  });
}
