import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/services/biometric_service.dart';
// the fingerprint / face unlock service

// one shared instance of the biometric service for the whole app
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

enum LockStatus {
// whether the app is hidden behind the fingerprint lock screen
  checking,
  // still reading the saved opt-in flag
  locked,
  // opted in and not unlocked yet this launch
  unlocked,
  // either never opted in, or the fingerprint already matched
}

class BiometricLockController extends StateNotifier<LockStatus> {
// decides whether the signed in user has to scan a fingerprint before
// the app is revealed
//
// the flag is read ONCE, when the app starts. that is deliberate: if it
// were re-read whenever it changed, turning the lock on in settings would
// immediately throw a lock screen over the page the user is standing on.
// enabling it takes effect from the next launch instead

  BiometricLockController(this._service) : super(LockStatus.checking) {
    _check();
  }

  final BiometricService _service;

  Future<void> _check() async {
    final enabled = await _service.isEnabled();
    state = enabled ? LockStatus.locked : LockStatus.unlocked;
  }

  // shows the system fingerprint prompt, and reveals the app if it matches
  // returns whether the scan succeeded, so the lock screen can show an
  // error message when it didn't
  Future<bool> unlock() async {
    final ok = await _service.authenticate();
    if (ok) state = LockStatus.unlocked;
    return ok;
  }
}

// the provider the auth gate watches to decide between the lock screen
// and the main app
final biometricLockProvider =
    StateNotifierProvider<BiometricLockController, LockStatus>((ref) {
  return BiometricLockController(ref.watch(biometricServiceProvider));
});
