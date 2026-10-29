import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/constants/tp_schools.dart';
// the School -> Diploma cascade data
import 'package:tpmentorship/models/user_profile.dart';
// the user profile data type
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// the app's providers
import 'package:tpmentorship/services/bio_writer_service.dart';
// drafts a bio from the school/diploma/year/subjects already entered
import 'package:tpmentorship/services/notification_service.dart';
// requests the OS notification permission when onboarding opts in
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/widgets/subject_picker.dart';
// the subject chips + "More..." custom subject input

class EditProfileScreen extends ConsumerStatefulWidget {
// a validated form for editing the user's Firestore profile
// the subjects picked here are what the AI matching feature uses
  final UserProfile profile;
  // the current profile values to pre-fill the form with
  final bool isOnboarding;
  // true only for the first-time setup push from main.dart - locks
  // navigation, requires Subjects, and shows the notifications toggle.
  // false (default) for the regular Settings > Edit Profile flow, which
  // stays cancellable exactly as before

  const EditProfileScreen({
    super.key,
    required this.profile,
    this.isOnboarding = false,
  });

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  // lets us run every field's validator at once on submit

  late final TextEditingController _nameController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _bioController;
  // pre-filled with the current profile values in initState

  String? _academicYear;
  String? _school;
  String? _diploma;
  late List<String> _selectedSubjects;
  // which subject chips are picked

  bool _saving = false;
  // true while saving, shows the button spinner
  bool _notificationsEnabled = true;
  // only shown/used when widget.isOnboarding is true

  bool _generatingBio = false;
  // true while the bio request is in flight, shows the button spinner

  String? _lastGeneratedBio;
  // what the generator last produced. while the box still holds exactly
  // this, tapping again regenerates freely; once the user edits a
  // character it stops matching and the next tap confirms first
  bool get _bioIsAiGenerated =>
      _lastGeneratedBio != null && _bioController.text == _lastGeneratedBio;

  static const _years = ['Year 1', 'Year 2', 'Year 3'];

  @override
  void initState() {
    super.initState();
    // start every field with what the profile currently says
    _nameController = TextEditingController(text: widget.profile.fullName);
    _studentIdController =
        TextEditingController(text: widget.profile.studentId);
    _bioController = TextEditingController(text: widget.profile.bio);
    _academicYear = widget.profile.academicYear.isEmpty
        ? null
        : widget.profile.academicYear;

    _school = widget.profile.school.isEmpty ? null : widget.profile.school;
    if (_school == null && widget.profile.course.isNotEmpty) {
      // older profiles saved a free-text course with no school - try to
      // recognise it so the dropdowns come back pre-filled
      _school = schoolFor(widget.profile.course);
    }
    _diploma = widget.profile.course.isEmpty ? null : widget.profile.course;
    // drop a diploma that doesn't belong to the matched school, or isn't
    // valid for the matched year (e.g. a stale Common Programme value on a
    // profile that has since moved past Year 1)
    if (_school == null ||
        _diploma == null ||
        !diplomasFor(_school!, _academicYear ?? 'Year 1').contains(_diploma)) {
      _diploma = null;
    }

    _selectedSubjects = List.from(widget.profile.subjects);
  }

  @override
  void dispose() {
  // free the controllers memory to avoid leaks
    _nameController.dispose();
    _studentIdController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // checks the form then saves the changes to Firestore
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // stop if any field is invalid
    if (widget.isOnboarding && _selectedSubjects.isEmpty) {
      showAppSnackBar(context, 'Please select at least one subject');
      return;
    }

    setState(() => _saving = true);
    try {
      final fullName = _nameController.text.trim();
      final bio = _bioController.text.trim();
      await ref.read(userServiceProvider).updateProfile(
            uid: widget.profile.uid,
            fullName: fullName,
            studentId: _studentIdController.text.trim().toUpperCase(),
            course: _diploma!,
            school: _school!,
            academicYear: _academicYear ?? '',
            bio: bio,
            subjects: _selectedSubjects,
          );

      if (widget.isOnboarding) {
        await ref
            .read(userServiceProvider)
            .updateNotificationsEnabled(widget.profile.uid, _notificationsEnabled);
        if (_notificationsEnabled) {
          await NotificationService.instance.requestPermission();
        }
      }

      // keep the "browse students" directory in sync too, so mentors
      // looking for mentees can find real registered students (not just
      // the seed data) - see StudentService.publishToDirectory
      if (_selectedSubjects.isNotEmpty) {
        await ref.read(studentServiceProvider).publishToDirectory(
              uid: widget.profile.uid,
              name: fullName,
              course: _diploma!,
              academicYear: _academicYear ?? '',
              subjects: _selectedSubjects,
              bio: bio,
            );
      } else {
        // no subjects set - nothing to browse them for
        await ref.read(studentServiceProvider).removeFromDirectory(widget.profile.uid);
      }

      // keep the auth display name in sync so the greeting matches
      final newName = _nameController.text.trim();
      if (newName != widget.profile.fullName) {
        await ref.read(authServiceProvider).updateDisplayName(newName);
      }

      if (!mounted) return;
      showAppSnackBar(context, 'Profile updated!', success: true);
      Navigator.pop(context);
      // profile screen refreshes by itself - its watching the stream
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not save your profile. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // drafts a bio and drops it into the field. the user edits it afterwards
  // - this is a starting point, not a final answer
  Future<void> _generateBio() async {
    if (_diploma == null) {
      // nothing useful to describe yet. the button stays enabled rather
      // than greying out because a disabled button has no way to explain
      // itself on mobile, where tooltips need a long-press
      showAppSnackBar(context, 'Pick your School and Diploma first');
      return;
    }

    if (_bioController.text.trim().isNotEmpty && !_bioIsAiGenerated) {
      // the user typed this themselves - do not throw it away silently
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCardBg,
          title: Text('Replace your bio?',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Your current bio will be overwritten.',
              style: TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true) return;
      if (!mounted) return;
    }

    setState(() => _generatingBio = true);
    try {
      final bio = await ref.read(bioWriterServiceProvider).writeBio(
            school: _school ?? '',
            diploma: _diploma!,
            academicYear: _academicYear ?? '',
            subjects: _selectedSubjects,
          );

      if (!mounted) return;
      setState(() {
        _bioController.text = bio.text;
        _lastGeneratedBio = bio.text;
      });
      showAppSnackBar(
        context,
        bio.source == BioSource.groq
            ? 'Bio written by Groq'
            : 'Bio built offline - edit it to make it yours',
        success: true,
      );
    } finally {
      // writeBio never throws, but the finally means an unexpected error
      // still cannot strand the spinner
      if (mounted) setState(() => _generatingBio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isOnboarding,
      child: Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          title: const Text('Edit Profile'),
          automaticallyImplyLeading: !widget.isOnboarding,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----- role (read only - changes automatically when you
                  // sign up as a mentor from the Mentor Profile tab) -----
                  _label('Role'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.tpRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.tpRed.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      widget.profile.role,
                      style: TextStyle(
                        color: AppTheme.tpRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ----- full name -----
                  _label('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.name,
                    decoration:
                        const InputDecoration(hintText: 'Your full name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ----- student id -----
                  _label('Student ID'),
                  TextFormField(
                    controller: _studentIdController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.text,
                    decoration:
                        const InputDecoration(hintText: 'e.g. 2501587F'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your student ID';
                      }
                      // TP student ids are 7 digits then a letter
                      final pattern = RegExp(r'^\d{7}[A-Za-z]$');
                      if (!pattern.hasMatch(value.trim())) {
                        return 'Student ID should be 7 digits then a letter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ----- academic year dropdown -----
                  // first of the three cascading fields: the year decides
                  // whether the school's Common Programme is still offered
                  _label('Academic Year'),
                  DropdownButtonFormField<String>(
                    initialValue: _academicYear,
                    dropdownColor: AppTheme.darkCardBg,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration:
                        const InputDecoration(hintText: 'Select your year'),
                    items: _years
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (year) => setState(() {
                      _academicYear = year;
                      if (_school != null &&
                          _diploma != null &&
                          !diplomasFor(_school!, year ?? '')
                              .contains(_diploma)) {
                        _diploma = null;
                      }
                    }),
                    validator: (value) =>
                        value == null ? 'Please select your year' : null,
                  ),
                  const SizedBox(height: 16),

                  // ----- school -----
                  _label('School'),
                  DropdownButtonFormField<String>(
                    initialValue: _school,
                    isExpanded: true,
                    // without this the field sizes to its longest item's
                    // intrinsic width (e.g. "School of Humanities & Social
                    // Sciences") and overflows the screen instead of
                    // wrapping to the available width
                    dropdownColor: AppTheme.darkCardBg,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                        hintText: 'Select your school'),
                    items: tpSchools.keys
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (school) => setState(() {
                      _school = school;
                      if (_diploma != null &&
                          !diplomasFor(school ?? '', _academicYear ?? '')
                              .contains(_diploma)) {
                        _diploma = null;
                      }
                    }),
                    validator: (value) =>
                        value == null ? 'Please select your school' : null,
                  ),
                  const SizedBox(height: 16),

                  // ----- diploma (filtered by school + year) -----
                  _label('Diploma'),
                  DropdownButtonFormField<String>(
                    initialValue: _diploma,
                    isExpanded: true,
                    // same overflow fix as School - diploma names run even
                    // longer (e.g. "Diploma in Architectural Technology &
                    // Building Services")
                    dropdownColor: AppTheme.darkCardBg,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: _school == null
                          ? 'Select a school first'
                          : 'Select a diploma',
                    ),
                    items: _school == null
                        ? const []
                        : diplomasFor(_school!, _academicYear ?? '')
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child:
                                      Text(d, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                    onChanged: _school == null
                        ? null
                        : (diploma) => setState(() => _diploma = diploma),
                    validator: (value) =>
                        value == null ? 'Please select your diploma' : null,
                  ),
                  const SizedBox(height: 16),

                  // ----- subjects the student needs help with -----
                  // above the bio because the bio generator uses them, and
                  // "what do you need help with" reads naturally before
                  // "describe yourself"
                  _label('Subjects I need help with'),
                  Text(
                    'The AI uses these to recommend your best-fit mentors',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SubjectPicker(
                    selected: _selectedSubjects,
                    onChanged: (subjects) =>
                        setState(() => _selectedSubjects = subjects),
                  ),
                  const SizedBox(height: 16),

                  // ----- bio -----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Bio'),
                      TextButton.icon(
                        onPressed: _generatingBio ? null : _generateBio,
                        icon: _generatingBio
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                            _generatingBio ? 'Writing…' : 'Generate with AI'),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _bioController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                    maxLength: 150,
                    // the counter under the box is another form of feedback
                    decoration: InputDecoration(
                      hintText: 'Tell mentors a little about yourself',
                      counterStyle:
                          TextStyle(color: AppTheme.textSecondary),
                    ),
                    // bio is optional - no validator
                  ),
                  const SizedBox(height: 24),

                  // ----- notifications opt-in (onboarding only) -----
                  if (widget.isOnboarding) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppTheme.tpRed,
                      value: _notificationsEnabled,
                      onChanged: (value) =>
                          setState(() => _notificationsEnabled = value),
                      title: Text('Enable session reminder notifications',
                          style: TextStyle(color: AppTheme.textPrimary)),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ----- save button with loading spinner -----
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // small bold heading above each field
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
