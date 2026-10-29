import 'package:cloud_firestore/cloud_firestore.dart';
// the firestore database package
import 'package:tpmentorship/models/user_profile.dart';
// the user profile data type

class UserService {
// handles the "users" collection in Firestore
// stores the extra profile info that Firebase Auth cant hold
// (course, year, bio, premium status, subjects the student needs help with)

  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');
  // a reference to the "users" collection

  // creates a profile document for a user if they dont have one yet
  // runs every login - safe because it does nothing when the profile exists
  // the document id is the auth uid so each user has exactly one profile
  Future<void> createProfileIfMissing({
    required String uid,
    required String fullName,
  }) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) return;
    // profile already exists, keep whatever is there

    final profile = UserProfile(
      uid: uid,
      fullName: fullName,
      createdAt: DateTime.now(),
    );
    await _users.doc(uid).set(profile.toMap());
  }

  // streams the logged in user's profile so the UI updates live
  // (eg premium badge appears instantly after paying)
  Stream<UserProfile?> streamProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!, doc.id);
    });
  }

  // updates the editable parts of the profile (from the edit profile form)
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String studentId,
    required String course,
    required String school,
    required String academicYear,
    required String bio,
    required List<String> subjects,
  }) {
    return _users.doc(uid).update({
      'fullName': fullName,
      'studentId': studentId,
      'course': course,
      'school': school,
      'academicYear': academicYear,
      'bio': bio,
      'subjects': subjects,
      // saving the profile at all - even editing again later - counts as
      // onboarding being complete, so the first-time auto-prompt never
      // reappears once the user has filled this form in once
      'onboardingComplete': true,
    });
    // isPremium and createdAt stay untouched
  }

  // marks the user as premium after the NETS QR payment completes
  // also clears any earlier cancellation so re-subscribing shows as active
  Future<void> upgradeToPremium(String uid) {
    return _users.doc(uid).update({
      'isPremium': true,
      'premiumCancelled': false,
      'premiumCancelledAt': null,
    });
  }

  // cancels premium - this is a student project, not a real billing
  // system, so there is no background job that flips isPremium off at
  // the end of the month. instead we just remember when the user
  // cancelled so the UI can show "active until end of <month>"
  Future<void> cancelPremium(String uid) {
    return _users.doc(uid).update({
      'premiumCancelled': true,
      'premiumCancelledAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // updates the user's role - called once, when they sign up as a mentor
  Future<void> setRole(String uid, String role) {
    return _users.doc(uid).update({'role': role});
  }

  // saves the user's chosen theme (AppPalette.name) to their profile so it
  // follows them across logins and devices
  Future<void> updateTheme(String uid, String themeName) {
    return _users.doc(uid).update({'themeName': themeName});
  }

  // saves whether this account wants session reminder notifications
  Future<void> updateNotificationsEnabled(String uid, bool enabled) {
    return _users.doc(uid).update({'notificationsEnabled': enabled});
  }
}
