import 'package:flutter/material.dart';
// built in ui widgets
import 'package:tpmentorship/models/mentor.dart';
// the mentor data (name, rating, etc)
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class MentorCard extends StatelessWidget {
// a small tappable card showing one mentor, reused in the home and search screens
  final Mentor mentor;
  // the mentor to show on this card
  final VoidCallback? onTap;
  // what to run when the card is tapped
  final bool isSelf;
  // true when this card is the logged in user's own mentor listing -
  // shows a "You" badge so search results are clear it's their own profile

  const MentorCard({
    super.key,
    required this.mentor,
    this.onTap,
    this.isSelf = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // makes the whole card tappable
      child: Stack(
        // expand (not the Stack default of loose) so the card still fills
        // and centers within its slot exactly like before the "You" badge
        // was added - loose sizing made it shrink to content and top-align
        fit: StackFit.expand,
        children: [
          _card(),
          if (isSelf)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.tpRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.tpRed, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.darkCardBg,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // profile picture with an online dot in the corner
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.tpRed, width: 3),
                    color: AppTheme.darkBg,
                  ),
                  child: Icon(Icons.person, color: AppTheme.textSecondary, size: 28),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mentor.isOnline ? Colors.green : Colors.grey,
                      // green if online, grey if offline
                      border: Border.all(color: AppTheme.darkCardBg, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // mentor name
            Text(
              mentor.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            // what the mentor specialises in
            Text(
              mentor.specialization,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            // star rating and number of reviews
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${mentor.rating}',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Text(
                  ' (${mentor.reviewCount})',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
