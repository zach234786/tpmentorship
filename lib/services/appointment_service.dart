import 'package:cloud_firestore/cloud_firestore.dart';
// the firestore database package
import 'package:tpmentorship/models/session.dart';
// the session (appointment) data type

class AppointmentService {
// handles the "appointments" collection in Firestore
// this is the ONE set of CRUD for Part 3:
//   Insert     -> bookSession
//   Select all -> streamMySessions
//   Select one -> getSession
//   Update     -> updateSession (also used for the everyday "Cancel
//                 Session" action, which just sets status to 'Cancelled'
//                 rather than removing the booking from history)
//   Delete     -> cancelSession (permanently removes an already-cancelled
//                 session, see session_detail_screen.dart's "Delete
//                 Permanently" button)

  final CollectionReference<Map<String, dynamic>> _appointments =
      FirebaseFirestore.instance.collection('appointments');
  // a reference to the "appointments" collection

  // INSERT - saves a new booked session into Firestore
  // returns the new document id so we can schedule a reminder for it
  Future<String> bookSession(Session session) async {
    final doc = await _appointments.add(session.toMap());
    // .add() creates a new document with a random unique id
    return doc.id;
  }

  // SELECT ALL - streams every session belonging to the logged in student
  // a stream means the list updates live when anything changes in Firestore
  Stream<List<Session>> streamMySessions(String studentId) {
    return _appointments
        .where('studentId', isEqualTo: studentId)
        // only this student's sessions, not everyone's
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => Session.fromMap(doc.data(), doc.id))
          .toList();
      // sort by date in the app (soonest first) so firestore doesnt
      // need a special composite index for this query
      sessions.sort((a, b) => a.date.compareTo(b.date));
      return sessions;
    });
  }

  // SELECT with MULTIPLE FILTER criteria on DIFFERENT fields (advanced query)
  // gets this student's sessions AND with a certain status (eg only Pending)
  Stream<List<Session>> streamMySessionsByStatus(
      String studentId, String status) {
    return _appointments
        .where('studentId', isEqualTo: studentId)
        // filter 1: field "studentId"
        .where('status', isEqualTo: status)
        // filter 2: a different field, "status"
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => Session.fromMap(doc.data(), doc.id))
          .toList();
      sessions.sort((a, b) => a.date.compareTo(b.date));
      return sessions;
    });
  }

  // SELECT ALL (mentor side) - streams every session booked WITH this
  // mentor, so they can see requests students have sent them
  //
  // the mirror of streamMySessions: same collection, filtered on mentorId
  // instead of studentId. becomeMentor() writes the mentor document at
  // _mentors.doc(uid), so a real mentor's id is their auth uid and this
  // query finds the sessions belonging to their account
  Stream<List<Session>> streamMentorSessions(String mentorId) {
    return _appointments
        .where('mentorId', isEqualTo: mentorId)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => Session.fromMap(doc.data(), doc.id))
          .toList();
      // sorted in the app so firestore needs no composite index
      _sortForMentor(sessions);
      return sessions;
    });
  }

  // SELECT with MULTIPLE FILTER criteria (mentor side)
  // this mentor's sessions AND with a certain status (eg only Pending)
  Stream<List<Session>> streamMentorSessionsByStatus(
      String mentorId, String status) {
    return _appointments
        .where('mentorId', isEqualTo: mentorId)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => Session.fromMap(doc.data(), doc.id))
          .toList();
      _sortForMentor(sessions);
      return sessions;
    });
  }

  // premium students first, then soonest first inside each group
  //
  // this is what the premium plan's "Priority when booking sessions"
  // actually delivers: a paying student's request sits at the top of the
  // mentor's list instead of being buried. the mentor's card shows a
  // PREMIUM badge so the ordering is visibly explained rather than looking
  // arbitrary
  static void _sortForMentor(List<Session> sessions) {
    sessions.sort((a, b) {
      if (a.studentIsPremium != b.studentIsPremium) {
        return a.studentIsPremium ? -1 : 1;
      }
      return a.date.compareTo(b.date);
    });
  }

  // UPDATE (single field) - used by the mentor's Accept / Reject buttons
  //
  // writes only 'status' rather than round-tripping the whole document
  // through toMap(), so a mentor acting on a request cannot accidentally
  // overwrite the date, notes or anything else the student entered
  Future<void> updateStatus(String id, String status) {
    return _appointments.doc(id).update({'status': status});
  }

  // SELECT ONE - gets a single session by its document id
  Future<Session?> getSession(String id) async {
    final doc = await _appointments.doc(id).get();
    if (!doc.exists) return null;
    // return null if the session was deleted or the id is wrong
    return Session.fromMap(doc.data()!, doc.id);
  }

  // UPDATE - overwrites the changed fields of an existing session
  // used for rescheduling (new date/time) or changing the status
  Future<void> updateSession(Session session) {
    return _appointments.doc(session.id).update(session.toMap());
    // .update() fails if the document doesnt exist, which is what we want
    // (you shouldnt be able to edit a session that was already deleted)
  }

  // DELETE - permanently removes a session from Firestore
  Future<void> cancelSession(String id) {
    return _appointments.doc(id).delete();
  }

  // SELECT with AGGREGATION (advanced query: count)
  // counts how many sessions this student has completed
  // firestore counts on the server and only sends back the number,
  // which is faster than downloading every document and counting here
  Future<int> countSessionsByStatus(String studentId, String status) async {
    final result = await _appointments
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: status)
        .count()
        .get();
    return result.count ?? 0;
    // count can technically be null so fall back to 0
  }

  // SELECT with AGGREGATION - counts how many sessions a mentor has run
  // with one status, eg how many they've completed. shown as the
  // "N Sessions" badge on a mentor's profile
  Future<int> countSessionsByMentor(String mentorId, String status) async {
    final result = await _appointments
        .where('mentorId', isEqualTo: mentorId)
        .where('status', isEqualTo: status)
        .count()
        .get();
    return result.count ?? 0;
  }

  // turns firestore errors into short messages the user can understand
  // (same idea as AuthService.friendlyError)
  static String friendlyError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to do that.';
        case 'unavailable':
          return 'Cannot reach the server. Check your connection.';
        case 'not-found':
          return 'That session no longer exists.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
