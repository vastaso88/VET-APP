import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/responsive.dart';
import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../l10n/date_formats.dart';
import '../../../../../shared/date/calendar_days.dart';
import '../../../../../l10n/l10n.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../settings/data/layout_settings_store.dart';
import '../../data/reminders_repository.dart';
import '../../domain/reminder_calendar.dart';
import '../../domain/reminder_presentation.dart';
import '../widgets/reminder_completion_sheet.dart';
import '../../../../shared/widgets/min_tap_target.dart';
import '../widgets/reminder_page_parts.dart';
import 'reminder_create_edit_pages.dart';
import 'reminder_detail_page.dart';

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
        _KindFilterOption.events =>
          kind == EventKind.spot || kind == EventKind.recurring,
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

  _KindFilterOption _kindFilter = _KindFilterOption.all;
  String? _petFilter;
  _ViewMode _viewMode = _ViewMode.list;

  Future<void> _reload() async {
    // The list already rebuilds on its own via RemindersRepository.changes
    // (see the ValueListenableBuilder in build()) — this just forces one
    // more rebuild for the "Riprova" retry button, which also re-attempts
    // ensureHydrated() since a failed hydration leaves _hydratedOwnerId
    // unset.
    setState(() {});
    await _repository.loadReminders();
  }

  void _openCreate() {
    unawaited(() async {
      await PetDemoStore.instance.ensureHydrated();
      if (!mounted) return;
      await openReminderCreate(
        context,
        petNames: [for (final pet in PetDemoStore.instance.list()) pet.name],
      );
      if (mounted) await _reload();
    }());
  }

  void _openDetail(ReminderEntry reminder) {
    unawaited(
      Navigator.of(context)
          .push(
        MaterialPageRoute<void>(
            builder: (_) => ReminderDetailPage(reminder: reminder)),
      )
          .then((_) {
        if (mounted) {
          _reload();
        }
      }),
    );
  }

  /// Asks "Fatto? Registralo nello storico" and does what the owner answers.
  Future<void> _markDone(ReminderEntry reminder) async {
    await askToCompleteReminder(context, reminder);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ReminderPageShell(
          title: context.l10n.remindersTitle,
          subtitle: context.l10n.remindersSubtitle,
          actionLabel: context.l10n.remindersCreateButton,
          onAction: _openCreate,
          showNotificationsBanner: true,
          child: ValueListenableBuilder<int>(
            valueListenable: RemindersRepository.changes,
            builder: (context, _, __) => FutureBuilder<List<ReminderEntry>>(
              future: _repository.loadActiveReminders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ReminderLoadingPanel(
                    title: context.l10n.remindersLoadingTitle,
                    body: context.l10n.remindersLoadingBody,
                  );
                }

                if (snapshot.hasError) {
                  return ReminderStatePanel(
                    label: context.l10n.remindersSyncErrorLabel,
                    title: context.l10n.remindersSyncErrorTitle,
                    body: context.l10n.remindersSyncErrorBody,
                    icon: Icons.wifi_off_outlined,
                    actionLabel: context.l10n.commonRetry,
                    onAction: () => unawaited(_reload()),
                  );
                }

                final all = (snapshot.data ?? const <ReminderEntry>[])
                    .where((reminder) => !reminder.isDone)
                    .toList(growable: false);

                if (all.isEmpty) {
                  return ReminderStatePanel(
                    label: context.l10n.remindersEmptyLabel,
                    title: context.l10n.remindersEmptyTitle,
                    body: context.l10n.remindersEmptyBody,
                    icon: Icons.event_note_outlined,
                    actionLabel: context.l10n.remindersCreateTitle,
                    onAction: _openCreate,
                  );
                }

                final pets = PetDemoStore.instance.list();
                final filtered = all
                    .where((r) =>
                        _kindFilter.matches(r.kind) &&
                        (_petFilter == null || r.petName == _petFilter))
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
                      onSelect: (petName) =>
                          setState(() => _petFilter = petName),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          context.l10n.remindersNoMatchForFilters,
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
                              onTap: () => _openDetail(reminder),
                              onMarkDone: () => _markDone(reminder),
                            ),
                            if (index != filtered.length - 1)
                              const SizedBox(height: AppSpacing.sm),
                          ];
                        },
                      ),
                  ],
                );
              },
            ),
          ),
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
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ReminderKindChip(
            label: context.l10n.remindersFilterAll,
            selected: selected == _KindFilterOption.all,
            onTap: () => onSelect(_KindFilterOption.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          ReminderKindChip(
            label: context.l10n.remindersFilterEvents,
            icon: Icons.event_outlined,
            selected: selected == _KindFilterOption.events,
            onTap: () => onSelect(_KindFilterOption.events),
          ),
          const SizedBox(width: AppSpacing.sm),
          ReminderKindChip(
            label: context.l10n.remindersFilterCourses,
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
  const _PetFilterBar(
      {required this.pets, required this.selected, required this.onSelect});

  final List<PetProfile> pets;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ReminderKindChip(
              label: context.l10n.remindersFilterAll,
              selected: selected == null,
              onTap: () => onSelect(null)),
          for (final pet in pets) ...[
            const SizedBox(width: AppSpacing.sm),
            _PetChip(
                pet: pet,
                selected: selected == pet.name,
                onTap: () => onSelect(pet.name)),
          ],
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip(
      {required this.pet, required this.selected, required this.onTap});

  final PetProfile pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MinTapTarget(
      onTap: onTap,
      child: Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: pet.identityColor),
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
      segments: [
        ButtonSegment(
          value: _ViewMode.list,
          icon: const Icon(Icons.view_list_rounded, size: 16),
          label: Text(context.l10n.remindersViewList),
        ),
        ButtonSegment(
          value: _ViewMode.calendar,
          icon: const Icon(Icons.calendar_month_rounded, size: 16),
          label: Text(context.l10n.remindersViewCalendar),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
            AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
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
  late DateTime _visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay = DateTime.now();

  static String _capitalized(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// "Gennaio" … "Dicembre" in the app language.
  static List<String> _monthNames() => appLongMonths().map(_capitalized).toList();

  /// "Lunedì" … "Domenica" in the app language (Monday first).
  static List<String> _weekdayNames() => appLongWeekdaysMondayFirst().map(_capitalized).toList();

  /// One-letter weekday headers, Monday first ("L", "M", "M", "G", "V", "S", "D").
  static List<String> _mondayFirstLabels() =>
      _weekdayNames().map((name) => name.substring(0, 1)).toList();

  static List<String> _sundayFirstLabels() {
    final labels = _mondayFirstLabels();
    return [labels.last, ...labels.sublist(0, 6)];
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay =
          _selectedDay != null && isSameDay(_selectedDay!, day) ? null : day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekStartDay = LayoutSettingsStore.instance.settings.weekStartDay;
    final pets = PetDemoStore.instance.list();
    final labels = weekStartDay == WeekStartDay.monday
        ? _mondayFirstLabels()
        : _sundayFirstLabels();

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final firstOffset = weekStartDay == WeekStartDay.monday
        ? firstOfMonth.weekday - 1
        : firstOfMonth.weekday % 7;
    final gridStart = addCalendarDays(firstOfMonth, -firstOffset);
    final daysInMonth =
        DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    final totalWeeks = ((firstOffset + daysInMonth) / 7).ceil();

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final selectedDay = _selectedDay;

    final selectedReminders = selectedDay == null
        ? const <ReminderEntry>[]
        : (widget.reminders
            .where((r) => reminderActiveOnDay(r, selectedDay))
            .toList()
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
                tooltip: context.l10n.remindersPreviousMonth,
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.secondaryStrong,
              ),
              Expanded(
                child: Text(
                  '${_monthNames()[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
              ),
              IconButton(
                tooltip: context.l10n.remindersNextMonth,
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.secondaryStrong,
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
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.mutedText),
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
                      final day = addCalendarDays(gridStart, week * 7 + i);
                      return Expanded(
                        child: _MonthDayCell(
                          day: day,
                          inMonth: day.month == _visibleMonth.month,
                          isToday: isSameDay(day, startOfToday),
                          isSelected: selectedDay != null &&
                              isSameDay(day, selectedDay),
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
              Text(context.l10n.remindersNothingThisDay, style: AppTextStyles.bodySmall)
            else
              ...selectedReminders.asMap().entries.expand((entry) {
                final index = entry.key;
                final reminder = entry.value;
                return <Widget>[
                  _ReminderTile(
                    reminder: reminder,
                    compact: true,
                    onTap: () => widget.onOpenReminder(reminder),
                    onMarkDone: () => widget.onMarkDone(reminder),
                  ),
                  if (index != selectedReminders.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ];
              }),
          ],
        ],
      ),
    );
  }

  String _selectedDayLabel(DateTime day) {
    if (isSameDay(day, DateTime.now())) return context.l10n.remindersTodayCapitalized;
    return '${_weekdayNames()[day.weekday - 1]} ${day.day} ${_monthNames()[day.month - 1]}';
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
        : (isToday ? AppColors.secondarySoft : Colors.transparent);
    final foreground = isSelected
        ? AppColors.onPrimary
        : (inMonth
            ? AppColors.text
            : AppColors.mutedText.withValues(alpha: 0.5));
    final shown = markers.take(3).toList();
    final extra = markers.length - shown.length;

    return Semantics(
      button: true,
      selected: isSelected,
      label: markers.isEmpty
          ? '${day.day}'
          : '${day.day}, ${context.l10n.remindersDayActivities(markers.length)}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
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
                            for (final marker in shown)
                              MarkerGlyph(marker: marker, size: 9),
                            if (extra > 0)
                              Text(
                                '+$extra',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: foreground),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
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
                child: Icon(presentation.icon,
                    color: palette.foreground, size: compact ? 18 : 24),
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
                      style: AppTextStyles.title
                          .copyWith(fontSize: compact ? 15 : 17),
                    ),
                    if (!compact &&
                        (reminder.petName.isNotEmpty || presentation.listKindLabel != null)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          if (reminder.petName.isNotEmpty) reminder.petName,
                          if (presentation.listKindLabel != null) presentation.listKindLabel!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Scales down instead of pushing the row past the card edge
                  // when the date label is long or the text size is large.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: DashboardBadge(
                        label: presentation.dateLabel,
                        tone: presentation.tone,
                        compact: true),
                  ),
                  if (onMarkDone != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Tooltip(
                      message: context.l10n.remindersDoneTooltip,
                      child: InkWell(
                        onTap: onMarkDone,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.check_circle_outline,
                              size: 18, color: AppColors.success),
                        ),
                      ),
                    ),
                  ],
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
