import 'package:flutter/material.dart';

import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../data/reminders_repository.dart';
import 'clock_time.dart';
import 'relative_date.dart';

/// Icon, type label, date/progress label, and urgency tone for a
/// [ReminderEntry] — computed live from [ReminderEntry.dueAt]/`kind` rather
/// than stored, and shared by Home, the reminders list, and the pet-detail
/// Promemoria tab so the three never drift out of sync.
class ReminderPresentation {
  const ReminderPresentation({
    required this.icon,
    required this.kindLabel,
    required this.dateLabel,
    required this.tone,
  });

  final IconData icon;
  final String kindLabel;
  final String dateLabel;
  final DashboardTone tone;

  factory ReminderPresentation.of(ReminderEntry reminder, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    switch (reminder.kind) {
      case EventKind.spot:
        return ReminderPresentation(
          icon: Icons.event_outlined,
          kindLabel: appL10n.remindersKindEvent,
          dateLabel: _withTime(relativeDayLabel(reminder.dueAt), reminder.dueAt),
          tone: _urgencyTone(reminder.dueAt, startOfToday),
        );
      case EventKind.recurring:
        return ReminderPresentation(
          icon: Icons.autorenew_rounded,
          kindLabel: appL10n.remindersKindRecurring(
            _intervalLabel(reminder),
            _recurrenceEndLabel(reminder),
          ),
          dateLabel: _withTime(relativeDayLabel(reminder.dueAt), reminder.dueAt),
          tone: _urgencyTone(reminder.dueAt, startOfToday),
        );
      case EventKind.course:
        return _coursePresentation(reminder, startOfToday);
    }
  }

  static ReminderPresentation _coursePresentation(ReminderEntry reminder, DateTime startOfToday) {
    final duration = reminder.courseDurationDays ?? 1;
    final startOfCourse = DateTime(reminder.dueAt.year, reminder.dueAt.month, reminder.dueAt.day);
    final dayNumber = startOfToday.difference(startOfCourse).inDays + 1;

    final String dateLabel;
    final DashboardTone tone;
    if (dayNumber < 1) {
      dateLabel = appL10n.remindersCourseStarts(relativeDayLabel(reminder.dueAt));
      tone = DashboardTone.neutral;
    } else if (dayNumber > duration) {
      dateLabel = appL10n.remindersCourseCompleted;
      tone = DashboardTone.success;
    } else {
      dateLabel = appL10n.remindersCourseDayOf(dayNumber, duration);
      tone = dayNumber == duration ? DashboardTone.warning : DashboardTone.primary;
    }

    return ReminderPresentation(
      icon: Icons.medication_outlined,
      kindLabel: reminder.doseTimes.isEmpty
          ? appL10n.remindersKindCourse(duration)
          : appL10n.remindersKindCourseWithTimes(duration, reminder.doseTimes.join(', ')),
      dateLabel: dateLabel,
      tone: tone,
    );
  }

  /// "Domani · 15:30"; date-only reminders (midnight) keep just the day.
  static String _withTime(String dayLabel, DateTime dueAt) {
    if (dueAt.hour == 0 && dueAt.minute == 0) return dayLabel;
    return '$dayLabel · ${formatClockTime(dueAt.hour, dueAt.minute)}';
  }

  static DashboardTone _urgencyTone(DateTime dueAt, DateTime startOfToday) {
    final startOfDue = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final daysUntil = startOfDue.difference(startOfToday).inDays;
    if (daysUntil <= 0) return DashboardTone.danger;
    if (daysUntil <= 3) return DashboardTone.warning;
    return DashboardTone.neutral;
  }

  static String _intervalLabel(ReminderEntry reminder) {
    final value = reminder.intervalValue ?? 1;
    final unit = reminder.intervalUnit ?? IntervalUnit.days;
    return switch (unit) {
      IntervalUnit.days => appL10n.remindersIntervalEveryDays(value),
      IntervalUnit.months => appL10n.remindersIntervalEveryMonths(value),
    };
  }

  static String _recurrenceEndLabel(ReminderEntry reminder) {
    switch (reminder.recurrenceEnd) {
      case RecurrenceEnd.afterOccurrences:
        final count = reminder.occurrenceCount;
        if (count == null) return '';
        return appL10n.remindersEndAfterTimes(count);
      case RecurrenceEnd.onDate:
        final end = reminder.recurrenceEndDate;
        if (end == null) return '';
        return appL10n.remindersEndUntilDate(formatAppDate(end, 'd MMM y'));
      case RecurrenceEnd.never:
      case null:
        return '';
    }
  }
}
