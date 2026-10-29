import 'package:cloud_firestore/cloud_firestore.dart';
// needed for Timestamp, the date type Firestore uses

class Review {
// a student's rating and comment left for a mentor after a completed
// session, stored in the "reviews" collection
// reviews are never edited or deleted once posted (like most real
// review systems) so this model only needs fromMap/toMap, no copyWith
  final String id;
  final String mentorId;
  final String studentId;
  final String studentName;
  final String sessionId;
  final int rating;
  // 1 to 5 stars
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.mentorId,
    required this.studentId,
    required this.studentName,
    required this.sessionId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  // builds a Review from a Firestore document
  factory Review.fromMap(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      mentorId: (data['mentorId'] ?? '') as String,
      studentId: (data['studentId'] ?? '') as String,
      studentName: (data['studentName'] ?? '') as String,
      sessionId: (data['sessionId'] ?? '') as String,
      rating: ((data['rating'] ?? 0) as num).toInt(),
      comment: (data['comment'] ?? '') as String,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // converts this Review into a plain map so Firestore can save it
  Map<String, dynamic> toMap() {
    return {
      'mentorId': mentorId,
      'studentId': studentId,
      'studentName': studentName,
      'sessionId': sessionId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
