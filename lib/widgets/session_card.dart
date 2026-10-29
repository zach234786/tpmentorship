import 'package:flutter/material.dart';
// built in ui widgets
import 'package:tpmentorship/models/session.dart';
// the session data (title, mentor, date, etc)
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class SessionCard extends StatelessWidget {
// a card showing one booked session, reused in the home and profile screens
  final Session session;
  // the session to show on this card
  final VoidCallback? onTap;
  // what to run when the card is tapped

  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

  IconData _sessionIcon() {
  // picks an icon based on words in the session title
    final t = session.title.toLowerCase();
    if (t.contains('web') || t.contains('development')) return Icons.code;
    if (t.contains('data') || t.contains('analytics')) return Icons.bar_chart;
    if (t.contains('security') || t.contains('cyber')) return Icons.security;
    if (t.contains('ai') || t.contains('machine')) return Icons.psychology;
    return Icons.school;
    // fallback icon if nothing matches
  }

  String _formattedDate() {
  // turns the date into a readable string like "5 Jul 2026"
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${session.date.day} ${months[session.date.month - 1]} ${session.date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // makes the whole card tappable
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // topic icon on the left
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.tpRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.tpRed.withValues(alpha: 0.4)),
              ),
              child: Icon(_sessionIcon(), color: AppTheme.tpRed, size: 24),
            ),
            const SizedBox(width: 12),
            // title, mentor name, date and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // "with <mentor name>" line
                  RichText(
                    text: TextSpan(
                      text: 'with ',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      children: [
                        TextSpan(
                          text: session.mentorName,
                          style: TextStyle(
                            color: AppTheme.tpRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // date and time row
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formattedDate(),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        session.time,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // status pill on the right (eg pending, confirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.tpRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.tpRed.withValues(alpha: 0.5)),
              ),
              child: Text(
                session.status,
                style: TextStyle(
                  color: AppTheme.tpRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
