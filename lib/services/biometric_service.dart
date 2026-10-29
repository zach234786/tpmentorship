import 'package:flutter/foundation.dart' show kIsWeb;
// tells us whether the app is running in a browser
import 'package:flutter/services.dart';
// for PlatformException, thrown when the sensor refuses
import 'package:local_auth/local_auth.dart';
// the fingerprint / face unlock plugin
import 'package:shared_preferences/shared_preferences.dart';
// stores the opt-in flag on this device

class BiometricService {
// additional feature: unlocking the app with a fingerprint or face scan
//
// how it works:
// Firebase already keeps the user signed in between launches, so this is
// an app LOCK over that saved session rather than a second way to log in.
// no password is ever stored on the device - the fingerprint only decides
// whether the already-signed-in session is revealed or stays hidden
//
// the opt-in flag lives in shared_preferences (this device) instead of on
// the Firestore profile like themeName does, because a fingerprint belongs
// to one phone - enabling it on your phone should not lock you out of the
// web build on a library computer

  BiometricService({LocalAuthentication? localAuth, bool? isWebOverride})
      : _localAuth = localAuth ?? LocalAuthentication(),
        _isWeb = isWebOverride ?? kIsWeb;
  // both are injectable so the tests can run without a real sensor

  final LocalAuthentication _localAuth;
  final bool _isWeb;

  // the shared_preferences key holding the opt-in flag
  static const String _enabledKey = 'biometric_unlock_enabled';

  // can this device actually do a fingerprint / face check right now?
  // false in a browser - local_auth has no web implementation
  Future<bool> isAvailable() async {
    if (_isWeb) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      return await _localAuth.canCheckBiometrics;
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
      // the platform channel is missing or the query failed - treat the
      // feature as unavailable rather than crashing the settings screen
    }
  }

  // shows the system fingerprint / face prompt
  // returns true only when the scan succeeded
  Future<bool> authenticate({
    String reason = 'Unlock TPMentorship',
  }) async {
    if (_isWeb) return false;
    // never even reach for the plugin in a browser
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        // keeps the prompt up if the app briefly goes to the background
        biometricOnly: false,
        // lets the user fall back to their device PIN / pattern, so
        // someone whose sensor fails is not locked out of their account
      );
    } on LocalAuthException {
      return false;
      // eg no fingerprint enrolled, cancelled, or too many failed tries.
      // local_auth 3.x reports these as LocalAuthException
    } on PlatformException {
      return false;
      // older style channel failure - treated the same way
    }
  }

  // has the user turned the lock on for this device?
  Future<bool> isEnabled() async {
    if (_isWeb) return false;
    // the flag may have been set on a phone while signed into the same
    // account - the browser build must never try to lock
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  // remembers the user's choice from the settings screen
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
