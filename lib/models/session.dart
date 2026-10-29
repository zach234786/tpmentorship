import 'package:cloud_firestore/cloud_firestore.dart';
// needed for Timestamp, the date type Firestore uses

class Session {
// one booked mentoring session (the "appointments" table from the proposal)
// this is the CRUD domain for Part 3, stored in the "appointments" collection
  final String id;
  final String title;
  final String mentorName;
  final DateTime date;
  final String time;
  final String status;
  // Pending / Confirmed / Completed / Cancelled
  final String studentId;
  // firebase auth uid of the student who booked the session
  final String studentName;
  // the student's display name, saved at booking time so the mentor's
  // request list can show who booked without a second lookup
  final bool studentIsPremium;
  // whether the student was premium when they booked. stored here because
  // firestore.rules lets a user read only their OWN users/{uid} document,
  // so the mentor cannot look this up - it has to travel on the session.
  // premium requests sort to the top of the mentor's list
  final String mentorId;
  // firestore document id of the mentor - for a real (non-seed) mentor
  // this is their firebase auth uid, so it identifies their account
  final String subject;
  // the subject the session is about (eg DAVA)
  final String notes;
  // optional extra info the student typed when booking

  Session({
    required this.id,
    required this.title,
    required this.mentorName,
    required this.date,
    required this.time,
    required this.status,
    this.studentId = '',
    this.studentName = '',
    this.studentIsPremium = false,
    this.mentorId = '',
    this.subject = '',
    this.notes = '',
  });

  // builds a Session object from a Firestore document
  factory Session.fromMap(Map<String, dynamic> data, String id) {
    return Session(
      id: id,
      title: (data['title'] ?? '') as String,
      mentorName: (data['mentorName'] ?? '') as String,
      // firestore stores dates as Timestamp so convert back to DateTime
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      time: (data['time'] ?? '') as String,
      status: (data['status'] ?? 'Pending') as String,
      studentId: (data['studentId'] ?? '') as String,
      // sessions booked before studentName existed fall back to a label
      // rather than showing the mentor a raw uid
      studentName: (data['studentName'] ?? '') as String,
      studentIsPremium: (data['studentIsPremium'] ?? false) as bool,
      mentorId: (data['mentorId'] ?? '') as String,
      subject: (data['subject'] ?? '') as String,
      notes: (data['notes'] ?? '') as String,
    );
  }

  // converts this Session into a plain map so Firestore can save it
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'mentorName': mentorName,
      // convert DateTime into Firestore's Timestamp type
      'date': Timestamp.fromDate(date),
      'time': time,
      'status': status,
      'studentId': studentId,
      'studentName': studentName,
      'studentIsPremium': studentIsPremium,
      'mentorId': mentorId,
      'subject': subject,
      'notes': notes,
    };
  }

  // makes a copy of this session with only some fields changed
  // used when updating (eg rescheduling keeps everything except date/time)
  Session copyWith({
    DateTime? date,
    String? time,
    String? status,
    String? notes,
  }) {
    return Session(
      id: id,
      title: title,
      mentorName: mentorName,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      studentId: studentId,
      // these two must be carried across explicitly. updateSession() saves
      // the whole document through toMap(), so any field copyWith forgets
      // is wiped in firestore - and the mentor cannot read them back from
      // the student's users/{uid} document to repair it
      studentName: studentName,
      studentIsPremium: studentIsPremium,
      mentorId: mentorId,
      subject: subject,
      notes: notes ?? this.notes,
    );
  }
}
