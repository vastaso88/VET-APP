import 'package:flutter_test/flutter_test.dart';

import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_time_zone.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_calendar.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_completion.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_presentation.dart';
import 'package:vet_app_mobile/shared/date/calendar_days.dart';

/// Clocks change in Italy on 29 March 2026 (forward, 02:00 -> 03:00) and on
/// 25 October 2026 (back, 03:00 -> 02:00). These tests would fail with
/// `Duration(days: n)` arithmetic on a machine set to a zone with that change
/// (the project's own machines are); elsewhere they simply must still pass.
void main() {
  group('calendar days', () {
    test('adding days never moves the clock time or the day', () {
      expect(addCalendarDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
      expect(addCalendarDays(DateTime(2026, 10, 24, 9, 30), 3), DateTime(2026, 10, 27, 9, 30));
      expect(addCalendarDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
      expect(addCalendarDays(DateTime(2026, 3, 27, 8), 5), DateTime(2026, 4, 1, 8));
      expect(addCalendarDays(DateTime(2026, 10, 26), -2), DateTime(2026, 10, 24));
      expect(addCalendarDays(DateTime(2026, 12, 30), 3), DateTime(2027, 1, 2));
    });

    test('days between are whole calendar days across both changes', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(calendarDaysBetween(DateTime(2026, 3, 30, 23), DateTime(2026, 3, 28, 1)), -2);
      expect(calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
      expect(calendarDaysBetween(DateTime(2026, 10, 25, 23, 59), DateTime(2026, 10, 26, 0, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 6, 1, 8), DateTime(2026, 6, 1, 22)), 0);
    });

    test('every cell of an October month grid is the day after the previous one', () {
      // What the reminders calendar draws: it starts on a Monday of September.
      final gridStart = addCalendarDays(DateTime(2026, 10), -3);
      var previous = gridStart;
      for (var cell = 1; cell < 42; cell++) {
        final day = addCalendarDays(gridStart, cell);
        expect(calendarDaysBetween(previous, day), 1, reason: 'cell $cell');
        expect(day.hour, 0);
        previous = day;
      }
      expect(addCalendarDays(gridStart, 28), DateTime(2026, 10, 26));
    });
  });

  group('courses over the change', () {
    ReminderEntry course(DateTime start, int days) => ReminderEntry(
          id: 'c',
          petName: 'Moka',
          title: 'Antibiotico',
          kind: EventKind.course,
          dueAt: start,
          courseDurationDays: days,
        );

    test('a course that spans 25 October is active on every one of its days', () {
      final antibiotic = course(DateTime(2026, 10, 24), 4); // 24, 25, 26, 27
      for (final day in [24, 25, 26, 27]) {
        expect(reminderActiveOnDay(antibiotic, DateTime(2026, 10, day)), isTrue, reason: '$day');
      }
      expect(reminderActiveOnDay(antibiotic, DateTime(2026, 10, 28)), isFalse);
      expect(reminderActiveOnDay(antibiotic, DateTime(2026, 10, 23)), isFalse);
    });

    test('a course that spans 29 March is active on every one of its days', () {
      final antibiotic = course(DateTime(2026, 3, 27), 4); // 27, 28, 29, 30
      for (final day in [27, 28, 29, 30]) {
        expect(reminderActiveOnDay(antibiotic, DateTime(2026, 3, day)), isTrue, reason: '$day');
      }
      expect(reminderActiveOnDay(antibiotic, DateTime(2026, 3, 31)), isFalse);
    });

    test('the day number of a course is not off by one after the March change', () {
      final antibiotic = course(DateTime(2026, 3, 28), 5);

      expect(ReminderPresentation.of(antibiotic, now: DateTime(2026, 3, 30, 12)).dateLabel,
          ReminderPresentation.of(antibiotic, now: DateTime(2026, 3, 30, 22)).dateLabel);
      // 28 = day 1, 29 = day 2, 30 = day 3.
      expect(ReminderPresentation.of(antibiotic, now: DateTime(2026, 3, 30, 12)).dateLabel,
          contains('3'));
      expect(ReminderPresentation.of(antibiotic, now: DateTime(2026, 3, 29, 12)).dateLabel,
          contains('2'));
    });

    test('the last day of a course (when "Fatto?" is asked) counts calendar days', () {
      final antibiotic = course(DateTime(2026, 10, 24, 8), 4);

      expect(occurrenceDay(antibiotic), DateTime(2026, 10, 27));
      expect(completionDueAt(antibiotic), DateTime(2026, 10, 28));
    });
  });

  group('repeating reminders over the change', () {
    ReminderEntry repeating(DateTime due, int days) => ReminderEntry(
          id: 'r',
          petName: 'Moka',
          title: 'Antiparassitario',
          kind: EventKind.recurring,
          dueAt: due,
          intervalUnit: IntervalUnit.days,
          intervalValue: days,
        );

    test('the next date keeps its clock time across both changes', () {
      expect(nextDueAfter(repeating(DateTime(2026, 10, 24, 8), 1)), DateTime(2026, 10, 25, 8));
      expect(nextDueAfter(repeating(DateTime(2026, 10, 25, 8), 1)), DateTime(2026, 10, 26, 8));
      expect(nextDueAfter(repeating(DateTime(2026, 3, 22, 7, 30), 7)), DateTime(2026, 3, 29, 7, 30));
      expect(nextDueAfter(repeating(DateTime(2026, 3, 29, 7, 30), 7)), DateTime(2026, 4, 5, 7, 30));
      expect(nextDueAfter(repeating(DateTime(2026, 10, 20, 21), 14)), DateTime(2026, 11, 3, 21));
    });

    test('a series of dates stays on the same hour from October to November', () {
      var reminder = repeating(DateTime(2026, 10, 23, 8), 1);
      final dates = <DateTime>[reminder.dueAt];
      for (var i = 0; i < 5; i++) {
        reminder = reminder.copyWith(dueAt: nextDueAfter(reminder));
        dates.add(reminder.dueAt);
      }
      expect(dates.map((d) => d.hour), everyElement(8));
      expect(dates.map((d) => d.day), [23, 24, 25, 26, 27, 28]);
    });

    test('notifications: every occurrence is 08:00 on the phone clock, even across the change',
        () {
      final plan = planNotifications(
        reminders: [repeating(DateTime(2026, 10, 23, 8), 1)],
        pets: const [],
        now: DateTime(2026, 10, 22, 10),
        horizon: const Duration(days: 6),
      );
      final dues = plan.where((n) => n.payload != null).toList();

      expect(dues.map((n) => n.at.day), [23, 24, 25, 26, 27, 28]);
      for (final notification in dues) {
        expect(notificationInstant(notification.at).hour, 8, reason: '${notification.at}');
      }
      // 08:00 is 06:00 UTC before the change and 07:00 UTC after it.
      expect(notificationInstant(DateTime(2026, 10, 24, 8)).toUtc().hour, 6);
      expect(notificationInstant(DateTime(2026, 10, 26, 8)).toUtc().hour, 7);
    });

    test('the plan dates run unbroken, one calendar day apart, on the same hour', () {
      final plan = planNotifications(
        reminders: [repeating(DateTime(2026, 10, 23, 8), 1)],
        pets: const [],
        now: DateTime(2026, 10, 22, 10),
      );
      final dues = plan.where((n) => n.payload != null).map((n) => n.at).toList();

      expect(dues.length, greaterThan(10));
      for (var i = 1; i < dues.length; i++) {
        expect(calendarDaysBetween(dues[i - 1], dues[i]), 1);
        expect(dues[i].hour, 8);
      }
    });
  });

  group('times that do not exist or happen twice', () {
    test('02:30 on 29 March (skipped) and on 25 October (twice) still give an instant that day',
        () {
      final skipped = notificationInstant(DateTime(2026, 3, 29, 2, 30));
      expect(skipped.year, 2026);
      expect(skipped.month, 3);
      expect(skipped.day, 29);
      // Rome has no 02:30 that night: it lands on one of the two neighbouring hours.
      expect([1, 3], contains(skipped.hour));

      final twice = notificationInstant(DateTime(2026, 10, 25, 2, 30));
      expect(twice.day, 25);
      expect(twice.hour, 2);
      // Either the first (UTC 00:30) or the second (UTC 01:30) 02:30, never an hour elsewhere.
      expect([0, 1], contains(twice.toUtc().hour));
    });

    test('a notification planned for a skipped time is still scheduled, once', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'gap',
            petName: 'Moka',
            title: 'Pastiglia',
            kind: EventKind.spot,
            dueAt: DateTime(2026, 3, 29, 2, 30),
          ),
        ],
        pets: const [],
        now: DateTime(2026, 3, 28, 12),
      );

      expect(plan.where((n) => n.payload == 'reminder:gap'), hasLength(1));
    });
  });
}
