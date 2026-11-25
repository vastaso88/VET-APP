import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/formatters/date_input_formatter.dart';
import '../../../../../shared/widgets/typed_date_field.dart';
import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../l10n/regional_defaults.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../data/reminders_repository.dart';
import '../../domain/clock_time.dart';
import '../../domain/reminder_category.dart';
import '../widgets/reminder_category_picker.dart';
import 'reminder_page_parts.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_field.dart';

/// Width, before the text size, of a date and a time side by side.
const _dateAndTimeRow = 272.0;

/// Shared create/edit form: a required kind selector (spot/recurring/
/// course) drives which fields show below it, since each kind needs
/// different data (a single date; a next date + interval; a start date +
/// duration). Used by both [ReminderCreatePage] and [ReminderEditPage].
class ReminderForm extends StatefulWidget {
  const ReminderForm({super.key, 
    required this.petName,
    required this.initial,
    required this.onSave,
    required this.onCancel,
  });

  final String petName;
  final ReminderEntry? initial;
  final ValueChanged<ReminderEntry> onSave;
  final VoidCallback onCancel;

  @override
  State<ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController =
      TextEditingController(text: widget.initial?.title ?? '');
  late final _noteController =
      TextEditingController(text: widget.initial?.note ?? '');

  late EventKind _kind = widget.initial?.kind ?? EventKind.spot;

  // The category follows the title and kind (a guess) until the owner picks
  // one; a saved reminder keeps its own. Only what suits the animal is offered.
  late final List<ReminderCategory> _offeredCategories = () {
    final pet = PetDemoStore.instance.byName(widget.initial?.petName ?? widget.petName);
    return ReminderCategory.offeredFor(pet?.species, breed: pet?.breed);
  }();
  late ReminderCategory _category = _initialCategory();
  late String? _subtype = widget.initial?.subtype;
  late bool _categoryChosen = widget.initial?.category != null;

  ReminderCategory _initialCategory() {
    final initial = widget.initial;
    return _usable(initial?.effectiveCategory ?? ReminderCategory.other);
  }

  /// [category] when it suits the animal, else the neutral one.
  ReminderCategory _usable(ReminderCategory category) =>
      _offeredCategories.contains(category) ? category : ReminderCategory.other;

  void _followGuess() {
    if (_categoryChosen) return;
    final guess = _usable(legacyReminderCategory(title: _titleController.text, kind: _kind));
    if (guess == _category) return;
    setState(() {
      _category = guess;
      if (!guess.subtypes.contains(_subtype)) _subtype = null;
    });
  }
  late final _dateController = TextEditingController(
    text: formatDateForInput(_initialDate()),
  );
  // The time of day lives apart from the typed date: changing the date keeps it.
  late TimeOfDay _time = TimeOfDay.fromDateTime(_initialDate());
  late final List<String> _doseTimes = [...?widget.initial?.doseTimes];
  late IntervalUnit _intervalUnit =
      widget.initial?.intervalUnit ?? IntervalUnit.days;
  late int _intervalValue = widget.initial?.intervalValue ?? 30;
  bool _customInterval = false;
  late final _customIntervalController = TextEditingController(
      text: (widget.initial?.intervalValue ?? 30).toString());
  late int _courseDuration = widget.initial?.courseDurationDays ?? 5;

  late RecurrenceEnd _recurrenceEnd =
      widget.initial?.recurrenceEnd ?? RecurrenceEnd.never;
  late int _occurrenceCount = widget.initial?.occurrenceCount ?? 6;
  late final _recurrenceEndDateController = TextEditingController(
    text: formatDateForInput(
      widget.initial?.recurrenceEndDate ?? DateTime.now().add(const Duration(days: 365)),
    ),
  );
  late final _occurrenceCountController = TextEditingController(
      text: (widget.initial?.occurrenceCount ?? 6).toString());

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    _recurrenceEndDateController.dispose();
    _customIntervalController.dispose();
    _occurrenceCountController.dispose();
    super.dispose();
  }

  /// Tomorrow at 09:00 for a new reminder. A reminder saved before the time
  /// could be picked sits at midnight: it is shown (and notified) at 09:00.
  DateTime _initialDate() {
    final initial = widget.initial?.dueAt;
    if (initial == null) {
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day + 1, 9);
    }
    if (initial.hour == 0 && initial.minute == 0) {
      return DateTime(initial.year, initial.month, initial.day, 9);
    }
    return initial;
  }

  /// Closing a picker hands the focus back to the field that had it, which
  /// reopened the keyboard over the Save button: no field keeps it.
  void _dropFocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _pickDate() async {
    _dropFocus();
    final initialDate = parseStrictDate(_dateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      // A new reminder starts today or later; one being edited may keep a past date.
      firstDate: widget.initial == null
          ? DateTime.now()
          : DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      // Typing already happens in the field next to this icon (with its
      // gg/mm/aaaa slashes); the dialog only needs to offer the calendar.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _dateController.text = formatDateForInput(picked));
    }
  }

  Future<void> _pickTime() async {
    _dropFocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _addDoseTime() async {
    _dropFocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _doseTimes.isEmpty
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 20, minute: 0),
      helpText: context.l10n.remindersDosePickerHelp,
    );
    if (picked == null) return;
    final time = formatClockTime(picked.hour, picked.minute);
    if (_doseTimes.contains(time)) return;
    setState(() => _doseTimes
      ..add(time)
      ..sort());
  }

  Future<void> _pickRecurrenceEndDate() async {
    _dropFocus();
    final initialDate = parseStrictDate(_recurrenceEndDateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _recurrenceEndDateController.text = formatDateForInput(picked));
    }
  }

  String? _validateDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return context.l10n.remindersDateRequired;
    if (parseStrictDate(raw) == null) return appDateInputText(context.l10n.remindersDateInvalid);
    return null;
  }

  /// The first (or only) date of a reminder. A NEW reminder cannot start in the past:
  /// the day is checked against today, and a spot or recurring one against the
  /// chosen time too (today at an hour already gone). Editing an existing one is
  /// not checked: an overdue reminder stays editable, and a recurring one moves
  /// forward on its own. Dates are the phone's own, so time zones need no care.
  String? _validateStartDate(String? value) {
    final invalid = _validateDate(value);
    if (invalid != null) return invalid;
    if (widget.initial != null) return null;
    final day = parseStrictDate(value!.trim())!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day.isBefore(today)) return context.l10n.remindersDatePast;
    if (_kind != EventKind.course &&
        _combine(day).isBefore(now.subtract(const Duration(minutes: 1)))) {
      return context.l10n.remindersTimePast;
    }
    return null;
  }

  /// The typed day at the chosen time of day.
  DateTime _combine(DateTime day) =>
      DateTime(day.year, day.month, day.day, _time.hour, _time.minute);

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final reminder = ReminderEntry(
      id: widget.initial?.id ??
          'promemoria-${DateTime.now().microsecondsSinceEpoch}',
      petName: widget.initial?.petName ?? widget.petName,
      title: _titleController.text.trim(),
      kind: _kind,
      dueAt: _combine(parseStrictDate(_dateController.text.trim())!),
      note: _noteController.text.trim(),
      intervalUnit: _kind == EventKind.recurring ? _intervalUnit : null,
      intervalValue: _kind == EventKind.recurring ? _intervalValue : null,
      recurrenceEnd: _kind == EventKind.recurring ? _recurrenceEnd : null,
      occurrenceCount: _kind == EventKind.recurring &&
              _recurrenceEnd == RecurrenceEnd.afterOccurrences
          ? _occurrenceCount
          : null,
      recurrenceEndDate:
          _kind == EventKind.recurring && _recurrenceEnd == RecurrenceEnd.onDate
              ? parseStrictDate(_recurrenceEndDateController.text.trim())
              : null,
      courseDurationDays: _kind == EventKind.course ? _courseDuration : null,
      doseTimes: _kind == EventKind.course ? List.unmodifiable(_doseTimes) : const [],
      isDone: widget.initial?.isDone ?? false,
      category: _category,
      subtype: _category.subtypes.contains(_subtype) ? _subtype : null,
    );

    widget.onSave(reminder);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      // Mirrors the pet form: a date typo shows its error as soon as the
      // owner types it, not only after they hit Salva.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AppCard(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(context.l10n.remindersFormKind),
            _KindSelector(
                value: _kind,
                onChanged: (kind) {
                  setState(() => _kind = kind);
                  _followGuess();
                }),
            const SizedBox(height: AppSpacing.lg),
            AppField(
              label: context.l10n.remindersFormTitleLabel,
              child: _TextField(
                controller: _titleController,
                hintText: widget.petName.isEmpty
                    ? context.l10n.remindersFormTitleHint
                    : context.l10n.remindersFormTitleHintWithPet(widget.petName),
                onChanged: (_) => _followGuess(),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? context.l10n.remindersTitleRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ReminderCategoryPicker(
              offered: _offeredCategories,
              category: _category,
              subtype: _subtype,
              onCategory: (category) => setState(() {
                _categoryChosen = true;
                _category = category;
                if (!category.subtypes.contains(_subtype)) _subtype = null;
              }),
              onSubtype: (subtype) => setState(() => _subtype = subtype),
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, box) {
                final date = _DatePickerField(
                  label: switch (_kind) {
                    EventKind.spot => context.l10n.remindersFieldDate,
                    EventKind.recurring => context.l10n.remindersFieldNextDue,
                    EventKind.course => context.l10n.remindersFieldStartDate,
                  },
                  controller: _dateController,
                  onPick: _pickDate,
                  validator: _validateStartDate,
                );
                // A course is notified at its dose times instead.
                if (_kind == EventKind.course) return date;
                final time = AppField(
                  label: context.l10n.remindersFieldTime,
                  child: PickerField(
                    icon: Icons.schedule_rounded,
                    text: formatClockTime(_time.hour, _time.minute),
                    onTap: _pickTime,
                    // Narrow, next to the date: no arrow to squeeze the value.
                    trailing: null,
                  ),
                );
                // Side by side only where the whole date and the whole time fit.
                if (box.maxWidth < MediaQuery.textScalerOf(context).scale(_dateAndTimeRow)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [date, const SizedBox(height: AppSpacing.md), time],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: date),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(flex: 2, child: time),
                  ],
                );
              },
            ),
            if (_kind == EventKind.recurring) ...[
              const SizedBox(height: AppSpacing.lg),
              FieldLabel(context.l10n.remindersRepeats),
              _IntervalPresetChips(
                selectedUnit: _intervalUnit,
                selectedValue: _intervalValue,
                isCustom: _customInterval,
                onPreset: (unit, value) => setState(() {
                  _customInterval = false;
                  _intervalUnit = unit;
                  _intervalValue = value;
                }),
                onCustom: () => setState(() => _customInterval = true),
              ),
              if (_customInterval) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _TextField(
                        controller: _customIntervalController,
                        hintText: context.l10n.remindersCustomNumberHint,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed > 0) {
                            setState(() => _intervalValue = parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _UnitToggle(
                        value: _intervalUnit,
                        onChanged: (unit) =>
                            setState(() => _intervalUnit = unit),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FieldLabel(context.l10n.remindersRecurrenceEndLabel),
              _RecurrenceEndChips(
                value: _recurrenceEnd,
                onChanged: (end) => setState(() => _recurrenceEnd = end),
              ),
              if (_recurrenceEnd == RecurrenceEnd.afterOccurrences) ...[
                const SizedBox(height: AppSpacing.md),
                _TextField(
                  controller: _occurrenceCountController,
                  hintText: context.l10n.remindersOccurrenceCountHint,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setState(() => _occurrenceCount = parsed);
                    }
                  },
                ),
              ],
              if (_recurrenceEnd == RecurrenceEnd.onDate) ...[
                const SizedBox(height: AppSpacing.md),
                _DatePickerField(
                  label: context.l10n.remindersLastDate,
                  controller: _recurrenceEndDateController,
                  onPick: _pickRecurrenceEndDate,
                  validator: _validateDate,
                ),
              ],
            ],
            if (_kind == EventKind.course) ...[
              const SizedBox(height: AppSpacing.lg),
              FieldLabel(context.l10n.remindersCourseDuration),
              _DurationStepper(
                days: _courseDuration,
                onChanged: (days) => setState(() => _courseDuration = days),
              ),
              const SizedBox(height: AppSpacing.lg),
              FieldLabel(context.l10n.remindersDoseTimes),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final time in _doseTimes)
                    InputChip(
                      label: Text(time),
                      onDeleted: () => setState(() => _doseTimes.remove(time)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.l10n.remindersAddDoseTime),
                    onPressed: _addDoseTime,
                  ),
                ],
              ),
              if (_doseTimes.isEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.remindersNoDoseTimesNote,
                  style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            AppField(
              label: context.l10n.remindersFormNote,
              child: _TextField(
                controller: _noteController,
                hintText: context.l10n.remindersFormNoteHint,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                    child: FilledButton(
                        onPressed: _save, child: Text(context.l10n.commonSave))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                      onPressed: widget.onCancel, child: Text(context.l10n.commonCancel)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A `SegmentedButton` here used to force all three options into equal
/// thirds regardless of label length — at narrow widths "Ricorrente" had no
/// room and wrapped one character per line. This lays out icon-over-label
/// instead, each option sized by [Expanded] with the label capped to one
/// line, so it never wraps no matter how tight the screen is.
class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.value, required this.onChanged});

  final EventKind value;
  final ValueChanged<EventKind> onChanged;

  static const _options = <(EventKind, IconData)>[
    (EventKind.spot, Icons.event_outlined),
    (EventKind.recurring, Icons.autorenew_rounded),
    (EventKind.course, Icons.medication_outlined),
  ];

  static String _label(BuildContext context, EventKind kind) => switch (kind) {
        EventKind.spot => context.l10n.remindersKindEvent,
        EventKind.recurring => context.l10n.remindersKindOptionRecurring,
        EventKind.course => context.l10n.remindersKindOptionCourse,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _KindOption(
              icon: _options[i].$2,
              label: _label(context, _options[i].$1),
              selected: value == _options[i].$1,
              onTap: () => onChanged(_options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color:
                    selected ? AppColors.onPrimary : AppColors.secondaryText),
            const SizedBox(height: 4),
            // The same height for the three, whatever each name takes.
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(14) * 1.4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.onPrimary : AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A typed date field (`gg/mm/aaaa` or the country's order): digits format themselves as the owner types
/// (see [TypedDateField]), and the trailing calendar icon still opens the
/// native picker and fills the field for those who'd rather tap than type.
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.controller,
    required this.onPick,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final FutureOr<void> Function() onPick;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return AppField(
      label: label,
      child: TypedDateField(
        controller: controller,
        validator: validator,
        onPick: onPick,
        pickIcon: const Icon(Icons.calendar_today_outlined,
            size: 18, color: AppColors.primary),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
        decoration: InputDecoration(
          hintText: appDateInputText(context.l10n.remindersDatePlaceholder),
        ),
      ),
    );
  }
}

class _IntervalPresetChips extends StatelessWidget {
  const _IntervalPresetChips({
    required this.selectedUnit,
    required this.selectedValue,
    required this.isCustom,
    required this.onPreset,
    required this.onCustom,
  });

  final IntervalUnit selectedUnit;
  final int selectedValue;
  final bool isCustom;
  final void Function(IntervalUnit unit, int value) onPreset;
  final VoidCallback onCustom;

  bool _isSelected(IntervalUnit unit, int value) =>
      !isCustom && selectedUnit == unit && selectedValue == value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _presetChip(context.l10n.remindersPreset7Days, _isSelected(IntervalUnit.days, 7),
            () => onPreset(IntervalUnit.days, 7)),
        _presetChip(context.l10n.remindersPreset30Days, _isSelected(IntervalUnit.days, 30),
            () => onPreset(IntervalUnit.days, 30)),
        _presetChip(context.l10n.remindersPreset6Months, _isSelected(IntervalUnit.months, 6),
            () => onPreset(IntervalUnit.months, 6)),
        _presetChip(context.l10n.remindersPreset12Months, _isSelected(IntervalUnit.months, 12),
            () => onPreset(IntervalUnit.months, 12)),
        _presetChip(context.l10n.remindersPresetCustom, isCustom, onCustom),
      ],
    );
  }

  Widget _presetChip(String label, bool selected, VoidCallback onTap) {
    return ReminderKindChip(label: label, selected: selected, onTap: onTap);
  }
}

class _RecurrenceEndChips extends StatelessWidget {
  const _RecurrenceEndChips({required this.value, required this.onChanged});

  final RecurrenceEnd value;
  final ValueChanged<RecurrenceEnd> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ReminderKindChip(
          label: context.l10n.remindersEndAlways,
          selected: value == RecurrenceEnd.never,
          onTap: () => onChanged(RecurrenceEnd.never),
        ),
        ReminderKindChip(
          label: context.l10n.remindersEndAfterN,
          selected: value == RecurrenceEnd.afterOccurrences,
          onTap: () => onChanged(RecurrenceEnd.afterOccurrences),
        ),
        ReminderKindChip(
          label: context.l10n.remindersEndUntil,
          selected: value == RecurrenceEnd.onDate,
          onTap: () => onChanged(RecurrenceEnd.onDate),
        ),
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.value, required this.onChanged});

  final IntervalUnit value;
  final ValueChanged<IntervalUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<IntervalUnit>(
      segments: [
        ButtonSegment(value: IntervalUnit.days, label: Text(context.l10n.remindersUnitDays)),
        ButtonSegment(value: IntervalUnit.months, label: Text(context.l10n.remindersUnitMonths)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

/// Course length in days: typed directly (long courses) or nudged with
/// −/+. Part of the reminder [Form], so an empty or out-of-range number
/// blocks "Salva" with a message under the field.
class _DurationStepper extends StatefulWidget {
  const _DurationStepper({required this.days, required this.onChanged});

  static const minDays = 1;
  static const maxDays = 365;

  final int days;
  final ValueChanged<int> onChanged;

  @override
  State<_DurationStepper> createState() => _DurationStepperState();
}

class _DurationStepperState extends State<_DurationStepper> {
  late final _controller = TextEditingController(text: '${widget.days}');

  @override
  void didUpdateWidget(_DurationStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // −/+ changed the value: show it, unless the field already says so
    // (typing "1" on the way to "12" must not be rewritten).
    if (int.tryParse(_controller.text) != widget.days) {
      _controller.text = '${widget.days}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: context.l10n.remindersOneDayLess,
          onPressed:
              days > _DurationStepper.minDays ? () => widget.onChanged(days - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.secondaryStrong,
        ),
        Expanded(
          child: TextFormField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null &&
                  parsed >= _DurationStepper.minDays &&
                  parsed <= _DurationStepper.maxDays) {
                widget.onChanged(parsed);
              }
            },
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              if (parsed == null ||
                  parsed < _DurationStepper.minDays ||
                  parsed > _DurationStepper.maxDays) {
                return context.l10n.remindersDurationRange(
                  _DurationStepper.minDays,
                  _DurationStepper.maxDays,
                );
              }
              return null;
            },
            decoration: InputDecoration(
              suffixText: context.l10n.remindersDurationUnit(days),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.remindersOneDayMore,
          onPressed:
              days < _DurationStepper.maxDays ? () => widget.onChanged(days + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.secondaryStrong,
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    this.hintText,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
      decoration: InputDecoration(
        hintText: hintText,
      ),
    );
  }
}
