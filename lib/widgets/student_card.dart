import 'package:flutter/material.dart';
// built in ui widgets
import 'package:tpmentorship/models/student.dart';
// the student directory entry data type
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class StudentCard extends StatelessWidget {
// a small tappable card showing one student looking for mentoring help
// mirrors MentorCard's look so both browse lists feel like the same family
  final Student student;
  final VoidCallback? onTap;

  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.tpRed, width: 3),
                color: AppTheme.darkBg,
              ),
              child:
                  Icon(Icons.person, color: AppTheme.textSecondary, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              student.name,
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
            Text(
              student.academicYear,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 4),
            // the first subject they need help with, as a small pill
            if (student.subjects.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.tpRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  student.subjects.length > 1
                      ? '${student.subjects.first} +${student.subjects.length - 1}'
                      : student.subjects.first,
                  style: TextStyle(
                    color: AppTheme.tpRed,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
