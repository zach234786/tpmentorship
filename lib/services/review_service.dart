import 'package:cloud_firestore/cloud_firestore.dart';
// the firestore database package
import 'package:tpmentorship/models/review.dart';
// the review data type
import 'package:tpmentorship/services/mentor_service.dart';
// used to keep the mentor's rating in sync after a new review

class ReviewService {
// handles the "reviews" collection in Firestore
// a student leaves a review after marking a session as completed - see
// leave_review_screen.dart and session_detail_screen.dart

  final CollectionReference<Map<String, dynamic>> _reviews =
      FirebaseFirestore.instance.collection('reviews');
  // a reference to the "reviews" collection

  final MentorService _mentorService = MentorService();
  // used to recompute the mentor's rating after this review is added

  // SELECT ALL - streams every review left for one mentor, newest first
  Stream<List<Review>> streamReviewsForMentor(String mentorId) {
    return _reviews
        .where('mentorId', isEqualTo: mentorId)
        .snapshots()
        .map((snapshot) {
      final reviews = snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
      // sort here instead of orderBy so no composite index is needed
      // alongside the mentorId filter
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    });
  }

  // INSERT - saves a new review, then recalculates the mentor's overall
  // rating and review count from every review they have ever received
  Future<void> addReview(Review review) async {
    await _reviews.add(review.toMap());

    // pull every review for this mentor to compute a fresh average -
    // review lists per mentor are small, so doing this client-side is
    // simpler and cheaper than a server-side aggregation function
    final snapshot = await _reviews
        .where('mentorId', isEqualTo: review.mentorId)
        .get();
    final ratings = snapshot.docs
        .map((doc) => ((doc.data()['rating'] ?? 0) as num).toDouble())
        .toList();
    final average = ratings.reduce((a, b) => a + b) / ratings.length;

    await _mentorService.recomputeRatingFromReviews(
      mentorId: review.mentorId,
      averageRating: double.parse(average.toStringAsFixed(1)),
      // round to 1 decimal place, eg 4.7
      reviewCount: ratings.length,
    );
  }
}
