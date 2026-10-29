import 'package:flutter/foundation.dart' show kIsWeb;
// detect whether the app is running on the web or mobile for google and git sign in
import 'package:firebase_core/firebase_core.dart';
// connect app with firebase project
import 'package:firebase_auth/firebase_auth.dart';
// handles authentication with firebase (register, login, etc)
import 'package:google_sign_in/google_sign_in.dart';
// responsible for the google popup after user clicks the google sign in button


class AuthService { 
// handles all things related to authentication (register, login, logout, etc). 
// makes it easier for screens to call on authenication functions without having to deal with firebase directly
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
// save login system as a private variable (_auth) so its only usable within the class
// prevents other parts of the app from accessing it directly and cause bugs
  Stream<User?> get authStateChanges => _auth.authStateChanges();
// check is user logged in or not and returns the current user if logged in
  User? get currentUser => _auth.currentUser;
// get the current user if logged in, otherwise return null
  String get displayName => _auth.currentUser?.displayName?.trim() ?? '';
// get the display name of the current user if logged in, otherwise return an empty string

  Future<void> updateDisplayName(String name) async {
  // changes the display name of the user once they are logged in with a valid account.
    final user = _auth.currentUser;
    // saves current user as a variable 
    if (user == null) {
    // if user not logged in, throw an error
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.updateDisplayName(name.trim());
    // remove spaces and update new name
    await user.reload();
    // reload the user to update with the new data
  }

  Future<void> _ignoreKnownBugIf({
  // firebase auth has a known bug that throws an error even if nothing went wrong
  // this ignores the error if action is confirmed to have worked successfully
    required Future<void> Function() action,
    // try to perform the action (register, login, etc)
    required bool Function() succeeded,
    // check if it worked
  }) async {
    try {
      await action();
    } catch (e) {
      if (!succeeded()) rethrow;
      // if action is actually not working, throw error, if succeeeded, ignore and continue
    }
  }

  static bool _isKnownBugError(Object e) =>
      e is TypeError && e.toString().contains('Pigeon');
  // checks if the error is a Pigeon error.
  // Pigeon is a code generation tool that helps Flutter apps communicate with platform-specific code.

  Future<void> register({
  // register new user with name email and password
    required String name,
    required String email,
    required String password,
  }) async {
    // create a temporary firebase app to register new user
    // this allows user to create account without logging into the main app straight away
    final FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'registrationTemp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try { 
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      // create a temporary firebase auth instance for the temp app
      try {
        final credential = await tempAuth.createUserWithEmailAndPassword(
        // create new user with email and password
          email: email.trim(),
          password: password,
        );
        await credential.user?.updateDisplayName(name.trim());
        // save user's name to firebase
        await credential.user?.sendEmailVerification();
        // send user email verification to confirm their email address
      } catch (e) {
        // account was not created, rethrow error
        if (tempAuth.currentUser == null) rethrow;
        // account was created, error was a Pigeon errpr, ignore error and continue
        await tempAuth.currentUser?.updateDisplayName(name.trim());
        await tempAuth.currentUser?.sendEmailVerification();
      }
    } finally {
      await tempApp.delete();
      // always delete temp app after try 
    }
  }

  Future<void> login({
  // login with email and password
    required String email,
    required String password,
  }) {
    return _ignoreKnownBugIf(
    // if theres a known bug error, ignore and continue
      action: () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
      succeeded: () => _auth.currentUser != null,
    );
  }

  Future<void> logout() async {
  // logout user 
    if (!kIsWeb) {
    // check if app is running on mobile and sign out of google if user logged in with google
    // not necessary for web because google sign in is handled by a popup and closes with the browser
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    // sign out of firebase auth
  }

  Future<void> sendPasswordResetEmail(String email) {
  // send password reset email to user if forgot password
    return _auth.sendPasswordResetEmail(email: email.trim());
    // remove spaces and send email
  }

  Future<void> sendEmailVerification() async {
    // send email verification if email not verified yet
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'requires-recent-login');
    // make sure user logged in befor sending email verification. throw error if not
    await user.sendEmailVerification();
    // send email verification to user
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  // check if user email is verified 
  // true if yes, false if no, or if user not logged in

  Future<void> reloadUser() async {
  // reload user data to get latest info (like email verification status)
    await _auth.currentUser?.reload();
  }

  bool get isEmailPasswordAccount =>
  // check if user can change password
  // only can change if logged in with email and password 
      _auth.currentUser?.providerData
      // check if user logged in with email and password or other providers (google/git)
          .any((info) => info.providerId == 'password') ??
          // check if there's "password" and returns true if yes
      false;

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      // check if user is logged in 
      // check if user has email (if logged in with google/git, no email)
      throw FirebaseAuthException(code: 'requires-recent-login');
      // if no credentials, throw error and ask user to relogin
    }

    final credential = EmailAuthProvider.credential(
    // check if user remember their old password
      email: user.email!,
      password: oldPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      // if wrong password, throw error 
      if (!_isKnownBugError(e)) rethrow;
    }

    try {
      await user.updatePassword(newPassword);
      // change to new password if old password is correct
    } catch (e) {
      if (!_isKnownBugError(e)) rethrow;
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
      // login check
    }
    await _ignoreKnownBugIf(
      // delete account and ignore pigeon error
      action: user.delete,
      succeeded: () => _auth.currentUser == null,
    );
    if (!kIsWeb) {
      // clear the cached google sign-in session too, otherwise the next
      // "sign in with google" silently reuses the deleted account instead
      // of showing the account picker
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // web method
      // firebase handles the google popup directly 
      await _ignoreKnownBugIf(
        action: () => _auth.signInWithPopup(GoogleAuthProvider()),
        succeeded: () => _auth.currentUser != null,
      );
      return;
    }
    // mobile method
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    // open google sign in as a popup and get account if user is logged in
    if (googleUser == null) return;
    // stop is user cancels googlee sign in
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    // get auth tokens to use in firebase sign in 
    // firebase uses these tokens to verify the user and create a session
    );
    await _ignoreKnownBugIf(
      action: () => _auth.signInWithCredential(credential),
      succeeded: () => _auth.currentUser != null,
      // check if user is logged in after signing in with google and ignore pigeon error if login successful
    );
  }

  Future<void> signInWithGitHub() {
    final githubProvider = GithubAuthProvider();
    // create github provider to handle github sign in
    return _ignoreKnownBugIf(
      action: () => kIsWeb
          ? _auth.signInWithPopup(githubProvider)
          // if use web then open popup with firebase
          : _auth.signInWithProvider(githubProvider),
          // if use mobile open native flow
          // firebase opens a native oauth browser flow then user logs in then firebase gets the result
      succeeded: () => _auth.currentUser != null,
      // check if user is logged in after signing in with github and ignore pigeon error if login successful
    );
  }

  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      // check if error is a fiirebase error
      switch (error.code) {
        // turn on error code
        // match error code with a friendly message to show to user
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No account found with that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak (use at least 6 characters).';
        case 'requires-recent-login':
          return 'For security, please log out and log in again, then try again.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email but a different sign-in method.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Sign-in was cancelled.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a while and try again.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
        // if code not recognised show default msg
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
    // only for non firebase errors
  }
}
