import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/review.dart';
import 'package:tpmentorship/models/session.dart';
// the data types
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// the app's providers
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages

class LeaveReviewScreen extends ConsumerStatefulWidget {
// shown right after a student marks a session as Completed - lets them
// rate the mentor (1-5 stars) and leave a short comment
// this is optional (there is a Skip button), not a hard block
  final Session session;
  // the just-completed session being reviewed

  const LeaveReviewScreen({super.key, required this.session});

  @override
  ConsumerState<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends ConsumerState<LeaveReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showAppSnackBar(context, 'Please select a star rating');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final studentName = ref.read(authServiceProvider).displayName;
      final review = Review(
        id: '',
        // firestore generates the real id on insert
        mentorId: widget.session.mentorId,
        studentId: user.uid,
        studentName: studentName.isEmpty ? 'A student' : studentName,
        sessionId: widget.session.id,
        rating: _rating,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(reviewServiceProvider).addReview(review);
      // INSERT the review + recompute the mentor's average rating

      if (!mounted) return;
      showAppSnackBar(context, 'Thanks for your feedback!', success: true);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not submit your review. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Leave a Review'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text('Skip',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was your session with ${widget.session.mentorName}?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.session.subject,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // ----- star rating selector -----
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starValue = i + 1;
                      return IconButton(
                        iconSize: 40,
                        onPressed: () => setState(() => _rating = starValue),
                        icon: Icon(
                          _rating >= starValue ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // ----- comment -----
                Text('Comment',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: const InputDecoration(
                      hintText: 'Share a short snippet about your session'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please write a short comment';
                    }
                    if (value.trim().length < 5) {
                      return 'Comment must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Submit Review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
