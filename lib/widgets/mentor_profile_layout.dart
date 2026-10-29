import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/review.dart';
// the data types
import 'package:tpmentorship/providers/data_providers.dart';
// live firestore providers
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class MentorProfileLayout extends ConsumerWidget {
// the shared visual layout for a mentor's profile - used by BOTH:
//   - mentor_detail_screen.dart  (viewing someone ELSE's profile, read only)
//   - mentor_profile_screen.dart (viewing YOUR OWN profile, editable)
// this keeps the two screens looking identical apart from the edit
// controls and the book-session button, instead of duplicating this
// ~300 line layout twice
  final Mentor mentor;
  final bool isEditable;
  // true only on "My Mentor Profile" - shows the edit pencil and hides
  // the book-a-session button (you cant book yourself)
  final VoidCallback? onEdit;
  // opens the become/edit mentor form, only used when isEditable
  final VoidCallback? onBookSession;
  // only used when NOT editable (viewing another mentor)
  final List<Widget> extraContent;
  // extra widgets shown after availability, before the reviews section -
  // eg mentor_detail_screen.dart's "view study resources" link. empty by
  // default so the own-profile screen doesn't need to pass anything

  const MentorProfileLayout({
    super.key,
    required this.mentor,
    required this.isEditable,
    this.onEdit,
    this.onBookSession,
    this.extraContent = const [],
  });

  // turns a DateTime into a short relative string like "2 days ago"
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'Just now';
  }

  // the sign-up form (become_mentor_screen.dart) only has a single free
  // text availability field, eg "Mon 4-6pm, Wed 2-4pm" - split it back
  // into one row per day so it displays the same way it always has
  List<(String, String)> _parseAvailability(String availability) {
    return availability
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .map((entry) {
      final spaceIndex = entry.indexOf(' ');
      if (spaceIndex == -1) return (entry, '');
      // everything before the first space is the day, the rest is the time
      return (entry.substring(0, spaceIndex), entry.substring(spaceIndex + 1));
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(mentorReviewsProvider(mentor.id));
    // live reviews for this mentor - powers both "Student Reviews" (viewing
    // someone else) and "Reviews About Me" (your own profile)
    final sessionsCount =
        ref.watch(mentorCompletedSessionsCountProvider(mentor.id)).value ?? 0;
    // how many completed sessions this mentor has run - the "N Sessions" badge

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- top card: picture on the left, name/rating on the right -----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCardBg,
              border: Border.all(color: AppTheme.darkBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // profile picture with online dot
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.tpRed, width: 3),
                        color: AppTheme.darkBg,
                      ),
                      child: Icon(Icons.person,
                          color: AppTheme.textSecondary, size: 40),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mentor.isOnline ? Colors.green : Colors.grey,
                          border:
                              Border.all(color: AppTheme.darkCardBg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // name, specialisation and rating/sessions row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mentor.name,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        mentor.specialization,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (mentor.reviewCount == 0)
                            Text(
                              'New mentor',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${mentor.rating}',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '(${mentor.reviewCount} Reviews)',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          // "N Sessions" pill - completed sessions aggregation
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.tpRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.tpRed.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '$sessionsCount Sessions',
                              style: TextStyle(
                                color: AppTheme.tpRed,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ----- specialisations (subject chips), with the edit pencil -----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Specialisations',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (isEditable)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.tpRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child:
                        Icon(Icons.edit, color: AppTheme.tpRed, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          mentor.subjects.isEmpty
              ? Text('No subjects added yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mentor.subjects
                      .map((subject) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.tpRed),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              subject,
                              style: TextStyle(
                                color: AppTheme.tpRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 24),

          // ----- about me section -----
          Text('About Me',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            mentor.bio.isEmpty ? 'No bio added yet' : mentor.bio,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),

          // ----- availability, one row per day -----
          Text('Availability',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          mentor.availability.isEmpty
              ? Text('Not set yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
              : Builder(builder: (context) {
                  final slots = _parseAvailability(mentor.availability);
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardBg,
                      border: Border.all(color: AppTheme.darkBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        for (var i = 0; i < slots.length; i++) ...[
                          if (i > 0)
                            Divider(color: AppTheme.darkBorder, height: 1),
                          _availabilityRow(slots[i].$1, slots[i].$2),
                        ],
                      ],
                    ),
                  );
                }),

          if (extraContent.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...extraContent,
          ],
          const SizedBox(height: 24),

          // ----- book session button (only when viewing someone else) -----
          if (!isEditable && onBookSession != null) ...[
            ElevatedButton.icon(
              onPressed: onBookSession,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Book a Session'),
            ),
            const SizedBox(height: 24),
          ],

          // ----- reviews section -----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditable ? 'Reviews About Me' : 'Student Reviews',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'View all',
                style: TextStyle(
                    color: AppTheme.tpRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return Text(
                  isEditable
                      ? 'No reviews yet - they will show up here once a student completes a session with you.'
                      : 'No reviews yet for this mentor.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                );
              }
              return Column(
                children:
                    reviews.map((review) => _reviewCard(review)).toList(),
              );
            },
            loading: () => Center(
                child: CircularProgressIndicator(color: AppTheme.tpRed)),
            error: (e, _) => Text('Could not load reviews',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  // one row in the availability card (day on the left, time on the right)
  Widget _availabilityRow(String day, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.access_time, color: AppTheme.tpRed, size: 16),
          const SizedBox(width: 10),
          Text(
            day,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: TextStyle(
              color: AppTheme.tpRed,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // one review card (reviewer name, stars, comment, time)
  Widget _reviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardBg,
        border: Border.all(color: AppTheme.darkBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.tpRed, width: 2),
                  color: AppTheme.darkBg,
                ),
                child: Icon(Icons.person,
                    color: AppTheme.textSecondary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.studentName,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _timeAgo(review.createdAt),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  Icons.star,
                  color: i < review.rating ? Colors.amber : AppTheme.darkBorder,
                  size: 13,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
