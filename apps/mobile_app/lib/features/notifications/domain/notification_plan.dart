import '../../pets/domain/pet_format.dart';
import '../../pets/domain/pet_models.dart';
import '../../reminders/data/reminders_repository.dart';
import '../../reminders/domain/clock_time.dart';

/// The three kinds of phone notification, each with its own switch in
/// Impostazioni.
enum NotificationCategory { reminders, medicines, birthdays }

class NotificationPreferences {
  const NotificationPreferences({
    this.reminders = true,
    this.medicines = true,
    this.birthdays = true,
  });

  final bool reminders;
  final bool medicines;
  final bool birthdays;

  bool allows(NotificationCategory category) => switch (category) {
        NotificationCategory.reminders => reminders,
        NotificationCategory.medicines => medicines,
        NotificationCategory.birthdays => birthdays,
      };

  NotificationPreferences copyWith({bool? reminders, bool? medicines, bool? birthdays}) {
    return NotificationPreferences(
      reminders: reminders ?? this.reminders,
      medicines: medicines ?? this.medicines,
      birthdays: birthdays ?? this.birthdays,
    );
  }
}

/// One notification to put on the phone. [at] is a wall-clock time (what
/// the owner reads on the clock in Italy), turned into a real instant only
/// when scheduled — see notification_time_zone.dart.
class PlannedNotification {
  const PlannedNotification({
    required this.at,
    required this.title,
    required this.body,
    required this.category,
  });

  final DateTime at;
  final String title;
  final String body;
  final NotificationCategory category;

  @override
  String toString() => '$at · $title · $body';
}

/// Time used for a reminder saved before a time could be picked (midnight),
/// a course without dose times, and birthdays.
const kDefaultNotificationHour = 9;

/// The evening before a visit or vaccine, "Domani: ..." arrives at this hour.
const kDayBeforeHour = 18;

/// How far ahead repeating reminders and courses are expanded. The plan is
/// rebuilt every time the app opens or the data changes, so this only
/// limits what is waiting on the phone if the app stays closed for long.
const kPlanHorizon = Duration(days: 60);

/// Upper bound on scheduled notifications (the earliest ones are kept):
/// far below Android's per-app alarm limit (500) and iOS's 64.
const kMaxPlannedNotifications = 64;

/// Everything to notify from [now] on, earliest first, at most [maxCount].
/// Pure: same input, same plan — the scheduler cancels and re-schedules it
/// whole on every change.
List<PlannedNotification> planNotifications({
  required List<ReminderEntry> reminders,
  required List<PetProfile> pets,
  required DateTime now,
  NotificationPreferences preferences = const NotificationPreferences(),
  Duration horizon = kPlanHorizon,
  int maxCount = kMaxPlannedNotifications,
}) {
  final until = now.add(horizon);
  final memorialNames = {for (final pet in pets) if (pet.isMemorial) pet.name};
  final planned = <PlannedNotification>[];

  for (final reminder in reminders) {
    if (reminder.isDone || memorialNames.contains(reminder.petName)) continue;
    if (reminder.kind == EventKind.course) {
      planned.addAll(_courseNotifications(reminder, now, until));
    } else {
      planned.addAll(_eventNotifications(reminder, now, until));
    }
  }
  for (final pet in pets) {
    if (pet.isMemorial) continue;
    planned.addAll(_birthdayNotifications(pet, now));
  }

  final allowed = planned
      .where((n) => preferences.allows(n.category) && n.at.isAfter(now))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return allowed.length > maxCount ? allowed.sublist(0, maxCount) : allowed;
}

/// The reminder's own time, or [kDefaultNotificationHour] when it was saved
/// date-only (midnight).
DateTime reminderTime(DateTime dueAt) {
  if (dueAt.hour == 0 && dueAt.minute == 0) {
    return DateTime(dueAt.year, dueAt.month, dueAt.day, kDefaultNotificationHour);
  }
  return dueAt;
}

/// Occurrences of a spot or recurring reminder up to [until]: the due date
/// itself, then every interval after it, until the series ends.
List<DateTime> reminderOccurrences(ReminderEntry reminder, DateTime until) {
  final first = reminderTime(reminder.dueAt);
  final step = reminder.intervalValue ?? 0;
  if (reminder.kind != EventKind.recurring || reminder.intervalUnit == null || step <= 0) {
    return first.isAfter(until) ? const [] : [first];
  }

  final lastDay = reminder.recurrenceEnd == RecurrenceEnd.onDate ? reminder.recurrenceEndDate : null;
  final maxCount =
      reminder.recurrenceEnd == RecurrenceEnd.afterOccurrences ? reminder.occurrenceCount : null;
  final occurrences = <DateTime>[];
  // 5000 bounds a daily series started years ago; the loop otherwise ends
  // at [until] or at the end of the series.
  for (var index = 0; index < 5000; index++) {
    if (maxCount != null && index >= maxCount) break;
    final at = reminder.intervalUnit == IntervalUnit.months
        ? addMonthsClamped(first, step * index)
        : DateTime(first.year, first.month, first.day + step * index, first.hour, first.minute);
    if (at.isAfter(until)) break;
    if (lastDay != null && _dayOf(at).isAfter(_dayOf(lastDay))) break;
    occurrences.add(at);
  }
  return occurrences;
}

/// [date] moved by [months], kept on the same day of the month or, when that
/// month is shorter, on its last day (31 Jan + 1 month = 28/29 Feb).
DateTime addMonthsClamped(DateTime date, int months) {
  final firstOfTarget = DateTime(date.year, date.month + months);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(firstOfTarget.year, firstOfTarget.month, day, date.hour, date.minute);
}

Iterable<PlannedNotification> _eventNotifications(
  ReminderEntry reminder,
  DateTime now,
  DateTime until,
) sync* {
  for (final at in reminderOccurrences(reminder, until)) {
    final time = formatClockTime(at.hour, at.minute);
    yield PlannedNotification(
      at: at,
      title: reminder.title,
      body: '${reminder.petName} · oggi alle $time',
      category: NotificationCategory.reminders,
    );
    yield PlannedNotification(
      at: DateTime(at.year, at.month, at.day - 1, kDayBeforeHour),
      title: 'Domani: ${reminder.title}',
      body: '${reminder.petName} · alle $time',
      category: NotificationCategory.reminders,
    );
  }
}

/// One notification per dose time on every day of the course, or one a day
/// at the course's time when no dose time was set.
Iterable<PlannedNotification> _courseNotifications(
  ReminderEntry course,
  DateTime now,
  DateTime until,
) sync* {
  final start = reminderTime(course.dueAt);
  final days = course.courseDurationDays ?? 1;
  final times = course.doseTimes.map(parseClockTime).whereType<({int hour, int minute})>().toList();
  if (times.isEmpty) times.add((hour: start.hour, minute: start.minute));

  for (var day = 0; day < days; day++) {
    for (final time in times) {
      final at = DateTime(start.year, start.month, start.day + day, time.hour, time.minute);
      if (at.isAfter(until)) return;
      yield PlannedNotification(
        at: at,
        title: 'Farmaco per ${course.petName}',
        body: course.doseTimes.isEmpty
            ? '${course.title} · giorno ${day + 1} di $days'
            : '${course.title} · dose delle ${formatClockTime(time.hour, time.minute)}',
        category: NotificationCategory.medicines,
      );
    }
  }
}

/// The birthday itself and the heads-up a week before. The heads-up is
/// purely informative on purpose: pointing it at products or shops would
/// make it marketing, which needs the owner's marketing consent
/// (docs/compliance/04).
Iterable<PlannedNotification> _birthdayNotifications(PetProfile pet, DateTime now) sync* {
  final birth = parsePetBirthdayLabel(pet.birthDateLabel);
  if (birth == null) return;
  final today = _dayOf(now);
  if (birth.isAfter(today)) return;

  final birthday = nextBirthday(birth, today);
  final years = birthday.year - birth.year;
  if (years >= 1) {
    yield PlannedNotification(
      at: DateTime(birthday.year, birthday.month, birthday.day, kDefaultNotificationHour),
      title: 'Buon compleanno, ${pet.name}!',
      body: years == 1 ? 'Oggi compie 1 anno.' : 'Oggi compie $years anni.',
      category: NotificationCategory.birthdays,
    );
  }

  // The next birthday at least a week away, so the heads-up is still ahead.
  final upcoming = nextBirthday(birth, DateTime(today.year, today.month, today.day + 7));
  final headsUp = DateTime(upcoming.year, upcoming.month, upcoming.day - 7, kDefaultNotificationHour);
  yield PlannedNotification(
    at: headsUp,
    title: 'Compleanno in arrivo',
    body: 'Tra una settimana è il compleanno di ${pet.name}: pensa a un regalo.',
    category: NotificationCategory.birthdays,
  );
}

/// The first birthday on or after [from] (both are dates, no time), for a pet
/// born on [birth]. Someone born on 29 February celebrates on 28 February in
/// years that have no 29th.
DateTime nextBirthday(DateTime birth, DateTime from) {
  final thisYear = _birthdayIn(birth, from.year);
  return thisYear.isBefore(_dayOf(from)) ? _birthdayIn(birth, from.year + 1) : thisYear;
}

/// [birth]'s day and month in [year]; DateTime(2027, 2, 29) would silently
/// roll over to 1 March, so the day is clamped to the month's last day.
DateTime _birthdayIn(DateTime birth, int year) {
  final lastDay = DateTime(year, birth.month + 1, 0).day;
  return DateTime(year, birth.month, birth.day > lastDay ? lastDay : birth.day);
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
