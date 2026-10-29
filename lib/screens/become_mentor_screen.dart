import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/mentor.dart';
// the mentor data type
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// the app's providers
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/widgets/subject_picker.dart';
// the subject chips + "More..." custom subject input

class BecomeMentorScreen extends ConsumerStatefulWidget {
// one form used for BOTH:
//   - signing up as a mentor for the first time (existingMentor: null)
//   - editing your existing mentor listing (existingMentor: your Mentor)
// signing up creates a new mentor document (id == your auth uid) and
// upgrades your user role to "Student & Mentor"; editing just updates
// the existing document
  final Mentor? existingMentor;

  const BecomeMentorScreen({super.key, this.existingMentor});

  @override
  ConsumerState<BecomeMentorScreen> createState() =>
      _BecomeMentorScreenState();
}

class _BecomeMentorScreenState extends ConsumerState<BecomeMentorScreen> {
  final _formKey = GlobalKey<FormState>();
  // lets us run every field's validator at once on submit
  late final TextEditingController _bioController;
  late final TextEditingController _availabilityController;

  String? _specialization;
  late List<String> _selectedSubjects;
  bool _saving = false;

  // the same specialisation options used elsewhere in the app
  // (search screen's "browse by subject" areas)
  static const _specializations = [
    'Development',
    'Data',
    'Cybersecurity',
    'AI & Machine Learning',
  ];

  bool get _isEditing => widget.existingMentor != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMentor;
    // pre-fill with the current mentor doc's values when editing,
    // otherwise start blank
    _bioController = TextEditingController(text: existing?.bio ?? '');
    _availabilityController =
        TextEditingController(text: existing?.availability ?? '');
    _specialization = existing?.specialization;
    _selectedSubjects = List.from(existing?.subjects ?? const []);
  }

  @override
  void dispose() {
    // free the controllers memory to avoid leaks
    _bioController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // stop if any field is invalid
    if (_specialization == null) {
      showAppSnackBar(context, 'Please pick a specialisation');
      return;
    }
    if (_selectedSubjects.isEmpty) {
      showAppSnackBar(context, 'Please select at least one subject');
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    // should never happen - this screen is behind the auth gate

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        // UPDATE - save changes to the existing mentor document
        await ref.read(mentorServiceProvider).updateMentorProfile(
              uid: user.uid,
              specialization: _specialization!,
              subjects: _selectedSubjects,
              availability: _availabilityController.text.trim(),
              bio: _bioController.text.trim(),
            );
      } else {
        // INSERT - create a brand new mentor document and become a mentor
        final name = ref.read(authServiceProvider).displayName;
        await ref.read(mentorServiceProvider).becomeMentor(
              uid: user.uid,
              name: name.isEmpty ? 'TP Mentor' : name,
              specialization: _specialization!,
              subjects: _selectedSubjects,
              availability: _availabilityController.text.trim(),
              bio: _bioController.text.trim(),
            );
        // role becomes "Student & Mentor" now that they have a mentor listing
        await ref.read(userServiceProvider).setRole(user.uid, 'Student & Mentor');
      }

      if (!mounted) return;
      showAppSnackBar(
          context,
          _isEditing ? 'Mentor profile updated!' : 'You are now a mentor!',
          success: true);
      Navigator.pop(context);
      // the mentor profile screen refreshes by itself - it watches the stream
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Mentor Profile' : 'Sign up as a Mentor'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  Text(
                    'Tell students what you can help with',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                ],

                // ----- specialisation -----
                _label('Specialisation'),
                DropdownButtonFormField<String>(
                  initialValue: _specialization,
                  dropdownColor: AppTheme.darkCardBg,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                      hintText: 'Select your specialisation'),
                  items: _specializations
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _specialization = value),
                  validator: (value) =>
                      value == null ? 'Please pick a specialisation' : null,
                ),
                const SizedBox(height: 16),

                // ----- subjects -----
                _label('Subjects you can teach'),
                SubjectPicker(
                  selected: _selectedSubjects,
                  onChanged: (subjects) =>
                      setState(() => _selectedSubjects = subjects),
                ),
                const SizedBox(height: 16),

                // ----- availability -----
                _label('Availability'),
                TextFormField(
                  controller: _availabilityController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Mon 4-6pm, Wed 2-4pm'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please share when you are available';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ----- about / bio -----
                _label('About You'),
                TextFormField(
                  controller: _bioController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  maxLength: 250,
                  decoration: const InputDecoration(
                      hintText: 'What should students know about you?'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please write a short bio';
                    }
                    if (value.trim().length < 10) {
                      return 'Bio must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ----- submit button with loading spinner -----
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Sign Up as a Mentor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
