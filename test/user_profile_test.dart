import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/user_profile.dart';

void main() {
  group('UserProfile themeName', () {
    test('defaults to null when not provided', () {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(profile.themeName, isNull);
    });

    test('round-trips through toMap/fromMap', () {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada',
        createdAt: DateTime(2026, 1, 1),
        themeName: 'TP Light',
      );

      final rebuilt = UserProfile.fromMap(profile.toMap(), profile.uid);

      expect(rebuilt.themeName, 'TP Light');
    });

    test('fromMap defaults themeName to null when the field is missing', () {
      final profile = UserProfile.fromMap({
        'fullName': 'Ada',
        'createdAt': null,
      }, 'u1');

      expect(profile.themeName, isNull);
    });
  });

  group('UserProfile notificationsEnabled', () {
    test('defaults to true when not provided', () {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(profile.notificationsEnabled, isTrue);
    });

    test('round-trips through toMap/fromMap', () {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada',
        createdAt: DateTime(2026, 1, 1),
        notificationsEnabled: false,
      );

      final rebuilt = UserProfile.fromMap(profile.toMap(), profile.uid);

      expect(rebuilt.notificationsEnabled, isFalse);
    });

    test('fromMap defaults to true when the field is missing', () {
      final profile = UserProfile.fromMap({
        'fullName': 'Ada',
        'createdAt': null,
      }, 'u1');

      expect(profile.notificationsEnabled, isTrue);
    });
  });

  group('UserProfile school', () {
    test('defaults to empty string when not provided', () {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(profile.school, '');
    });

    test('round-trips through toMap/fromMap', () {
      final profile = UserProfile(
        uid: 'u1',
        fullName: 'Ada',
        createdAt: DateTime(2026, 1, 1),
        school: 'School of Informatics & IT',
      );

      final rebuilt = UserProfile.fromMap(profile.toMap(), profile.uid);

      expect(rebuilt.school, 'School of Informatics & IT');
    });

    test('fromMap defaults school to empty string when the field is missing',
        () {
      final profile = UserProfile.fromMap({
        'fullName': 'Ada',
        'createdAt': null,
      }, 'u1');

      expect(profile.school, '');
    });
  });
}
