import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/providers/biometric_provider.dart';
import 'package:tpmentorship/services/biometric_service.dart';

// a stand-in for BiometricService so the controller can be tested without
// a fingerprint sensor or shared_preferences
class _FakeBiometricService implements BiometricService {
  _FakeBiometricService({
    this.enabled = false,
    this.scanSucceeds = true,
  });

  bool enabled;
  final bool scanSucceeds;
  int authenticateCalls = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({String reason = 'Unlock TPMentorship'}) async {
    authenticateCalls++;
    return scanSucceeds;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _containerWith(_FakeBiometricService fake) {
  final container = ProviderContainer(overrides: [
    biometricServiceProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('BiometricLockController', () {
    test('leaves the app unlocked when the user never opted in', () async {
      final container = _containerWith(_FakeBiometricService(enabled: false));

      container.read(biometricLockProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(biometricLockProvider), LockStatus.unlocked);
    });

    test('locks the app when the user opted in', () async {
      final container = _containerWith(_FakeBiometricService(enabled: true));

      container.read(biometricLockProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(biometricLockProvider), LockStatus.locked);
    });

    test('unlocks when the fingerprint matches', () async {
      final fake = _FakeBiometricService(enabled: true, scanSucceeds: true);
      final container = _containerWith(fake);

      container.read(biometricLockProvider);
      await Future<void>.delayed(Duration.zero);

      final ok = await container.read(biometricLockProvider.notifier).unlock();

      expect(ok, isTrue);
      expect(container.read(biometricLockProvider), LockStatus.unlocked);
      expect(fake.authenticateCalls, 1);
    });

    test('stays locked when the fingerprint does not match', () async {
      final fake = _FakeBiometricService(enabled: true, scanSucceeds: false);
      final container = _containerWith(fake);

      container.read(biometricLockProvider);
      await Future<void>.delayed(Duration.zero);

      final ok = await container.read(biometricLockProvider.notifier).unlock();

      expect(ok, isFalse);
      expect(container.read(biometricLockProvider), LockStatus.locked);
    });

    test('turning the lock on in settings does not lock the current session',
        () async {
      // the flag is read once at launch, so enabling it takes effect the
      // next time the app starts rather than throwing up a lock screen
      // over the settings page the user is standing on
      final fake = _FakeBiometricService(enabled: false);
      final container = _containerWith(fake);

      container.read(biometricLockProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(biometricLockProvider), LockStatus.unlocked);

      await fake.setEnabled(true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(biometricLockProvider), LockStatus.unlocked);
    });
  });
}
