import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/date/calendar_days.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/domain/clock_time.dart';
import '../../../reminders/domain/memorial_reminders.dart';
import '../../../reminders/domain/reminder_calendar.dart';
import '../../../settings/data/layout_settings_store.dart';
import 'home_dashboard_primitives.dart';
import 'home_surface.dart';

/// The days of the home calendar strip: [weeksShown] full weeks starting from
/// the week of [today]. Calendar arithmetic, so the clock change of 29/03 and
/// 25/10 never repeats or skips a date.
@visibleForTesting
List<DateTime> homeCalendarDays(
    DateTime today, int weeksShown, WeekStartDay weekStartDay) {
  final weekStart = _startOfWeek(today, weekStartDay);
  return List.generate(weeksShown * 7, (i) => addCalendarDays(weekStart, i));
}

DateTime _startOfWeek(DateTime day, WeekStartDay weekStartDay) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final offset = weekStartDay == WeekStartDay.monday
      ? startOfDay.weekday - 1
      : startOfDay.weekday % 7;
  return addCalendarDays(startOfDay, -offset);
}

/// "Il tuo calendario": the coming days, whose day each activity is, and what
/// there is today. The whole card opens the reminders.
class HomeCalendarSection extends StatefulWidget {
  const HomeCalendarSection({
    super.key,
    required this.repository,
    required this.clock,
    required this.onOpenReminders,
  });

  final RemindersRepository repository;
  final DateTime Function() clock;
  final VoidCallback onOpenReminders;

  @override
  State<HomeCalendarSection> createState() => _HomeCalendarSectionState();
}

class _HomeCalendarSectionState extends State<HomeCalendarSection> {
  int? _tick;
  Future<List<ReminderEntry>>? _future;

  /// One read per change of the reminders: a rebuild for any other reason
  /// (layout, pets) keeps the same Future, so the calendar never goes back to
  /// the loader on its own.
  Future<List<ReminderEntry>> _futureFor(int tick) {
    if (_future == null || _tick != tick) {
      _tick = tick;
      _future = widget.repository.loadActiveReminders();
    }
    return _future!;
  }

  void _retry() => setState(() {
        _future = null;
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LayoutSettingsStore.instance,
      builder: (context, _) {
        final layout = LayoutSettingsStore.instance.settings;

        // Home stays alive under the bottom-nav IndexedStack (never
        // disposed/rebuilt on tab switch), so a one-shot Future loaded in
        // initState never saw a reminder created elsewhere. Listening to
        // RemindersRepository.changes and re-fetching on every tick keeps
        // the calendar in sync no matter where the reminder was added.
        return ValueListenableBuilder<int>(
          valueListenable: RemindersRepository.changes,
          builder: (context, tick, __) {
            return FutureBuilder<List<ReminderEntry>>(
              future: _futureFor(tick),
              builder: (context, snapshot) {
                // The loader only while there is nothing to show yet: a reload
                // keeps the previous calendar on screen.
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return _section(
                    context,
                    subtitle: context.l10n.homeAgendaLoadingSubtitle,
                    child: const HomeSectionLoader(),
                  );
                }
                if (snapshot.hasError && !snapshot.hasData) {
                  return _section(
                    context,
                    child: HomeSectionNotice(
                      text: Text(
                        context.l10n.remindersSyncErrorTitle,
                        style: AppTextStyles.bodySmall,
                      ),
                      action: TextButton.icon(
                        key: const ValueKey('home-calendar-retry'),
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.l10n.commonRetry),
                      ),
                    ),
                  );
                }

                return ValueListenableBuilder<int>(
                  valueListenable: PetDemoStore.changes,
                  builder: (context, _, __) => _calendar(
                    context,
                    layout,
                    snapshot.data ?? const <ReminderEntry>[],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _section(BuildContext context, {String? subtitle, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionHeader(title: context.l10n.homeAgendaTitle, subtitle: subtitle),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }

  Widget _calendar(BuildContext context, LayoutSettings layout, List<ReminderEntry> loaded) {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final pets = PetDemoStore.instance.list();
    // An animal moved to Ricordi while this page was open: its activities go
    // at once, without waiting for the reminders to be read again.
    final reminders = remindersOfActivePets(
      loaded,
      PetDemoStore.instance.list(includeMemorial: true),
    ).where((reminder) => !reminder.isDone).toList(growable: false)
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    return _section(
      context,
      subtitle: _summaryLine(context, reminders, today),
      child: HomeCard(
        key: const ValueKey('home-calendar'),
        padding: const EdgeInsets.all(AppSpacing.md),
        // The whole calendar is the entry point into the full reminders view:
        // no separate "Vedi tutti" link.
        onTap: widget.onOpenReminders,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeekStrip(
              reminders: reminders,
              pets: pets,
              weeksShown: layout.weeksShown,
              weekStartDay: layout.weekStartDay,
              today: today,
            ),
            const SizedBox(height: AppSpacing.sm),
            _TodayPanel(
              reminders: [
                for (final reminder in reminders)
                  if (reminderActiveOnDay(reminder, today)) reminder,
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fixed 10-day window, deliberately independent of the "weeks shown"
  /// layout setting, which only governs the calendar strip above. Courses
  /// aren't counted here: they're ongoing rather than "upcoming".
  String _summaryLine(BuildContext context, List<ReminderEntry> reminders, DateTime today) {
    final endOfWindow = addCalendarDays(today, 10);

    final count = reminders.where((r) {
      if (r.kind == EventKind.course) return false;
      final d = DateTime(r.dueAt.year, r.dueAt.month, r.dueAt.day);
      return !d.isBefore(today) && !d.isAfter(endOfWindow);
    }).length;

    return context.l10n.homeAgendaSummary(count);
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.reminders,
    required this.pets,
    required this.weeksShown,
    required this.weekStartDay,
    required this.today,
  });

  final List<ReminderEntry> reminders;
  final List<PetProfile> pets;
  final int weeksShown;
  final WeekStartDay weekStartDay;
  final DateTime today;

  /// One-letter weekday headers in the app language ("L M M G V S D" in
  /// Italian), Monday first.
  static List<String> _mondayFirstLabels() => [
        for (final name in appShortWeekdaysMondayFirst()) _initial(name),
      ];

  static List<String> _sundayFirstLabels() {
    final monday = _mondayFirstLabels();
    return [monday.last, ...monday.sublist(0, 6)];
  }

  static String _initial(String name) =>
      name.isEmpty ? '' : String.fromCharCode(name.runes.first).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final labels = weekStartDay == WeekStartDay.monday
        ? _mondayFirstLabels()
        : _sundayFirstLabels();
    final days = homeCalendarDays(today, weeksShown, weekStartDay);

    return Column(
      children: [
        for (var week = 0; week < weeksShown; week++) ...[
          if (week != 0) const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: HomeDayChip(
                    day: days[week * 7 + i],
                    // The letters head the columns once; today is always in
                    // the first week, so its block has letter and number.
                    label: week == 0 ? labels[i] : '',
                    isToday: isSameDay(days[week * 7 + i], today),
                    isPast: days[week * 7 + i].isBefore(today),
                    markers: activityMarkersForDay(reminders, pets, days[week * 7 + i]),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One day of the home calendar strip. Public only so a test can pump it.
///
/// [markers] has one entry per activity: a single one shows the animal's
/// initial in a ring of its colour, more than one show how many they are.
@visibleForTesting
class HomeDayChip extends StatelessWidget {
  const HomeDayChip({
    super.key,
    required this.day,
    required this.label,
    required this.isToday,
    required this.markers,
    this.isPast = false,
  });

  final DateTime day;
  final String label;
  final bool isToday;
  final bool isPast;
  final List<DayMarker> markers;

  @override
  Widget build(BuildContext context) {
    // The mark grows with the text it holds, within what a column can take.
    final markSize = MediaQuery.textScalerOf(context).scale(12) * 1.9;

    // Spoken as "19, 2 promemoria", not as the letter, the number and the
    // mark one by one.
    return Semantics(
      label: markers.isEmpty
          ? '${day.day}'
          : '${day.day}, ${context.l10n.remindersDayActivities(markers.length)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: isToday
            ? BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty)
              Text(
                label,
                maxLines: 1,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 13, height: 1.3),
              ),
            Text(
              '${day.day}',
              maxLines: 1,
              style: AppTextStyles.bodySmall.copyWith(
                color: isPast ? AppColors.mutedText : AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox.square(
              dimension: markSize,
              child: markers.isEmpty ? null : _DayMark(markers: markers),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({required this.markers});

  final List<DayMarker> markers;

  @override
  Widget build(BuildContext context) {
    final single = markers.length == 1 ? markers.single : null;
    final initial = single?.initial ?? '';
    final counted = initial.isEmpty;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondarySoft,
        border: Border.all(
          color: counted ? AppColors.secondary : single!.color,
          width: counted ? 1 : 2,
        ),
      ),
      child: Text(
        counted ? '${markers.length}' : initial,
        maxLines: 1,
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w700,
          color: counted ? AppColors.secondaryStrong : AppColors.text,
        ),
      ),
    );
  }
}

/// "Oggi" and its activities, the ones with a time in order of time.
class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.reminders});

  final List<ReminderEntry> reminders;

  /// More than these open with the calendar.
  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final ordered = List<ReminderEntry>.of(reminders)
      ..sort((a, b) => _minuteOfDay(a).compareTo(_minuteOfDay(b)));
    final extra = math.max(0, ordered.length - _shown);

    return Container(
      key: const ValueKey('home-today'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.remindersTodayCapitalized,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (ordered.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.remindersNothingThisDay,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
            ),
          ],
          for (final reminder in ordered.take(_shown)) ...[
            const SizedBox(height: AppSpacing.xs),
            _TodayRow(reminder: reminder),
          ],
          if (extra > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '+$extra',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryStrong,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.reminder});

  final ReminderEntry reminder;

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel(reminder);
    final style = AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.text);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              [
                reminder.title,
                if (reminder.petName.trim().isNotEmpty) reminder.petName.trim(),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            // A course with many doses: its times go on a second line instead
            // of squeezing the title out.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
              child: Text(time, textAlign: TextAlign.end, style: style),
            ),
          ],
        ],
      ),
    );
  }
}

/// "11:00", the dose times of a course, or nothing for an all-day activity.
String _timeLabel(ReminderEntry reminder) {
  if (reminder.doseTimes.isNotEmpty) return reminder.doseTimes.join(', ');
  final due = reminder.dueAt;
  if (due.hour == 0 && due.minute == 0) return '';
  return formatClockTime(due.hour, due.minute);
}

/// Where the activity falls in the day; those without a time come first.
int _minuteOfDay(ReminderEntry reminder) {
  if (reminder.doseTimes.isNotEmpty) {
    final first = parseClockTime(reminder.doseTimes.first);
    if (first != null) return first.hour * 60 + first.minute;
  }
  return reminder.dueAt.hour * 60 + reminder.dueAt.minute;
}
