import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/formatters/date_input_formatter.dart';
import '../../../../shared/widgets/typed_date_field.dart';
import '../../../medical_records/data/medical_records_repository.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../application/reminder_completion_service.dart';
import '../../data/reminders_repository.dart';
import '../../domain/reminder_category.dart';
import '../../domain/reminder_completion.dart';
import 'reminder_category_picker.dart';

/// What the owner answered to "Fatto?".
sealed class ReminderAnswer {
  const ReminderAnswer();
}

class ReminderDone extends ReminderAnswer {
  const ReminderDone({
    required this.category,
    required this.eventDate,
    required this.title,
    this.subtype,
    this.notes = '',
  });

  final ReminderCategory category;
  final DateTime eventDate;
  final String title;
  final String? subtype;
  final String notes;
}

class ReminderPostponed extends ReminderAnswer {
  const ReminderPostponed();
}

class ReminderNotDone extends ReminderAnswer {
  const ReminderNotDone();
}

/// Asks "Fatto? Registralo nello storico" for [reminder] and carries out the
/// answer (see [ReminderCompletionService]). Returns true when the reminder was
/// dealt with (done or "non fatto"), false when postponed or dismissed.
///
/// Used by the reminders list and detail, the pet's Promemoria tab, the app's
/// own question when a reminder falls due and the notification tap, so all of
/// them behave the same.
Future<bool> askToCompleteReminder(
  BuildContext context,
  ReminderEntry reminder, {
  ReminderCompletionService? service,
}) async {
  final answer = await showModalBottomSheet<ReminderAnswer>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
    ),
    builder: (_) => _CompletionSheet(reminder: reminder),
  );
  if (answer == null) return false;

  final completion = service ?? ReminderCompletionService();
  final l10n = appL10n;
  String? message;
  var handled = true;
  try {
    switch (answer) {
      case ReminderDone():
        final record = await completion.confirmDone(
          reminder,
          category: answer.category,
          eventDate: answer.eventDate,
          title: answer.title,
          subtype: answer.subtype,
          notes: answer.notes,
        );
        message = record == null
            ? l10n.remindersDoneMarked
            : l10n.remindersDoneRecorded(reminder.petName);
      case ReminderNotDone():
        await completion.dismiss(reminder);
        message = l10n.remindersDoneDismissed;
      case ReminderPostponed():
        await completion.postpone(reminder);
        message = l10n.remindersDonePostponed;
        handled = false;
    }
  } on MedicalRecordSaveException catch (error) {
    message = error.message;
    handled = false;
  } on ReminderSyncException catch (error) {
    message = error.message;
    handled = false;
  }
  AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  return handled;
}

class _CompletionSheet extends StatefulWidget {
  const _CompletionSheet({required this.reminder});

  final ReminderEntry reminder;

  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet> {
  late final List<ReminderCategory> _offered;
  late ReminderCategory _category;
  String? _subtype;
  late final TextEditingController _title = TextEditingController(text: widget.reminder.title);
  late final TextEditingController _date = TextEditingController(
    text: formatDateForInput(defaultEventDay(widget.reminder, DateTime.now())),
  );
  final TextEditingController _notes = TextEditingController();
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final pet = PetDemoStore.instance.byName(widget.reminder.petName);
    _offered = ReminderCategory.offeredFor(pet?.species, breed: pet?.breed);
    final current = widget.reminder.effectiveCategory;
    // A category that makes no sense for this animal (a vaccine for a fish)
    // is not offered: start from the first clinical one that is.
    _category = _offered.contains(current) ? current : _offered.first;
    final saved = widget.reminder.subtype;
    _subtype = saved != null && _category.subtypes.contains(saved) ? saved : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = parseStrictDate(_date.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        _date.text = formatDateForInput(picked);
        _dateError = null;
      });
    }
  }

  void _confirm() {
    final date = parseStrictDate(_date.text.trim());
    if (_category.isClinical && date == null) {
      setState(() => _dateError = context.l10n.remindersDateInvalid);
      return;
    }
    Navigator.of(context).pop(
      ReminderDone(
        category: _category,
        eventDate: date ?? DateTime.now(),
        title: _title.text.trim(),
        subtype: _subtype,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reminder = widget.reminder;
    final clinical = _category.isClinical;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.remindersDoneTitle, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              Text(
                reminder.petName.isEmpty ? reminder.title : '${reminder.title} · ${reminder.petName}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                clinical
                    ? l10n.remindersDoneRecordHint(reminder.petName)
                    : l10n.remindersDonePlainHint,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              ReminderCategoryPicker(
                offered: _offered,
                category: _category,
                subtype: _subtype,
                showSubtypes: clinical,
                onCategory: (category) => setState(() {
                  _category = category;
                  if (!category.subtypes.contains(_subtype)) _subtype = null;
                }),
                onSubtype: (subtype) => setState(() => _subtype = subtype),
              ),
              if (clinical) ...[
                const SizedBox(height: AppSpacing.md),
                _Label(l10n.remindersDoneFieldTitle),
                TextField(controller: _title, decoration: _decoration()),
                const SizedBox(height: AppSpacing.md),
                _Label(l10n.remindersDoneFieldDate),
                TypedDateField(
                  controller: _date,
                  onPick: _pickDate,
                  pickIcon: const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.primary),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
                  decoration: _decoration(hint: l10n.remindersDatePlaceholder, error: _dateError),
                  onChanged: (_) {
                    if (_dateError != null) setState(() => _dateError = null);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _Label(l10n.remindersDoneFieldNotes),
                TextField(
                  controller: _notes,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
                  child: Text(clinical
                      ? l10n.remindersDoneConfirmRecord
                      : l10n.remindersDoneConfirmPlain),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(const ReminderPostponed()),
                      child: Text(l10n.remindersDonePostpone),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(const ReminderNotDone()),
                      child: Text(l10n.remindersDoneNotDone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint, String? error}) => InputDecoration(
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text, style: AppTextStyles.caption),
      );
}
