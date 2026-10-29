import 'package:cloud_firestore/cloud_firestore.dart';
// the firestore database package

class AccountDeletionService {
// removes everything a user owns in Firestore before their auth account
// is deleted
//
// WHY THIS RUNS FIRST, ALWAYS:
// every rule in firestore.rules requires `request.auth != null`. the
// moment FirebaseAuth deletes the user, this client is anonymous and
// every one of these writes is rejected with PERMISSION_DENIED. so the
// cleanup cannot be bolted on after AuthService.deleteAccount() - it has
// to happen while the account still exists
//
// this is the single place that answers "what does deleting my account
// actually remove?", so keep it in sync with firestore.rules

  AccountDeletionService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // wipes this user's data. deleting a document that was never created
  // (eg mentors/{uid} for someone who never signed up as a mentor) is a
  // no-op in Firestore, so every branch is safe to run unconditionally
  Future<void> deleteAllDataFor(String uid) async {
    final batch = _db.batch();

    // the mentor listing - this is the one that used to survive account
    // deletion and keep showing up in search
    batch.delete(_db.collection('mentors').doc(uid));

    // the browse-students directory entry
    batch.delete(_db.collection('students').doc(uid));

    // sessions this user booked as a student. firestore.rules allows
    // delete only for the owning student, which is exactly this case
    final booked = await _db
        .collection('appointments')
        .where('studentId', isEqualTo: uid)
        .get();
    for (final doc in booked.docs) {
      batch.delete(doc.reference);
    }

    // sessions booked WITH this user as the mentor are cancelled, not
    // deleted: the student on the other side owns that record and should
    // keep it. cancelling tells them the session is off, instead of
    // leaving a booking pointing at a mentor who no longer exists.
    // (the rules only grant the mentor update, not delete, anyway)
    final asMentor = await _db
        .collection('appointments')
        .where('mentorId', isEqualTo: uid)
        .get();
    for (final doc in asMentor.docs) {
      batch.update(doc.reference, {'status': 'Cancelled'});
    }

    // the profile document last, so a failure part way through still
    // leaves the profile around to retry from
    batch.delete(_db.collection('users').doc(uid));

    await batch.commit();
  }

  // NOT removed by the above, on purpose:
  //
  // - reviews: firestore.rules has no delete rule for them by design.
  //   deleting the person who wrote a review should not erase a mentor's
  //   public feedback history.
  // - conversations and their messages subcollection: no delete rule
  //   either, and clearing a subcollection from a client means paging
  //   through every message. that belongs in a Cloud Function, not here.
  //   the other participant keeps the thread.
}
