import 'package:connectivity_plus/connectivity_plus.dart';
// detects wifi / mobile data / no connection
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management

// additional feature: offline mode detection
// streams the device's connection status live - the list holds every
// active connection type (wifi, mobile, etc)
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// simple true/false the UI can watch: are we offline right now?
final isOfflineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).value;
  if (results == null) return false;
  // status not known yet (app just started) - assume online
  return results.contains(ConnectivityResult.none);
  // "none" in the list means no connection of any kind
});
