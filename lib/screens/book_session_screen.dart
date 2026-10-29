import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/session.dart';
// the data types
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// the app's providers
import 'package:tpmentorship/services/appointment_service.dart';
// for friendly error messages
import 'package:tpmentorship/services/notification_service.dart';
// schedules the session reminder notification
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages

class BookSessionScreen extends ConsumerStatefulWidget {
// the CREATE part of CRUD - a validated form that inserts a new
// appointment document into Firestore
  final Mentor? mentor;
  // the mentor being booked. can be null when opened from the sessions
  // screen, in which case a mentor dropdown is shown instead

  const BookSessionScreen({super.key, this.mentor});

  @override
  ConsumerState<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends ConsumerState<BookSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  // lets us run every field's validator at once on submit
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  // grab what the user types

  Mentor? _selectedMentor;
  // which mentor the session is with
  String? _selectedSubject;
  // which subject the session covers
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  // when the session happens
  bool _saving = false;
  // true while the booking is being written to firestore,
  // used to show a loading spinner on the button (feedback)

  @override
  void initState() {
    super.initState();
    _selectedMentor = widget.mentor;
    // if a mentor was passed in, preselect them
  }

  @override
  void dispose() {
  // free the controllers memory to avoid leaks
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // turns a TimeOfDay into a string like "3:00 PM" for saving
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // turns a date into a string like "5 Jul 2026" for display
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // opens the calendar popup to pick the session date
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      // cant book a session in the past
      lastDate: now.add(const Duration(days: 90)),
      // bookings only up to 3 months ahead
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // opens the clock popup to pick the session time
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 15, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // checks the form then inserts the session into Firestore
  Future<void> _submit() async {
    // run every validator, stop if any field is invalid
    if (!_formKey.currentState!.validate()) return;

    // date and time are picked with popups not typed, so check them manually
    if (_selectedDate == null || _selectedTime == null) {
      showAppSnackBar(context, 'Please pick a date and time');
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    // should never happen because this screen is behind the auth gate

    setState(() => _saving = true);
    // show the loading spinner on the button

    // combine the picked date and picked time into one DateTime
    final sessionDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final session = Session(
      id: '',
      // firestore generates the real id on insert
      title: _titleController.text.trim(),
      mentorName: _selectedMentor!.name,
      date: sessionDateTime,
      time: _formatTime(_selectedTime!),
      status: 'Pending',
      // every new booking starts as pending
      studentId: user.uid,
      // saved now so the mentor's request list can name who booked without
      // looking the profile up. profile first, then the auth display name,
      // then a neutral label - never a raw uid
      studentName: ref.read(userProfileProvider).value?.fullName.trim().isNotEmpty ==
              true
          ? ref.read(userProfileProvider).value!.fullName.trim()
          : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'A student'),
      // travels with the session so the mentor's list can sort premium
      // requests first - they cannot read the student's profile to check
      studentIsPremium:
          ref.read(userProfileProvider).value?.isPremium ?? false,
      mentorId: _selectedMentor!.id,
      subject: _selectedSubject!,
      notes: _notesController.text.trim(),
    );

    try {
      final sessionId =
          await ref.read(appointmentServiceProvider).bookSession(session);
      // INSERT into firestore

      // schedule the reminder notification 15 minutes before the session
      // (does nothing on web, see NotificationService)
      await NotificationService.instance.scheduleSessionReminder(
        sessionId: sessionId,
        title: session.title,
        mentorName: session.mentorName,
        sessionTime: sessionDateTime,
        notificationsEnabled:
            ref.read(userProfileProvider).value?.notificationsEnabled ?? true,
      );

      if (!mounted) return;
      showAppSnackBar(context, 'Session booked with ${session.mentorName}!',
          success: true);
      Navigator.pop(context);
      // go back - the sessions list updates by itself because its a stream
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppointmentService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
      // stop the loading spinner whether it worked or not
    }
  }

  @override
  Widget build(BuildContext context) {
    // all mentors, used for the dropdown when no mentor was passed in
    final mentorsAsync = ref.watch(mentorsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(title: const Text('Book a Session')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----- mentor picker -----
                Text('Mentor',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (widget.mentor != null)
                  // mentor already chosen, just show who
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardBg,
                      border: Border.all(color: AppTheme.darkBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: AppTheme.tpRed),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.mentor!.name}  (${widget.mentor!.specialization})',
                          style:
                              TextStyle(color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  )
                else
                  // no mentor passed in, show a dropdown of all mentors
                  mentorsAsync.when(
                    data: (mentors) => DropdownButtonFormField<Mentor>(
                      initialValue: _selectedMentor,
                      dropdownColor: AppTheme.darkCardBg,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'Select a mentor'),
                      items: mentors
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('${m.name} (${m.specialization})'),
                              ))
                          .toList(),
                      onChanged: (mentor) => setState(() {
                        _selectedMentor = mentor;
                        _selectedSubject = null;
                        // reset subject because each mentor teaches
                        // different subjects
                      }),
                      validator: (value) =>
                          value == null ? 'Please select a mentor' : null,
                    ),
                    loading: () => Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.tpRed)),
                    error: (e, _) => Text('Could not load mentors: $e',
                        style:
                            TextStyle(color: AppTheme.textSecondary)),
                  ),
                const SizedBox(height: 16),

                // ----- session title -----
                Text('Session Title',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Web Development Basics'),
                  validator: (value) {
                    // must not be empty and must be a sensible length
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a session title';
                    }
                    if (value.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ----- subject dropdown (only the mentor's subjects) -----
                Text('Subject',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  // Key forces the dropdown to rebuild when the mentor
                  // changes so a stale subject cant stay selected
                  key: ValueKey(_selectedMentor?.id),
                  initialValue: _selectedSubject,
                  dropdownColor: AppTheme.darkCardBg,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration:
                      const InputDecoration(hintText: 'Select a subject'),
                  items: (_selectedMentor?.subjects ?? [])
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (subject) =>
                      setState(() => _selectedSubject = subject),
                  validator: (value) =>
                      value == null ? 'Please select a subject' : null,
                ),
                const SizedBox(height: 16),

                // ----- date and time pickers side by side -----
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.calendar_today,
                        label: _selectedDate == null
                            ? 'Pick date'
                            : _formatDate(_selectedDate!),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.access_time,
                        label: _selectedTime == null
                            ? 'Pick time'
                            : _formatTime(_selectedTime!),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ----- optional notes -----
                Text('Notes (optional)',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Anything the mentor should know?'),
                  // no validator - notes are optional
                ),
                const SizedBox(height: 24),

                // ----- submit button with loading spinner -----
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  // disabled while saving so it cant be tapped twice
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Book Session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
// a tappable box that opens the date or time picker and
// shows what has been picked so far
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkCardBg,
          border: Border.all(color: AppTheme.darkBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.tpRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
