import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/responsive.dart';
import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../settings/data/layout_settings_store.dart';
import '../../data/reminders_repository.dart';
import '../../domain/reminder_calendar.dart';
import '../../domain/reminder_presentation.dart';

enum _ViewMode { list, calendar }

/// Collapses spot+recurring into one "Eventi" filter, alongside Cicli —
/// simpler than the underlying 3-way [EventKind] split, which read as too
/// granular for a filter strip.
enum _KindFilterOption {
  all,
  events,
  courses;

  bool matches(EventKind kind) => switch (this) {
        _KindFilterOption.all => true,
        _KindFilterOption.events => kind == EventKind.spot || kind == EventKind.recurring,
        _KindFilterOption.courses => kind == EventKind.course,
      };
}

class RemindersListPage extends StatefulWidget {
  const RemindersListPage({super.key});

  @override
  State<RemindersListPage> createState() => _RemindersListPageState();
}

class _RemindersListPageState extends State<RemindersListPage> {
  final RemindersRepository _repository = RemindersRepository();

  late Future<List<ReminderEntry>> _remindersFuture;
  _KindFilterOption _kindFilter = _KindFilterOption.all;
  String? _petFilter;
  _ViewMode _viewMode = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    _remindersFuture = _repository.loadReminders();
  }

  Future<void> _reload() async {
    setState(() {
      _remindersFuture = _repository.loadReminders();
    });
    await _remindersFuture;
  }

  void _openCreate() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReminderCreatePage()),
      ).then((_) {
        if (mounted) {
          _reload();
        }
      }),
    );
  }

  void _openDetail(ReminderEntry reminder) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReminderDetailPage(reminder: reminder)),
      ).then((_) {
        if (mounted) {
          _reload();
        }
      }),
    );
  }

  Future<void> _markDone(ReminderEntry reminder) async {
    await _repository.saveReminder(reminder.copyWith(isDone: true));
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LayoutSettingsStore.instance,
      builder: (context, _) {
        final compact = LayoutSettingsStore.instance.settings.listDensity == ListDensity.compact;

        return _Shell(
      title: 'Promemoria',
      subtitle: 'Vaccini, trattamenti e visite da tenere sotto controllo.',
      actionLabel: 'Crea',
      onAction: _openCreate,
      child: FutureBuilder<List<ReminderEntry>>(
        future: _remindersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingPanel(
              title: 'Caricamento promemoria',
              body: 'Sto leggendo date, ricorrenze e note del proprietario.',
            );
          }

          if (snapshot.hasError) {
            return _StatePanel(
              label: 'Errore sync',
              title: 'Sincronizzazione promemoria fallita.',
              body: 'La sorgente demo e ancora disponibile. Riprova quando la rete torna su.',
              icon: Icons.wifi_off_outlined,
              actionLabel: 'Riprova',
              onAction: () => unawaited(_reload()),
            );
          }

          final all = (snapshot.data ?? const <ReminderEntry>[])
              .where((reminder) => !reminder.isDone)
              .toList(growable: false);

          if (all.isEmpty) {
            return _StatePanel(
              label: 'Nessun promemoria',
              title: 'La lista dei promemoria e vuota.',
              body: 'Crea il primo promemoria per vaccino o trattamento e resta in carreggiata.',
              icon: Icons.event_note_outlined,
              actionLabel: 'Crea promemoria',
              onAction: _openCreate,
            );
          }

          final pets = PetDemoStore.instance.list();
          final filtered = all
              .where((r) => _kindFilter.matches(r.kind) && (_petFilter == null || r.petName == _petFilter))
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ViewModeToggle(
                value: _viewMode,
                onChanged: (mode) => setState(() => _viewMode = mode),
              ),
              const SizedBox(height: AppSpacing.lg),
              _KindFilterBar(
                selected: _kindFilter,
                onSelect: (kind) => setState(() => _kindFilter = kind),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PetFilterBar(
                pets: pets,
                selected: _petFilter,
                onSelect: (petName) => setState(() => _petFilter = petName),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_viewMode == _ViewMode.calendar)
                _MonthCalendarView(
                  reminders: filtered,
                  onOpenReminder: _openDetail,
                  onMarkDone: _markDone,
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'Nessun promemoria per questi filtri.',
                    style: AppTextStyles.bodySmall,
                  ),
                )
              else
                ...filtered.asMap().entries.expand(
                  (entry) {
                    final index = entry.key;
                    final reminder = entry.value;
                    return <Widget>[
                      _ReminderTile(
                        reminder: reminder,
                        compact: compact,
                        onTap: () => _openDetail(reminder),
                        onMarkDone: reminder.kind == EventKind.spot
                            ? () => _markDone(reminder)
                            : null,
                      ),
                      if (index != filtered.length - 1) const SizedBox(height: AppSpacing.sm),
                    ];
                  },
                ),
            ],
          );
        },
      ),
        );
      },
    );
  }
}

class _KindFilterBar extends StatelessWidget {
  const _KindFilterBar({required this.selected, required this.onSelect});

  final _KindFilterOption selected;
  final ValueChanged<_KindFilterOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _KindChip(
            label: 'Tutti',
            selected: selected == _KindFilterOption.all,
            onTap: () => onSelect(_KindFilterOption.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          _KindChip(
            label: 'Eventi',
            icon: Icons.event_outlined,
            selected: selected == _KindFilterOption.events,
            onTap: () => onSelect(_KindFilterOption.events),
          ),
          const SizedBox(width: AppSpacing.sm),
          _KindChip(
            label: 'Cicli',
            icon: Icons.medication_outlined,
            selected: selected == _KindFilterOption.courses,
            onTap: () => onSelect(_KindFilterOption.courses),
          ),
        ],
      ),
    );
  }
}

class _PetFilterBar extends StatelessWidget {
  const _PetFilterBar({required this.pets, required this.selected, required this.onSelect});

  final List<PetProfile> pets;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _KindChip(label: 'Tutti', selected: selected == null, onTap: () => onSelect(null)),
          for (final pet in pets) ...[
            const SizedBox(width: AppSpacing.sm),
            _PetChip(pet: pet, selected: selected == pet.name, onTap: () => onSelect(pet.name)),
          ],
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip({required this.pet, required this.selected, required this.onTap});

  final PetProfile pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: pet.identityColor),
              ),
              const SizedBox(width: 6),
              Text(
                pet.name,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? AppColors.onPrimary : AppColors.text),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.value, required this.onChanged});

  final _ViewMode value;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ViewMode>(
      segments: const [
        ButtonSegment(
          value: _ViewMode.list,
          icon: Icon(Icons.view_list_rounded, size: 16),
          label: Text('Lista'),
        ),
        ButtonSegment(
          value: _ViewMode.calendar,
          icon: Icon(Icons.calendar_month_rounded, size: 16),
          label: Text('Calendario'),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Classic monthly calendar, reached from "Vedi tutti": bigger and more
/// detailed than the Home week-strip, with a day's reminders listed below
/// the grid — tapping one reuses the same detail page (edit/delete/mark
/// done) as the list view.
class _MonthCalendarView extends StatefulWidget {
  const _MonthCalendarView({
    required this.reminders,
    required this.onOpenReminder,
    required this.onMarkDone,
  });

  final List<ReminderEntry> reminders;
  final ValueChanged<ReminderEntry> onOpenReminder;
  final ValueChanged<ReminderEntry> onMarkDone;

  @override
  State<_MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends State<_MonthCalendarView> {
  late DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay = DateTime.now();

  static const _monthNames = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];
  static const _weekdayNames = [
    'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica',
  ];
  static const _mondayFirstLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
  static const _sundayFirstLabels = ['D', 'L', 'M', 'M', 'G', 'V', 'S'];

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = _selectedDay != null && isSameDay(_selectedDay!, day) ? null : day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekStartDay = LayoutSettingsStore.instance.settings.weekStartDay;
    final pets = PetDemoStore.instance.list();
    final labels = weekStartDay == WeekStartDay.monday ? _mondayFirstLabels : _sundayFirstLabels;

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final firstOffset = weekStartDay == WeekStartDay.monday
        ? firstOfMonth.weekday - 1
        : firstOfMonth.weekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: firstOffset));
    final daysInMonth = DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    final totalWeeks = ((firstOffset + daysInMonth) / 7).ceil();

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final selectedDay = _selectedDay;

    final selectedReminders = selectedDay == null
        ? const <ReminderEntry>[]
        : (widget.reminders.where((r) => reminderActiveOnDay(r, selectedDay)).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt)));

    return DashboardSurfaceCard(
      backgroundColor: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var week = 0; week < totalWeeks; week++) ...[
            if (week != 0) const SizedBox(height: 2),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  Builder(
                    builder: (context) {
                      final day = gridStart.add(Duration(days: week * 7 + i));
                      return Expanded(
                        child: _MonthDayCell(
                          day: day,
                          inMonth: day.month == _visibleMonth.month,
                          isToday: isSameDay(day, startOfToday),
                          isSelected: selectedDay != null && isSameDay(day, selectedDay),
                          markers: markersForDay(widget.reminders, pets, day),
                          onTap: () => _selectDay(day),
                        ),
                      );
                    },
                  ),
                  if (i != 6) const SizedBox(width: 2),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (selectedDay != null) ...[
            Text(
              _selectedDayLabel(selectedDay),
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (selectedReminders.isEmpty)
              Text('Nessuna attività in questo giorno.', style: AppTextStyles.bodySmall)
            else
              ...selectedReminders.asMap().entries.expand((entry) {
                final index = entry.key;
                final reminder = entry.value;
                return <Widget>[
                  _ReminderTile(
                    reminder: reminder,
                    compact: true,
                    onTap: () => widget.onOpenReminder(reminder),
                    onMarkDone: reminder.kind == EventKind.spot
                        ? () => widget.onMarkDone(reminder)
                        : null,
                  ),
                  if (index != selectedReminders.length - 1) const SizedBox(height: AppSpacing.sm),
                ];
              }),
          ],
        ],
      ),
    );
  }

  String _selectedDayLabel(DateTime day) {
    if (isSameDay(day, DateTime.now())) return 'Oggi';
    return '${_weekdayNames[day.weekday - 1]} ${day.day} ${_monthNames[day.month - 1]}';
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.markers,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<DayMarker> markers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? AppColors.primary
        : (isToday ? AppColors.accentSoft : Colors.transparent);
    final foreground = isSelected
        ? AppColors.onPrimary
        : (inMonth ? AppColors.text : AppColors.mutedText.withValues(alpha: 0.5));
    final shown = markers.take(3).toList();
    final extra = markers.length - shown.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: isToday && !isSelected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.day}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 12,
                child: markers.isEmpty
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final marker in shown) MarkerGlyph(marker: marker, size: 9),
                          if (extra > 0)
                            Text(
                              '+$extra',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: foreground),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderCreatePage extends StatefulWidget {
  const ReminderCreatePage({super.key, this.petName = ''});

  final String petName;

  @override
  State<ReminderCreatePage> createState() => _ReminderCreatePageState();
}

class _ReminderCreatePageState extends State<ReminderCreatePage> {
  final RemindersRepository _repository = RemindersRepository();

  void _save(ReminderEntry reminder) {
    unawaited(_repository.saveReminder(reminder));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: widget.petName.isEmpty ? 'Crea promemoria' : 'Nuovo promemoria per ${widget.petName}',
      subtitle: 'Scegli il tipo, la data e i dettagli.',
      child: _ReminderForm(
        petName: widget.petName,
        initial: null,
        onSave: _save,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class ReminderEditPage extends StatefulWidget {
  const ReminderEditPage({super.key, this.reminder});

  final ReminderEntry? reminder;

  @override
  State<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends State<ReminderEditPage> {
  final RemindersRepository _repository = RemindersRepository();

  void _save(ReminderEntry reminder) {
    unawaited(_repository.saveReminder(reminder));
    Navigator.of(context).pop(reminder);
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: 'Modifica promemoria',
      subtitle: 'Aggiorna tipo, data e note.',
      child: _ReminderForm(
        petName: widget.reminder?.petName ?? '',
        initial: widget.reminder,
        onSave: _save,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Shared create/edit form: a required kind selector (spot/recurring/
/// course) drives which fields show below it, since each kind needs
/// different data (a single date; a next date + interval; a start date +
/// duration). Used by both [ReminderCreatePage] and [ReminderEditPage].
class _ReminderForm extends StatefulWidget {
  const _ReminderForm({
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
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.initial?.title ?? '');
  late final _noteController = TextEditingController(text: widget.initial?.note ?? '');

  late EventKind _kind = widget.initial?.kind ?? EventKind.spot;
  late DateTime _date = widget.initial?.dueAt ?? DateTime.now().add(const Duration(days: 1));
  late IntervalUnit _intervalUnit = widget.initial?.intervalUnit ?? IntervalUnit.days;
  late int _intervalValue = widget.initial?.intervalValue ?? 30;
  bool _customInterval = false;
  late final _customIntervalController =
      TextEditingController(text: (widget.initial?.intervalValue ?? 30).toString());
  late int _courseDuration = widget.initial?.courseDurationDays ?? 5;

  late RecurrenceEnd _recurrenceEnd = widget.initial?.recurrenceEnd ?? RecurrenceEnd.never;
  late int _occurrenceCount = widget.initial?.occurrenceCount ?? 6;
  late DateTime _recurrenceEndDate =
      widget.initial?.recurrenceEndDate ?? DateTime.now().add(const Duration(days: 365));
  late final _occurrenceCountController =
      TextEditingController(text: (widget.initial?.occurrenceCount ?? 6).toString());

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _customIntervalController.dispose();
    _occurrenceCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final reminder = ReminderEntry(
      id: widget.initial?.id ?? 'promemoria-${DateTime.now().microsecondsSinceEpoch}',
      petName: widget.initial?.petName ?? widget.petName,
      title: _titleController.text.trim(),
      kind: _kind,
      dueAt: _date,
      note: _noteController.text.trim(),
      intervalUnit: _kind == EventKind.recurring ? _intervalUnit : null,
      intervalValue: _kind == EventKind.recurring ? _intervalValue : null,
      recurrenceEnd: _kind == EventKind.recurring ? _recurrenceEnd : null,
      occurrenceCount:
          _kind == EventKind.recurring && _recurrenceEnd == RecurrenceEnd.afterOccurrences
              ? _occurrenceCount
              : null,
      recurrenceEndDate:
          _kind == EventKind.recurring && _recurrenceEnd == RecurrenceEnd.onDate
              ? _recurrenceEndDate
              : null,
      courseDurationDays: _kind == EventKind.course ? _courseDuration : null,
      isDone: widget.initial?.isDone ?? false,
    );

    widget.onSave(reminder);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            _KindSelector(value: _kind, onChanged: (kind) => setState(() => _kind = kind)),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('Titolo'),
            const SizedBox(height: AppSpacing.xs),
            _TextField(
              controller: _titleController,
              hintText: widget.petName.isEmpty
                  ? 'Es. Richiamo vaccinale'
                  : 'Es. Richiamo vaccinale di ${widget.petName}',
              validator: (value) => (value ?? '').trim().isEmpty ? 'Inserisci un titolo.' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DatePickerField(
              label: switch (_kind) {
                EventKind.spot => 'Data',
                EventKind.recurring => 'Prossima scadenza',
                EventKind.course => 'Data di inizio',
              },
              date: _date,
              onTap: _pickDate,
            ),
            if (_kind == EventKind.recurring) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Si ripete', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.sm),
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
                        hintText: 'Numero',
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
                        onChanged: (unit) => setState(() => _intervalUnit = unit),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Fine ricorrenza', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.sm),
              _RecurrenceEndChips(
                value: _recurrenceEnd,
                onChanged: (end) => setState(() => _recurrenceEnd = end),
              ),
              if (_recurrenceEnd == RecurrenceEnd.afterOccurrences) ...[
                const SizedBox(height: AppSpacing.md),
                _TextField(
                  controller: _occurrenceCountController,
                  hintText: 'Numero di volte',
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
                  label: 'Ultima data',
                  date: _recurrenceEndDate,
                  onTap: _pickRecurrenceEndDate,
                ),
              ],
            ],
            if (_kind == EventKind.course) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Durata del ciclo', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.sm),
              _DurationStepper(
                days: _courseDuration,
                onChanged: (days) => setState(() => _courseDuration = days),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('Nota'),
            const SizedBox(height: AppSpacing.xs),
            _TextField(
              controller: _noteController,
              hintText: 'Es. Porta il libretto sanitario',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: FilledButton(onPressed: _save, child: const Text('Salva'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(onPressed: widget.onCancel, child: const Text('Annulla')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: AppTextStyles.caption);
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.value, required this.onChanged});

  final EventKind value;
  final ValueChanged<EventKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<EventKind>(
      segments: const [
        ButtonSegment(
          value: EventKind.spot,
          icon: Icon(Icons.event_outlined, size: 16),
          label: Text('Evento'),
        ),
        ButtonSegment(
          value: EventKind.recurring,
          icon: Icon(Icons.autorenew_rounded, size: 16),
          label: Text('Ricorrente'),
        ),
        ButtonSegment(
          value: EventKind.course,
          icon: Icon(Icons.medication_outlined, size: 16),
          label: Text('Ciclo'),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  static const _months = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
                ],
              ),
            ),
          ),
        ),
      ],
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
        _presetChip('7 gg', _isSelected(IntervalUnit.days, 7), () => onPreset(IntervalUnit.days, 7)),
        _presetChip('30 gg', _isSelected(IntervalUnit.days, 30), () => onPreset(IntervalUnit.days, 30)),
        _presetChip(
            '6 mesi', _isSelected(IntervalUnit.months, 6), () => onPreset(IntervalUnit.months, 6)),
        _presetChip(
            '12 mesi', _isSelected(IntervalUnit.months, 12), () => onPreset(IntervalUnit.months, 12)),
        _presetChip('Personalizzato', isCustom, onCustom),
      ],
    );
  }

  Widget _presetChip(String label, bool selected, VoidCallback onTap) {
    return _KindChip(label: label, selected: selected, onTap: onTap);
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
        _KindChip(
          label: 'Sempre',
          selected: value == RecurrenceEnd.never,
          onTap: () => onChanged(RecurrenceEnd.never),
        ),
        _KindChip(
          label: 'Per N volte',
          selected: value == RecurrenceEnd.afterOccurrences,
          onTap: () => onChanged(RecurrenceEnd.afterOccurrences),
        ),
        _KindChip(
          label: 'Fino a una data',
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
      segments: const [
        ButtonSegment(value: IntervalUnit.days, label: Text('Giorni')),
        ButtonSegment(value: IntervalUnit.months, label: Text('Mesi')),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
        color: AppColors.background,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: days > 1 ? () => onChanged(days - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
          ),
          Expanded(
            child: Text(
              days == 1 ? '1 giorno' : '$days giorni',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: days < 60 ? () => onChanged(days + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      ),
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
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class ReminderDetailPage extends StatefulWidget {
  const ReminderDetailPage({super.key, this.reminder});

  final ReminderEntry? reminder;

  @override
  State<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends State<ReminderDetailPage> {
  final _repository = RemindersRepository();
  late ReminderEntry? _reminder = widget.reminder;

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<ReminderEntry>(
      MaterialPageRoute<ReminderEntry>(
        builder: (_) => ReminderEditPage(reminder: _reminder),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _reminder = updated);
    }
  }

  Future<void> _delete() async {
    final reminder = _reminder;
    if (reminder == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: const Text('Eliminare questo promemoria?'),
        content: Text('"${reminder.title}" verrà eliminato definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _repository.deleteReminder(reminder.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminder;

    if (reminder == null) {
      return _Shell(
        title: 'Promemoria non trovato',
        subtitle: 'Questo promemoria non è più disponibile.',
        actionLabel: 'Indietro',
        onAction: () => Navigator.of(context).pop(),
        child: _StatePanel(
          label: 'Non trovato',
          title: 'Nessun promemoria da mostrare.',
          body: 'Potrebbe essere stato eliminato o non essere ancora sincronizzato.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Torna alla lista',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    final presentation = ReminderPresentation.of(reminder);

    return _Shell(
      title: 'Dettaglio promemoria',
      subtitle: 'Tipo, data e nota del promemoria.',
      actionLabel: 'Modifica',
      onAction: _openEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(
            title: reminder.title,
            body: reminder.note.isEmpty ? 'Nessuna nota aggiunta.' : reminder.note,
            icon: presentation.icon,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FormPanel(
            title: 'Riepilogo promemoria',
            items: [
              _FormItem(label: 'Animale', value: reminder.petName.isEmpty ? '—' : reminder.petName),
              _FormItem(label: 'Tipo', value: presentation.kindLabel),
              _FormItem(label: 'Stato', value: presentation.dateLabel),
            ],
            onSave: _openEdit,
            onCancel: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
              label: const Text('Elimina promemoria', style: TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FBF8),
              Color(0xFFF4F7EE),
              Color(0xFFEAF0DC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(title: title, subtitle: subtitle, actionLabel: actionLabel, onAction: onAction),
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF163A35)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const _BrandPill(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle, style: AppTextStyles.body),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: AppSpacing.md),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_outlined, size: 14, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Text(
            'VET APP',
            style: TextStyle(color: AppColors.onPrimary, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: label,
      title: title,
      body: body,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: 'Caricamento',
      title: title,
      body: body,
      icon: Icons.hourglass_empty_outlined,
      actionLabel: 'Attendi',
      onAction: null,
      loading: true,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.loading = false,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentPill(label: label),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          if (loading) ...[
            const _Skeleton(width: double.infinity),
            const SizedBox(height: AppSpacing.sm),
            const _Skeleton(width: 180),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF315E55),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.onTap,
    this.compact = false,
    this.onMarkDone,
  });

  final ReminderEntry reminder;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final presentation = ReminderPresentation.of(reminder);
    final palette = DashboardPrimitivePalette.colorsFor(presentation.tone);
    final iconSize = (compact ? 40.0 : 52.0) * appScaleOf(context);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(presentation.icon, color: palette.foreground, size: compact ? 18 : 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: compact ? 15 : 17),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        reminder.petName.isEmpty
                            ? presentation.kindLabel
                            : '${reminder.petName} · ${presentation.kindLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DashboardBadge(label: presentation.dateLabel, tone: presentation.tone, compact: true),
                  if (onMarkDone != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: onMarkDone,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.items,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final List<_FormItem> items;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xl),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _InputLike(label: item.label, value: item.value),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: onSave, child: const Text('Modifica')),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Indietro'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormItem {
  const _FormItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _InputLike extends StatelessWidget {
  const _InputLike({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
