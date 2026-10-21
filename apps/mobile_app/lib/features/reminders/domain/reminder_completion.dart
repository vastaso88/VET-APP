import '../../../shared/date/calendar_days.dart';
import '../../notifications/domain/notification_plan.dart';
import '../data/reminders_repository.dart';

/// How far back an overdue reminder is still asked about on its own when the
/// app opens. Older ones are not forgotten (the list still offers "Fatto?"),
/// but a long-neglected reminder must not greet the owner with a dialog.
const kAutoPromptWindowDays = 7;

/// Pure rules of completing a reminder ("Fatto? Registralo nello storico").
/// Dates are wall-clock local DateTimes; all day arithmetic is calendar-based
/// (see shared/date/calendar_days.dart) so the clock changes of 29/03 and
/// 25/10 never move a day.

/// The day the current occurrence is about: the due day of a one-off or
/// repeating reminder, the last day of a course.
DateTime occurrenceDay(ReminderEntry reminder) {
  final start = DateTime(reminder.dueAt.year, reminder.dueAt.month, reminder.dueAt.day);
  if (reminder.kind == EventKind.course) {
    return addCalendarDays(start, (reminder.courseDurationDays ?? 1) - 1);
  }
  return start;
}

/// The moment from which the reminder is "reached": its time for a one-off or
/// repeating reminder (date-only ones count from 09:00, like their
/// notification), the midnight after the last day for a course.
DateTime completionDueAt(ReminderEntry reminder) {
  if (reminder.kind == EventKind.course) {
    return addCalendarDays(occurrenceDay(reminder), 1);
  }
  return reminderTime(reminder.dueAt);
}

/// A reminder that reached its time and was neither completed nor dismissed.
bool isAwaitingConfirmation(ReminderEntry reminder, DateTime now) =>
    !reminder.isDone && !completionDueAt(reminder).isAfter(now);

/// Whether the app should ask about [reminder] by itself right now: clinical,
/// reached, recently (see [kAutoPromptWindowDays]) and not postponed.
bool shouldAutoPrompt(ReminderEntry reminder, DateTime now, {DateTime? snoozedUntil}) {
  if (!reminder.effectiveCategory.isClinical) return false;
  if (!isAwaitingConfirmation(reminder, now)) return false;
  if (calendarDaysBetween(completionDueAt(reminder), now) > kAutoPromptWindowDays) return false;
  return snoozedUntil == null || !snoozedUntil.isAfter(now);
}

/// The id of the record a completed occurrence writes. Built from the
/// reminder and the occurrence's day, so confirming the same occurrence twice
/// (a retry, a second tap) updates the same record instead of adding another.
/// It is also the link between the two: the id says which reminder made it.
String completedRecordId(ReminderEntry reminder) {
  final day = occurrenceDay(reminder);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return 'reminder-${reminder.id}-${day.year}$month$date';
}

/// The day proposed as "when it happened": the occurrence's day, or today when
/// that is still ahead (completed early).
DateTime defaultEventDay(ReminderEntry reminder, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = occurrenceDay(reminder);
  return day.isAfter(today) ? today : day;
}

/// When "Rimanda" asks again: tomorrow morning.
DateTime snoozeUntil(DateTime now) => DateTime(now.year, now.month, now.day + 1, kDefaultNotificationHour);

/// The due date after the current occurrence of a repeating reminder, or null
/// when the series ends there (and for anything that does not repeat).
/// Months keep the day of the month (clamped to short months) starting from the
/// current due date, so a monthly reminder started on the 31st settles on the
/// 28th after February - the rule of [addMonthsClamped].
DateTime? nextDueAfter(ReminderEntry reminder) {
  final unit = reminder.intervalUnit;
  final step = reminder.intervalValue ?? 0;
  if (reminder.kind != EventKind.recurring || unit == null || step <= 0) return null;

  if (reminder.recurrenceEnd == RecurrenceEnd.afterOccurrences &&
      (reminder.occurrenceCount ?? 0) <= 1) {
    return null;
  }
  final due = reminder.dueAt;
  final next = unit == IntervalUnit.months
      ? addMonthsClamped(due, step)
      : DateTime(due.year, due.month, due.day + step, due.hour, due.minute);

  final lastDay = reminder.recurrenceEnd == RecurrenceEnd.onDate ? reminder.recurrenceEndDate : null;
  if (lastDay != null &&
      DateTime(next.year, next.month, next.day)
          .isAfter(DateTime(lastDay.year, lastDay.month, lastDay.day))) {
    return null;
  }
  return next;
}

/// What a reminder becomes once its current occurrence is dealt with (done or
/// dismissed): a repeating one moves to its next due date after [now] (past
/// ones in between are skipped, not asked about one by one; each skipped one
/// counts against an occurrence limit), everything else is finished.
ReminderEntry advanceReminder(ReminderEntry reminder, DateTime now) {
  if (reminder.kind != EventKind.recurring) return reminder.copyWith(isDone: true);

  var current = reminder;
  // A daily reminder neglected for years is the worst case: bounded, then closed.
  for (var step = 0; step < 5000; step++) {
    final next = nextDueAfter(current);
    if (next == null) return current.copyWith(isDone: true);
    final remaining = current.recurrenceEnd == RecurrenceEnd.afterOccurrences
        ? (current.occurrenceCount ?? 1) - 1
        : null;
    current = current.copyWith(dueAt: next, occurrenceCount: remaining);
    if (current.dueAt.isAfter(now)) return current;
  }
  return current.copyWith(isDone: true);
}
