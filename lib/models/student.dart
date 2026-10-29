class Student {
// a browsable directory entry for a student looking for mentoring help,
// stored in the "students" collection
//
// this is deliberately separate from the real "users" collection: it is
// seed/demo data (same idea as MentorService's seeded mentors) so mentors
// browsing for mentees always have a rich list to look through, without
// needing lots of real registered test accounts. a real student's own
// "subjects I need help with" still lives on their own user profile
// (see UserProfile.subjects) and is what powers the AI matching feature.
  final String id;
  final String name;
  final String course;
  final String academicYear;
  final List<String> subjects;
  // subjects this student needs help with
  final String bio;

  Student({
    required this.id,
    required this.name,
    required this.course,
    required this.academicYear,
    this.subjects = const [],
    this.bio = '',
  });

  // builds a Student from a Firestore document
  factory Student.fromMap(Map<String, dynamic> data, String id) {
    return Student(
      id: id,
      name: (data['name'] ?? '') as String,
      course: (data['course'] ?? '') as String,
      academicYear: (data['academicYear'] ?? '') as String,
      subjects: List<String>.from((data['subjects'] ?? []) as List),
      bio: (data['bio'] ?? '') as String,
    );
  }

  // converts this Student into a plain map so Firestore can save it
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'course': course,
      'academicYear': academicYear,
      'subjects': subjects,
      'bio': bio,
    };
  }
}
