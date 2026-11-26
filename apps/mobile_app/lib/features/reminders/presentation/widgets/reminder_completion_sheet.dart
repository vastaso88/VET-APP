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
import '../../../notifications/presentation/exact_alarm_permission.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../application/reminder_completion_service.dart';
import '../../data/reminders_repository.dart';
import '../../domain/reminder_category.dart';
import '../../domain/reminder_completion.dart';
import 'reminder_category_picker.dart';
import 'reminder_postpone_sheet.dart';
import '../../../../shared/widgets/app_field.dart';

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
  const ReminderPostponed(this.until);

  /// The moment chosen in "Quando vuoi che te lo ricordi?".
  final DateTime until;
}

class ReminderNotDone extends ReminderAnswer {
  const ReminderNotDone();
}

/// Asks "Fatto? Registralo nello storico" for [reminder] and carries out the
/// answer (see [ReminderCompletionService]). Returns true when the reminder was
/// dealt with (done or "non fatto"), false when postponed (to the moment asked
/// for by [askPostponeMoment]) or dismissed.
///
/// Used by the reminders list and detail, the pet's Promemoria tab, the app's
/// own question when a reminder falls due and the notification tap, so all of
/// them behave the same.
Future<bool> askToCompleteReminder(
  BuildContext context,
  ReminderEntry reminder, {
  ReminderCompletionService? service,
  DateTime Function() now = DateTime.now,
  Future<bool> Function(ReminderEntry reminder)? alertsCanRing,
}) async {
  final answer = await showModalBottomSheet<ReminderAnswer>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
    ),
    builder: (_) => _CompletionSheet(
      reminder: reminder,
      askPostpone: (sheetContext) => askPostponeMoment(
        sheetContext,
        reminder,
        now: now,
        alertsCanRing: alertsCanRing,
      ),
    ),
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
      case ReminderPostponed(:final until):
        await completion.postpone(reminder, until);
        message = l10n.remindersPostponedTo(postponeMomentLabel(until, now()));
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
  if (answer is ReminderPostponed) {
    // An hour was just chosen. Waited for, so that the next question of
    // ReminderCompletionPrompter does not open over this window.
    await maybeAskExactAlarmPermission(AppRouter.navigatorKey.currentContext);
  }
  return handled;
}

class _CompletionSheet extends StatefulWidget {
  const _CompletionSheet({required this.reminder, required this.askPostpone});

  final ReminderEntry reminder;
  final Future<DateTime?> Function(BuildContext context) askPostpone;

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

  /// "Rimanda": closing the choice without choosing leaves this sheet as it was.
  Future<void> _postpone() async {
    final until = await widget.askPostpone(context);
    if (until == null || !mounted) return;
    Navigator.of(context).pop(ReminderPostponed(until));
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
                AppField(
                  label: l10n.remindersDoneFieldTitle,
                  child: TextField(controller: _title, decoration: _decoration()),
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: l10n.remindersDoneFieldDate,
                  child: TypedDateField(
                    controller: _date,
                    onPick: _pickDate,
                    pickIcon: Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.primary),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
                    decoration: _decoration(hint: l10n.remindersDatePlaceholder, error: _dateError),
                    onChanged: (_) {
                      if (_dateError != null) setState(() => _dateError = null);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: l10n.remindersDoneFieldNotes,
                  child: TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(),
                  ),
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
                      onPressed: _postpone,
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
      );
}
