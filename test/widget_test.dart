// Unit tests for the TPMentorship app.
//
// We test AuthService.friendlyError(), which turns raw Firebase error codes
// into the friendly messages shown to the user. It is a pure function (no
// Firebase or UI needed), so it is fast and reliable to test.

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tpmentorship/services/auth_service.dart';

void main() {
  group('AuthService.friendlyError', () {
    test('maps wrong-password to a friendly message', () {
      final error = FirebaseAuthException(code: 'wrong-password');
      expect(
        AuthService.friendlyError(error),
        'Incorrect email or password.',
      );
    });

    test('maps email-already-in-use to a friendly message', () {
      final error = FirebaseAuthException(code: 'email-already-in-use');
      expect(
        AuthService.friendlyError(error),
        'An account already exists for that email.',
      );
    });

    test('maps weak-password to a friendly message', () {
      final error = FirebaseAuthException(code: 'weak-password');
      expect(
        AuthService.friendlyError(error),
        'Password is too weak (use at least 6 characters).',
      );
    });

    test('falls back to a generic message for unknown errors', () {
      expect(
        AuthService.friendlyError(Exception('some random error')),
        'Something went wrong. Please try again.',
      );
    });
  });
}
