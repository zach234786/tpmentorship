import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/session.dart';
// the session data type
import 'package:tpmentorship/providers/data_providers.dart';
// the app's firestore providers
import 'package:tpmentorship/screens/leave_review_screen.dart';
// prompts the student to rate the mentor after completing a session
import 'package:tpmentorship/services/appointment_service.dart';
// for friendly error messages
import 'package:tpmentorship/services/notification_service.dart';
// reschedules or cancels the reminder notification
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages

class SessionDetailScreen extends ConsumerStatefulWidget {
// shows ONE session loaded by id from Firestore (the select-one of CRUD)
// and holds the UPDATE (reschedule, mark completed) and DELETE (cancel)
// actions for that session
  final String sessionId;
  // the firestore document id of the session to show

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Session? _session;
  // the loaded session, null while loading
  bool _loading = true;
  String? _loadError;
  // holds the error message if loading failed

  @override
  void initState() {
    super.initState();
    _loadSession();
    // fetch the session as soon as the screen opens
  }

  // SELECT ONE - loads this single session from Firestore by its id
  Future<void> _loadSession() async {
    try {
      final session = await ref
          .read(appointmentServiceProvider)
          .getSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        if (session == null) _loadError = 'This session no longer exists.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = AppointmentService.friendlyError(e);
      });
    }
  }

  // turns a date into a string like "5 Jul 2026"
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // turns a TimeOfDay into a string like "3:00 PM"
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // UPDATE (reschedule) - asks for a new date and time then saves them
  Future<void> _reschedule() async {
    final session = _session!;
    final now = DateTime.now();

    // pick the new date
    final newDate = await showDatePicker(
      context: context,
      initialDate: session.date.isAfter(now) ? session.date : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (newDate == null || !mounted) return;
    // user closed the picker, change nothing

    // pick the new time
    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(session.date),
    );
    if (newTime == null || !mounted) return;

    // combine the new date and time into one DateTime
    final newDateTime = DateTime(
      newDate.year, newDate.month, newDate.day,
      newTime.hour, newTime.minute,
    );

    // copyWith keeps every other field and only changes date/time
    final updated = session.copyWith(
      date: newDateTime,
      time: _formatTime(newTime),
      status: 'Pending',
      // a moved session needs the mentor to confirm again
    );

    try {
      await ref.read(appointmentServiceProvider).updateSession(updated);
      // UPDATE in firestore

      // move the reminder notification to the new time too
      await NotificationService.instance.scheduleSessionReminder(
        sessionId: updated.id,
        title: updated.title,
        mentorName: updated.mentorName,
        sessionTime: newDateTime,
        notificationsEnabled:
            ref.read(userProfileProvider).value?.notificationsEnabled ?? true,
      );

      if (!mounted) return;
      setState(() => _session = updated);
      // update whats on screen right away
      showAppSnackBar(context, 'Session rescheduled!', success: true);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppointmentService.friendlyError(e));
    }
  }

  // UPDATE (status) - marks the session as completed, then asks the
  // student to rate the mentor
  Future<void> _markCompleted() async {
    final updated = _session!.copyWith(status: 'Completed');
    try {
      await ref.read(appointmentServiceProvider).updateSession(updated);
      if (!mounted) return;
      setState(() => _session = updated);
      showAppSnackBar(context, 'Session marked as completed!',
          success: true);

      // prompt for a review right away - Navigator.push (not pop) so
      // coming back from the review screen returns here, now showing
      // the completed state with no more cancel/reschedule buttons
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LeaveReviewScreen(session: updated),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppointmentService.friendlyError(e));
    }
  }

  // UPDATE (status) - cancels the session by changing its status rather
  // than deleting it outright, so it still shows up under the "Cancelled"
  // filter on My Sessions as part of the student's history
  Future<void> _cancelSession() async {
    // confirm first since this affects a real booking (feedback: AlertDialog)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCardBg,
        title: Text('Cancel Session',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Cancel "${_session!.title}" with ${_session!.mentorName}?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep it',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Cancel Session',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // user changed their mind

    final updated = _session!.copyWith(status: 'Cancelled');
    try {
      await ref.read(appointmentServiceProvider).updateSession(updated);
      // UPDATE in firestore - the booking record is kept, just marked cancelled

      // remove the reminder notification for this session too
      await NotificationService.instance.cancelSessionReminder(_session!.id);

      if (!mounted) return;
      setState(() => _session = updated);
      showAppSnackBar(context, 'Session cancelled', success: true);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppointmentService.friendlyError(e));
    }
  }

  // DELETE - permanently removes an already-cancelled session from
  // Firestore. this is the real delete operation in the CRUD set; the
  // everyday "Cancel Session" action above is an update, not a delete,
  // so cancelled sessions still appear in the student's history until
  // they choose to clear them out here
  Future<void> _deletePermanently() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCardBg,
        title: Text('Delete Session',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Permanently remove this cancelled session from your history? '
          'This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep it',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(appointmentServiceProvider).cancelSession(_session!.id);
      // DELETE from firestore
      if (!mounted) return;
      showAppSnackBar(context, 'Session deleted', success: true);
      Navigator.pop(context);
      // leave the detail screen since the session is gone
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppointmentService.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(title: const Text('Session Details')),
      body: SafeArea(
        child: _loading
            // still fetching from firestore
            ? Center(
                child: CircularProgressIndicator(color: AppTheme.tpRed))
            : _loadError != null
                // fetch failed or session is gone
                ? Center(
                    child: Text(_loadError!,
                        style: TextStyle(
                            color: AppTheme.textSecondary)))
                : _buildDetails(),
      ),
    );
  }

  // the actual session info once its loaded
  Widget _buildDetails() {
    final session = _session!;
    final isCompleted = session.status == 'Completed';
    final isCancelled = session.status == 'Cancelled';
    // active sessions (Pending/Confirmed) can be rescheduled, completed or
    // cancelled; completed sessions are locked history; cancelled sessions
    // can only be permanently deleted from here
    final isActive = !isCompleted && !isCancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- main info card -----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCardBg,
              border: Border.all(color: AppTheme.darkBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title and status pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.tpRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppTheme.tpRed.withValues(alpha: 0.5)),
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
                const SizedBox(height: 16),
                // each detail as an icon + label row
                _detailRow(Icons.person, 'Mentor', session.mentorName),
                _detailRow(Icons.book, 'Subject', session.subject),
                _detailRow(Icons.calendar_today, 'Date',
                    _formatDate(session.date)),
                _detailRow(Icons.access_time, 'Time', session.time),
                if (session.notes.isNotEmpty)
                  _detailRow(Icons.notes, 'Notes', session.notes),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ----- action buttons -----
          // completed and cancelled sessions are history - only active
          // (Pending/Confirmed) sessions can be rescheduled or completed
          if (isActive) ...[
            ElevatedButton.icon(
              onPressed: _reschedule,
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Reschedule'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _markCompleted,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark as Completed'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _cancelSession,
              icon: Icon(Icons.cancel_outlined,
                  color: AppTheme.tpRed, size: 18),
              label: Text(
                'Cancel Session',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          // completed sessions are locked - no cancel/delete button at all
          if (isCancelled)
            TextButton.icon(
              onPressed: _deletePermanently,
              icon: Icon(Icons.delete_forever,
                  color: AppTheme.tpRed, size: 18),
              label: Text(
                'Delete Permanently',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  // one row of session info (icon, grey label, white value)
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.tpRed, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
