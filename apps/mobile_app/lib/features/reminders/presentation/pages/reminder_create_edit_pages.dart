import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/l10n.dart';
import '../../../notifications/presentation/exact_alarm_permission.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/widgets/pet_picker.dart';
import '../../data/reminders_repository.dart';
import '../widgets/reminder_form.dart';
import '../widgets/reminder_page_parts.dart';

/// Opens the new-reminder form for the right animal: a reminder needs one (the
/// server refuses it otherwise), and the form has no animal field. One animal:
/// it is used; several: the owner picks; none: they are told to add one first.
Future<void> openReminderCreate(
  BuildContext context, {
  required List<PetProfile> pets,
  RemindersRepository? repository,
}) async {
  if (pets.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.remindersNeedPetFirst)));
    return;
  }
  final pet = pets.length == 1 ? pets.single : await showPetPicker(context, pets);
  if (pet == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ReminderCreatePage(petName: pet.name, repository: repository),
    ),
  );
}

class ReminderCreatePage extends StatefulWidget {
  const ReminderCreatePage({super.key, this.petName = '', this.repository});

  final String petName;

  /// Only for tests; the page uses its own repository otherwise.
  final RemindersRepository? repository;

  @override
  State<ReminderCreatePage> createState() => _ReminderCreatePageState();
}

class _ReminderCreatePageState extends State<ReminderCreatePage> {
  late final RemindersRepository _repository = widget.repository ?? RemindersRepository();
  bool _saving = false;

  Future<void> _save(ReminderEntry reminder) async {
    if (_saving) return;
    _saving = true;
    // The form stays open until the save has gone through: when it fails
    // (no network) everything the owner typed is still there to retry.
    if (!await saveReminderKeepingForm(_repository, reminder)) {
      _saving = false;
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    // A reminder that can never ring is worse than none: ask for the
    // notification permission now if the phone has not allowed it yet, then
    // (the first time) for the access that makes it ring at the exact hour.
    unawaited(askReminderPermissions(reminder));
  }

  @override
  Widget build(BuildContext context) {
    return ReminderPageShell(
      title: widget.petName.isEmpty
          ? context.l10n.remindersCreateTitle
          : context.l10n.remindersCreateTitleForPet(widget.petName),
      subtitle: context.l10n.remindersCreateSubtitle,
      petName: widget.petName,
      child: ReminderForm(
        petName: widget.petName,
        initial: null,
        onSave: _save,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class ReminderEditPage extends StatefulWidget {
  const ReminderEditPage({super.key, this.reminder, this.repository});

  final ReminderEntry? reminder;

  /// Only for tests; the page uses its own repository otherwise.
  final RemindersRepository? repository;

  @override
  State<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends State<ReminderEditPage> {
  late final RemindersRepository _repository = widget.repository ?? RemindersRepository();
  bool _saving = false;

  Future<void> _save(ReminderEntry reminder) async {
    if (_saving) return;
    _saving = true;
    if (!await saveReminderKeepingForm(_repository, reminder)) {
      _saving = false;
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(reminder);
    unawaited(askReminderPermissions(reminder));
  }

  @override
  Widget build(BuildContext context) {
    return ReminderPageShell(
      title: context.l10n.remindersEditTitle,
      subtitle: context.l10n.remindersEditSubtitle,
      petName: widget.reminder?.petName,
      child: ReminderForm(
        petName: widget.reminder?.petName ?? '',
        initial: widget.reminder,
        onSave: _save,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
