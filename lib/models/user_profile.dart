import 'package:cloud_firestore/cloud_firestore.dart';
// needed for Timestamp, the date type Firestore uses

class UserProfile {
// extra info about a user that Firebase Auth does not store
// (the "users" table from the proposal), kept in the "users" collection
// the document id is the user's Firebase Auth uid so auth and firestore link up
  final String uid;
  final String fullName;
  final String studentId;
  final String course;
  final String school;
  // which TP school the course belongs to (see lib/constants/tp_schools.dart)
  final String academicYear;
  final String bio;
  final bool isPremium;
  // true after the user pays for premium via the NETS QR flow
  final List<String> subjects;
  // subjects the student wants help with (the "student needs" from the proposal)
  // this is what the AI matching feature uses to recommend mentors
  final DateTime createdAt;
  final String role;
  // 'Student' by default, becomes 'Student & Mentor' after signing up
  // as a mentor (see MentorService.becomeMentor)
  final bool onboardingComplete;
  // false until the user saves their profile for the first time - used to
  // auto-prompt first time users to fill in their details after signup
  final bool premiumCancelled;
  final DateTime? premiumCancelledAt;
  // when the user cancels premium we keep isPremium as-is (this is a
  // student project, not a real billing system) but remember the
  // cancellation so the profile screen can show "active until end of
  // <month>" instead of the normal active badge
  final String? themeName;
  // which AppPalette this account has chosen (matches AppPalette.name,
  // e.g. 'TP Light') - null means the account never picked one, so the
  // app falls back to the default palette
  final bool notificationsEnabled;
  // whether this account wants session reminder notifications - set
  // during onboarding (defaults to true), reconfigurable in Settings

  UserProfile({
    required this.uid,
    required this.fullName,
    this.studentId = '',
    this.course = '',
    this.school = '',
    this.academicYear = '',
    this.bio = '',
    this.isPremium = false,
    this.subjects = const [],
    required this.createdAt,
    this.role = 'Student',
    this.onboardingComplete = false,
    this.premiumCancelled = false,
    this.premiumCancelledAt,
    this.themeName,
    this.notificationsEnabled = true,
  });

  bool get isMentor => role.contains('Mentor');
  // true once the user has signed up as a mentor (role becomes
  // 'Student & Mentor') - used to gate mentor-only UI like the
  // search screen's browse-students toggle

  // builds a UserProfile from a Firestore document
  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      fullName: (data['fullName'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      course: (data['course'] ?? '') as String,
      school: (data['school'] ?? '') as String,
      academicYear: (data['academicYear'] ?? '') as String,
      bio: (data['bio'] ?? '') as String,
      isPremium: (data['isPremium'] ?? false) as bool,
      subjects: List<String>.from((data['subjects'] ?? []) as List),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      role: (data['role'] ?? 'Student') as String,
      onboardingComplete: (data['onboardingComplete'] ?? false) as bool,
      premiumCancelled: (data['premiumCancelled'] ?? false) as bool,
      premiumCancelledAt: data['premiumCancelledAt'] is Timestamp
          ? (data['premiumCancelledAt'] as Timestamp).toDate()
          : null,
      themeName: data['themeName'] as String?,
      notificationsEnabled: (data['notificationsEnabled'] ?? true) as bool,
    );
  }

  // converts this profile into a plain map so Firestore can save it
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'studentId': studentId,
      'course': course,
      'school': school,
      'academicYear': academicYear,
      'bio': bio,
      'isPremium': isPremium,
      'subjects': subjects,
      'createdAt': Timestamp.fromDate(createdAt),
      'role': role,
      'onboardingComplete': onboardingComplete,
      'premiumCancelled': premiumCancelled,
      'premiumCancelledAt': premiumCancelledAt == null
          ? null
          : Timestamp.fromDate(premiumCancelledAt!),
      'themeName': themeName,
      'notificationsEnabled': notificationsEnabled,
    };
  }
}
