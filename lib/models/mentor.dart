class Mentor {
// the mentor data type, now backed by Firestore instead of sample data
  final String id;
  final String name;
  final String specialization;
  final double rating;
  final int reviewCount;
  final bool isOnline;
  final List<String> subjects;
  // list of subject codes the mentor can help with (eg DAVA, LOMA)
  // used by search filters and the AI matching feature
  final String availability;
  // day and time the mentor is free (eg "Mon 4-6pm")
  final String bio;
  // short description shown on the mentor detail screen

  Mentor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.rating,
    required this.reviewCount,
    required this.isOnline,
    this.subjects = const [],
    this.availability = '',
    this.bio = '',
  });

  // builds a Mentor object from a Firestore document
  // data is the document's fields, id is the document's id
  factory Mentor.fromMap(Map<String, dynamic> data, String id) {
    return Mentor(
      id: id,
      name: (data['name'] ?? '') as String,
      specialization: (data['specialization'] ?? '') as String,
      // firestore stores numbers as num so convert to the exact type we want
      rating: ((data['rating'] ?? 0) as num).toDouble(),
      reviewCount: ((data['reviewCount'] ?? 0) as num).toInt(),
      isOnline: (data['isOnline'] ?? false) as bool,
      // firestore lists come back as List<dynamic> so convert each item to String
      subjects: List<String>.from((data['subjects'] ?? []) as List),
      availability: (data['availability'] ?? '') as String,
      bio: (data['bio'] ?? '') as String,
    );
  }

  // converts this Mentor into a plain map so Firestore can save it
  // (the id is not included because Firestore stores it as the document id)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialization': specialization,
      'rating': rating,
      'reviewCount': reviewCount,
      'isOnline': isOnline,
      'subjects': subjects,
      'availability': availability,
      'bio': bio,
    };
  }
}
