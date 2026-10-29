import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/session.dart';

void main() {
  // a fully populated session, the shape a real booking has once a student
  // has booked it (book_session_screen saves studentName and
  // studentIsPremium so the mentor's request list can show who booked)
  Session buildSession() => Session(
        id: 's1',
        title: 'DAVA revision',
        mentorName: 'Ada',
        date: DateTime(2026, 8, 20, 14, 0),
        time: '2:00 PM',
        status: 'Confirmed',
        studentId: 'stu1',
        studentName: 'Zachary',
        studentIsPremium: true,
        mentorId: 'men1',
        subject: 'DAVA',
        notes: 'bring past year papers',
      );

  group('Session copyWith', () {
    test('keeps every field the caller did not change', () {
      final original = buildSession();

      final updated = original.copyWith(status: 'Cancelled');

      expect(updated.status, 'Cancelled');
      // the fields copyWith is meant to carry across untouched
      expect(updated.id, original.id);
      expect(updated.title, original.title);
      expect(updated.mentorName, original.mentorName);
      expect(updated.date, original.date);
      expect(updated.time, original.time);
      expect(updated.studentId, original.studentId);
      expect(updated.mentorId, original.mentorId);
      expect(updated.subject, original.subject);
      expect(updated.notes, original.notes);
    });

    test('keeps studentName and studentIsPremium', () {
      // these travel on the session because firestore.rules lets a user
      // read only their OWN users/{uid} document - the mentor cannot look
      // them up, so losing them here blanks the "Booked by" label and the
      // PREMIUM badge on the mentor's request list
      final original = buildSession();

      final updated = original.copyWith(status: 'Cancelled');

      expect(updated.studentName, 'Zachary');
      expect(updated.studentIsPremium, isTrue);
    });

    test('a rescheduled session still carries the student details', () {
      // reschedule writes the whole document back through toMap(), so
      // anything copyWith drops is erased in firestore
      final original = buildSession();

      final updated = original.copyWith(
        date: DateTime(2026, 8, 25, 10, 0),
        time: '10:00 AM',
        status: 'Pending',
      );
      final saved = updated.toMap();

      expect(saved['studentName'], 'Zachary');
      expect(saved['studentIsPremium'], isTrue);
    });
  });
}
