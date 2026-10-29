import 'package:firebase_auth/firebase_auth.dart';
// handles authenication with firebase (register, login, etc)
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import flutter riverpod package for state management
import 'package:tpmentorship/services/auth_service.dart';
// import configuration for firebase project

final authServiceProvider = Provider<AuthService>((ref) {
  // a provider that stores a single authservice for the app to use
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  // checks users login status live and updates accordingly, giving you the current user
  return authService.authStateChanges;
});
