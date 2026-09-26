import 'package:flutter/material.dart';

import '../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../data/reminders_repository.dart';
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
          kindLabel: 'Evento',
          dateLabel: relativeDayLabel(reminder.dueAt),
          tone: _urgencyTone(reminder.dueAt, startOfToday),
        );
      case EventKind.recurring:
        return ReminderPresentation(
          icon: Icons.autorenew_rounded,
          kindLabel: 'Ricorrente · ${_intervalLabel(reminder)}${_recurrenceEndLabel(reminder)}',
          dateLabel: relativeDayLabel(reminder.dueAt),
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
      dateLabel = 'Inizia ${relativeDayLabel(reminder.dueAt)}';
      tone = DashboardTone.neutral;
    } else if (dayNumber > duration) {
      dateLabel = 'Completato';
      tone = DashboardTone.success;
    } else {
      dateLabel = 'Giorno $dayNumber di $duration';
      tone = dayNumber == duration ? DashboardTone.warning : DashboardTone.primary;
    }

    return ReminderPresentation(
      icon: Icons.medication_outlined,
      kindLabel: 'Ciclo · $duration giorni',
      dateLabel: dateLabel,
      tone: tone,
    );
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
    final unitLabel = switch (unit) {
      IntervalUnit.days => value == 1 ? 'giorno' : 'giorni',
      IntervalUnit.months => value == 1 ? 'mese' : 'mesi',
    };
    return 'ogni $value $unitLabel';
  }

  static const _months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic',
  ];

  static String _recurrenceEndLabel(ReminderEntry reminder) {
    switch (reminder.recurrenceEnd) {
      case RecurrenceEnd.afterOccurrences:
        final count = reminder.occurrenceCount;
        if (count == null) return '';
        return count == 1 ? ' · per 1 volta' : ' · per $count volte';
      case RecurrenceEnd.onDate:
        final end = reminder.recurrenceEndDate;
        if (end == null) return '';
        return ' · fino al ${end.day} ${_months[end.month - 1]} ${end.year}';
      case RecurrenceEnd.never:
      case null:
        return '';
    }
  }
}
