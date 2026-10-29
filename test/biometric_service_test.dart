import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpmentorship/services/biometric_service.dart';

// a stand-in for the real plugin so these tests never need a device with
// a fingerprint sensor. Dart lets us implement any class as an interface
class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({
    this.supported = true,
    this.canCheck = true,
    this.authResult = true,
    this.throws,
  });

  final bool supported;
  final bool canCheck;
  final bool authResult;
  final Object? throws;

  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalls++;
    if (throws != null) throw throws!;
    return authResult;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BiometricService availability', () {
    test('is not available on the web', () async {
      final fake = _FakeLocalAuth();
      final service =
          BiometricService(localAuth: fake, isWebOverride: true);

      expect(await service.isAvailable(), isFalse);
    });

    test('is available when the device supports and can check biometrics',
        () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(supported: true, canCheck: true),
        isWebOverride: false,
      );

      expect(await service.isAvailable(), isTrue);
    });

    test('is not available when the device has no biometric hardware',
        () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(supported: true, canCheck: false),
        isWebOverride: false,
      );

      expect(await service.isAvailable(), isFalse);
    });

    test('is not available when the device is unsupported', () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(supported: false, canCheck: true),
        isWebOverride: false,
      );

      expect(await service.isAvailable(), isFalse);
    });
  });

  group('BiometricService authenticate', () {
    test('never prompts on the web', () async {
      final fake = _FakeLocalAuth();
      final service =
          BiometricService(localAuth: fake, isWebOverride: true);

      expect(await service.authenticate(), isFalse);
      expect(fake.authenticateCalls, 0);
    });

    test('returns true when the fingerprint matches', () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(authResult: true),
        isWebOverride: false,
      );

      expect(await service.authenticate(), isTrue);
    });

    test('returns false when the user cancels', () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(authResult: false),
        isWebOverride: false,
      );

      expect(await service.authenticate(), isFalse);
    });

    test('returns false instead of crashing when no fingerprint is enrolled',
        () async {
      // local_auth 3.x reports failures as LocalAuthException
      final service = BiometricService(
        localAuth: _FakeLocalAuth(
          throws: const LocalAuthException(
            code: LocalAuthExceptionCode.noCredentialsSet,
          ),
        ),
        isWebOverride: false,
      );

      expect(await service.authenticate(), isFalse);
    });

    test('returns false instead of crashing on a platform channel failure',
        () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(
          throws: PlatformException(code: 'channel-error'),
        ),
        isWebOverride: false,
      );

      expect(await service.authenticate(), isFalse);
    });
  });

  group('BiometricService opt-in flag', () {
    // stored per device, not on the Firestore profile - a fingerprint
    // belongs to one phone, not to the account
    test('is off until the user turns it on', () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(),
        isWebOverride: false,
      );

      expect(await service.isEnabled(), isFalse);
    });

    test('remembers being turned on', () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(),
        isWebOverride: false,
      );

      await service.setEnabled(true);

      expect(await service.isEnabled(), isTrue);
    });

    test('remembers being turned back off', () async {
      final service = BiometricService(
        localAuth: _FakeLocalAuth(),
        isWebOverride: false,
      );

      await service.setEnabled(true);
      await service.setEnabled(false);

      expect(await service.isEnabled(), isFalse);
    });

    test('never reports enabled on the web, even if the flag was set',
        () async {
      // a user could enable it on their phone and then open the web build
      // signed into the same account - the lock must not engage there
      final service =
          BiometricService(localAuth: _FakeLocalAuth(), isWebOverride: true);

      await service.setEnabled(true);

      expect(await service.isEnabled(), isFalse);
    });
  });
}
