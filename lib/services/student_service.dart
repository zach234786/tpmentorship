import 'package:cloud_firestore/cloud_firestore.dart';
// the firestore database package
import 'package:tpmentorship/models/student.dart';
// the student directory entry data type

class StudentService {
// handles the "students" collection in Firestore - a browsable directory
// of students looking for mentoring help, symmetric to MentorService's
// "mentors" collection, so a user with the Mentor role can look for
// mentees the same way students look for mentors

  final CollectionReference<Map<String, dynamic>> _students =
      FirebaseFirestore.instance.collection('students');
  // a reference to the "students" collection

  // SELECT ALL - streams every student in the directory
  Stream<List<Student>> streamAllStudents() {
    return _students.snapshots().map(_toStudentList);
  }

  // SELECT with FILTER criteria - students needing help with one subject
  Stream<List<Student>> streamStudentsBySubject(String subject) {
    return _students
        .where('subjects', arrayContains: subject)
        .snapshots()
        .map(_toStudentList);
  }

  // helper that converts a firestore snapshot into a list of Student objects
  List<Student> _toStudentList(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) => Student.fromMap(doc.data(), doc.id))
        .toList();
  }

  // UPSERT - keeps a real registered user's directory entry in sync with
  // their profile, keyed by their own auth uid (same pattern as
  // MentorService.becomeMentor/updateMentorProfile using the mentor's own
  // uid) so mentors browsing for mentees can find real students, not just
  // the seed data. called from EditProfileScreen after a profile save
  Future<void> publishToDirectory({
    required String uid,
    required String name,
    required String course,
    required String academicYear,
    required List<String> subjects,
    required String bio,
  }) {
    final student = Student(
      id: uid,
      name: name,
      course: course,
      academicYear: academicYear,
      subjects: subjects,
      bio: bio,
    );
    return _students.doc(uid).set(student.toMap());
  }

  // DELETE - removes a user's directory entry, eg once they clear every
  // subject and are no longer actively looking for help
  Future<void> removeFromDirectory(String uid) {
    return _students.doc(uid).delete();
  }

  // fills the students collection with starting data the first time the
  // app runs, same idea as MentorService.seedMentorsIfEmpty()
  Future<void> seedStudentsIfEmpty() async {
    final existing = await _students.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final student in _seedStudents) {
      batch.set(_students.doc(), student.toMap());
    }
    await batch.commit();
  }

  // the starting student directory records
  static final List<Student> _seedStudents = [
    Student(
      id: '',
      name: 'Xin Yi',
      course: 'Diploma in Information Technology',
      academicYear: 'Year 1',
      subjects: ['DAVA', 'COMT'],
      bio: 'Just started coding and could use help understanding loops and arrays.',
    ),
    Student(
      id: '',
      name: 'Ryan Goh',
      course: 'Diploma in Applied AI',
      academicYear: 'Year 2',
      subjects: ['LOMA'],
      bio: 'Struggling with the maths behind machine learning models.',
    ),
    Student(
      id: '',
      name: 'Hana Yusof',
      course: 'Diploma in Cybersecurity & Digital Forensics',
      academicYear: 'Year 1',
      subjects: ['GSOST'],
      bio: 'Governance frameworks are confusing me - looking for a study buddy.',
    ),
    Student(
      id: '',
      name: 'Timothy Lee',
      course: 'Diploma in Information Technology',
      academicYear: 'Year 3',
      subjects: ['ECOMM', 'COMT'],
      bio: 'Building my final year e-commerce project, need help with checkout flow.',
    ),
    Student(
      id: '',
      name: 'Michelle Tan',
      course: 'Diploma in Applied AI',
      academicYear: 'Year 2',
      subjects: ['DAVA', 'LOMA'],
      bio: 'Data cleaning is taking forever, would love some tips.',
    ),
    Student(
      id: '',
      name: 'Aiman Faiz',
      course: 'Diploma in Information Technology',
      academicYear: 'Year 1',
      subjects: ['COMT'],
      bio: 'New to programming, want to get comfortable before exams.',
    ),
    Student(
      id: '',
      name: 'Charmaine Ho',
      course: 'Diploma in Cybersecurity & Digital Forensics',
      academicYear: 'Year 2',
      subjects: ['GSOST', 'DAVA'],
      bio: 'Preparing for a security audit assignment, need pointers.',
    ),
    Student(
      id: '',
      name: 'Nabil Hakim',
      course: 'Diploma in Applied AI',
      academicYear: 'Year 1',
      subjects: ['LOMA', 'DAVA'],
      bio: 'AI concepts are cool but the statistics side is rough for me.',
    ),
    Student(
      id: '',
      name: 'Grace Lim',
      course: 'Diploma in Information Technology',
      academicYear: 'Year 2',
      subjects: ['ECOMM'],
      bio: 'Working on a group e-commerce app, our payment integration is broken.',
    ),
    Student(
      id: '',
      name: 'Darius Wong',
      course: 'Diploma in Cybersecurity & Digital Forensics',
      academicYear: 'Year 3',
      subjects: ['GSOST', 'COMT'],
      bio: 'Almost done with my diploma, just need help tying concepts together.',
    ),
    Student(
      id: '',
      name: 'Elena Cruz',
      course: 'Diploma in Applied AI',
      academicYear: 'Year 2',
      subjects: ['DAVA'],
      bio: 'Visualising data is fun but I keep picking the wrong chart types.',
    ),
    Student(
      id: '',
      name: 'Faris Idris',
      course: 'Diploma in Information Technology',
      academicYear: 'Year 1',
      subjects: ['COMT', 'ECOMM'],
      bio: 'Trying to build my first app and could use a mentor to check my code.',
    ),
  ];
}
