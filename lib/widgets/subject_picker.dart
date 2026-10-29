import 'package:flutter/material.dart';
// built in ui widgets
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class SubjectPicker extends StatelessWidget {
// a row of subject chips - used by edit_profile_screen.dart ("Subjects I
// need help with") and become_mentor_screen.dart ("Subjects you can
// teach"). shows the preset TP subject codes as toggleable chips, plus
// any custom subjects the user has typed in, plus a "More..." chip that
// opens a dialog to type in a subject that isn't in the preset list
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const SubjectPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  // the subject codes offered as ready-made chips
  static const _presetSubjects = ['DAVA', 'LOMA', 'COMT', 'ECOMM', 'GSOST'];

  // prompts for free text, then adds it to the selection
  Future<void> _addCustomSubject(BuildContext context) async {
    final subject = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AddSubjectDialog(),
    );
    if (subject == null || subject.isEmpty) return;
    // uppercase to match the style of the preset subject codes
    final upper = subject.toUpperCase();
    if (selected.contains(upper)) return;
    onChanged([...selected, upper]);
  }

  @override
  Widget build(BuildContext context) {
    // anything selected that isn't one of the preset chips must have been
    // typed in through "More..." - show it as its own removable chip
    final customSubjects =
        selected.where((s) => !_presetSubjects.contains(s)).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._presetSubjects.map((subject) {
          final isSelected = selected.contains(subject);
          return FilterChip(
            label: Text(subject),
            selected: isSelected,
            onSelected: (picked) {
              onChanged(picked
                  ? [...selected, subject]
                  : selected.where((s) => s != subject).toList());
            },
            selectedColor: AppTheme.tpRed,
            backgroundColor: AppTheme.darkCardBg,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide(
                color: isSelected ? AppTheme.tpRed : AppTheme.darkBorder),
          );
        }),
        ...customSubjects.map((subject) => InputChip(
              label: Text(subject),
              onDeleted: () =>
                  onChanged(selected.where((s) => s != subject).toList()),
              backgroundColor: AppTheme.tpRed,
              deleteIconColor: Colors.white,
              labelStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              side: BorderSide(color: AppTheme.tpRed),
            )),
        ActionChip(
          avatar: Icon(Icons.add, size: 14, color: AppTheme.tpRed),
          label: const Text('More...'),
          onPressed: () => _addCustomSubject(context),
          backgroundColor: AppTheme.darkCardBg,
          labelStyle: TextStyle(
            color: AppTheme.tpRed,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          side: BorderSide(color: AppTheme.tpRed),
        ),
      ],
    );
  }
}

// the "Add a subject" dialog's content, as its own StatefulWidget so its
// TextEditingController is disposed by the framework at the right time -
// showDialog's returned future resolves as soon as Navigator.pop runs,
// which is *before* the dialog's closing animation finishes, so disposing
// the controller right after that await (as this used to) tore it down
// while the still-animating-out TextField was still using it
class _AddSubjectDialog extends StatefulWidget {
  const _AddSubjectDialog();

  @override
  State<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<_AddSubjectDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkCardBg,
      title:
          Text('Add a subject', style: TextStyle(color: AppTheme.textPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(hintText: 'e.g. UIUX'),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text('Add',
              style: TextStyle(
                  color: AppTheme.tpRed, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
