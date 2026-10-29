import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/student.dart';
// the student directory entry data type
import 'package:tpmentorship/providers/data_providers.dart';
// the firestore providers
import 'package:tpmentorship/screens/chat_screen.dart';
// the in-app chat thread opened by "Reach Out"
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/widgets/student_card.dart';
// the small student card widget

class StudentListScreen extends ConsumerWidget {
// a results screen listing students from the browse directory - either
// everyone, or filtered to one subject. mirrors mentor_list_screen.dart
// so mentors browsing for mentees get the same experience students get
// when browsing for mentors
  final String title;
  final String? subject;
  // null = show every student, otherwise filter by subject (arrayContains)

  const StudentListScreen({super.key, required this.title, this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = subject == null
        ? ref.watch(studentsProvider)
        : ref.watch(studentsBySubjectProvider(subject!));

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: studentsAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        color: AppTheme.textSecondary, size: 48),
                    const SizedBox(height: 12),
                    Text('No students found for this filter',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return StudentCard(
                  student: student,
                  onTap: () => showStudentDetailSheet(context, student),
                );
              },
            );
          },
          loading: () =>
              Center(child: CircularProgressIndicator(color: AppTheme.tpRed)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load students.\n$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }

}

// a lightweight bottom sheet with the student's details and a "Reach Out"
// button that opens a live in-app chat with them (see chat_screen.dart)
//
// this is a top-level function (not a method on StudentListScreen) so
// search_screen.dart's browse-students section can reuse the exact same
// sheet without duplicating it
void showStudentDetailSheet(BuildContext context, Student student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.tpRed, width: 2),
                        color: AppTheme.darkBg,
                      ),
                      child: Icon(Icons.person,
                          color: AppTheme.textSecondary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.name,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          Text(
                              '${student.course} (${student.academicYear})',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (student.bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(student.bio,
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: student.subjects
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.tpRed),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(s,
                                style: TextStyle(
                                    color: AppTheme.tpRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    // open a live chat with this student (their directory
                    // doc id is their auth uid, so it addresses a real
                    // account - see StudentService.publishToDirectory)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otherUid: student.id,
                          otherName: student.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Reach Out'),
                ),
              ],
            ),
          ),
        );
      },
    );
}
