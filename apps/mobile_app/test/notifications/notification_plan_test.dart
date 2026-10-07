import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_time_zone.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

import 'notification_test_data.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  group('nextBirthday', () {
    test('later this year, today included', () {
      expect(nextBirthday(DateTime(2020, 12, 1), DateTime(2026, 10, 7)), DateTime(2026, 12, 1));
      expect(nextBirthday(DateTime(2020, 10, 7), DateTime(2026, 10, 7)), DateTime(2026, 10, 7));
    });

    test('already passed this year: next year', () {
      expect(nextBirthday(DateTime(2020, 3, 5), DateTime(2026, 10, 7)), DateTime(2027, 3, 5));
    });

    test('29 February: 28 February in common years, 29 in leap years', () {
      final birth = DateTime(2020, 2, 29);
      expect(nextBirthday(birth, DateTime(2026, 10, 7)), DateTime(2027, 2, 28));
      expect(nextBirthday(birth, DateTime(2027, 3, 1)), DateTime(2028, 2, 29));
      expect(nextBirthday(birth, DateTime(2027, 2, 28)), DateTime(2027, 2, 28));
    });
  });

  group('birthdays', () {
    List<PlannedNotification> birthdayPlan(String label, {DateTime? at}) => planNotifications(
          reminders: const [],
          pets: [testPet('Moka', birth: label)],
          now: at ?? now,
        );

    test('the day itself at 09:00 and a week before, with the name and age', () {
      final plan = birthdayPlan('20 ott 2021');
      expect(plan.map((n) => n.at), [DateTime(2026, 10, 13, 9), DateTime(2026, 10, 20, 9)]);
      expect(plan[0].body, 'Tra una settimana è il compleanno di Moka: pensa a un regalo.');
      expect(plan[1].title, 'Buon compleanno, Moka!');
      expect(plan[1].body, 'Oggi compie 5 anni.');
      expect(plan.every((n) => n.category == NotificationCategory.birthdays), isTrue);
    });

    test('birthday within the week: heads-up moves to next year', () {
      final plan = birthdayPlan('10 ott 2021');
      expect(plan.map((n) => n.at), [DateTime(2026, 10, 10, 9), DateTime(2027, 10, 3, 9)]);
    });

    test('a 29 February pet is wished on 28 February, heads-up on 21', () {
      final plan = birthdayPlan('29 feb 2024', at: DateTime(2027, 2, 1));
      expect(plan.map((n) => n.at), [DateTime(2027, 2, 21, 9), DateTime(2027, 2, 28, 9)]);
    });

    test('no birthday without the day, nor for memorial pets', () {
      expect(birthdayPlan('ott 2021'), isEmpty);
      expect(birthdayPlan('2021'), isEmpty);
      expect(birthdayPlan(''), isEmpty);
      expect(
        planNotifications(
          reminders: const [],
          pets: [testPet('Rex', birth: '20 ott 2021', memorial: true)],
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('visits and vaccines', () {
    test('at the reminder time and the evening before', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'r1',
            petName: 'Moka',
            title: 'Vaccino',
            kind: EventKind.spot,
            dueAt: DateTime(2026, 10, 9, 15, 30),
          ),
        ],
        pets: const [],
        now: now,
      );
      expect(plan.map((n) => n.at), [DateTime(2026, 10, 8, 18), DateTime(2026, 10, 9, 15, 30)]);
      expect(plan[0].title, 'Domani: Vaccino');
      expect(plan[0].body, 'Moka · alle 15:30');
      expect(plan[1].body, 'Moka · oggi alle 15:30');
    });

    test('a date-only reminder (midnight) is notified at 09:00', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'r1',
            petName: 'Moka',
            title: 'Visita',
            kind: EventKind.spot,
            dueAt: DateTime(2026, 10, 9),
          ),
        ],
        pets: const [],
        now: now,
      );
      expect(plan.last.at, DateTime(2026, 10, 9, 9));
    });

    test('done reminders and past times are skipped', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'done',
            petName: 'Moka',
            title: 'Fatto',
            kind: EventKind.spot,
            dueAt: DateTime(2026, 10, 9, 9),
            isDone: true,
          ),
          ReminderEntry(
            id: 'past',
            petName: 'Moka',
            title: 'Passato',
            kind: EventKind.spot,
            dueAt: DateTime(2026, 10, 7, 9),
          ),
        ],
        pets: const [],
        now: now,
      );
      expect(plan, isEmpty);
    });
  });

  group('recurrences', () {
    ReminderEntry recurring({
      required IntervalUnit unit,
      required int every,
      required DateTime dueAt,
      RecurrenceEnd end = RecurrenceEnd.never,
      int? count,
      DateTime? endDate,
    }) {
      return ReminderEntry(
        id: 'rec',
        petName: 'Oliver',
        title: 'Antiparassitario',
        kind: EventKind.recurring,
        dueAt: dueAt,
        intervalUnit: unit,
        intervalValue: every,
        recurrenceEnd: end,
        occurrenceCount: count,
        recurrenceEndDate: endDate,
      );
    }

    test('every N days, up to the horizon', () {
      final occurrences = reminderOccurrences(
        recurring(unit: IntervalUnit.days, every: 20, dueAt: DateTime(2026, 10, 8, 9)),
        DateTime(2026, 12, 6),
      );
      expect(occurrences, [
        DateTime(2026, 10, 8, 9),
        DateTime(2026, 10, 28, 9),
        DateTime(2026, 11, 17, 9),
      ]);
    });

    test('monthly from the 31st stays on the last day of shorter months', () {
      final occurrences = reminderOccurrences(
        recurring(unit: IntervalUnit.months, every: 1, dueAt: DateTime(2027, 1, 31, 9)),
        DateTime(2027, 4, 30, 23),
      );
      expect(occurrences, [
        DateTime(2027, 1, 31, 9),
        DateTime(2027, 2, 28, 9),
        DateTime(2027, 3, 31, 9),
        DateTime(2027, 4, 30, 9),
      ]);
    });

    test('ends after N occurrences or on the last date', () {
      final until = DateTime(2027, 12, 31);
      expect(
        reminderOccurrences(
          recurring(
              unit: IntervalUnit.days, every: 1, dueAt: DateTime(2026, 10, 8, 8),
              end: RecurrenceEnd.afterOccurrences, count: 3),
          until,
        ).length,
        3,
      );
      expect(
        reminderOccurrences(
          recurring(
              unit: IntervalUnit.days, every: 1, dueAt: DateTime(2026, 10, 8, 8),
              end: RecurrenceEnd.onDate, endDate: DateTime(2026, 10, 10)),
          until,
        ).last,
        DateTime(2026, 10, 10, 8),
      );
    });

    test('a daily time does not shift across the summer-time change', () {
      final occurrences = reminderOccurrences(
        recurring(unit: IntervalUnit.days, every: 1, dueAt: DateTime(2026, 10, 24, 8)),
        DateTime(2026, 10, 26, 23),
      );
      expect(occurrences.map((at) => at.hour), [8, 8, 8]);
    });
  });

  group('medicines', () {
    test('every dose time on every day of the course', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'c1',
            petName: 'Moka',
            title: 'Antibiotico',
            kind: EventKind.course,
            dueAt: DateTime(2026, 10, 8),
            courseDurationDays: 2,
            doseTimes: const ['08:00', '20:00'],
          ),
        ],
        pets: const [],
        now: now,
      );
      expect(plan.map((n) => n.at), [
        DateTime(2026, 10, 8, 8),
        DateTime(2026, 10, 8, 20),
        DateTime(2026, 10, 9, 8),
        DateTime(2026, 10, 9, 20),
      ]);
      expect(plan.first.title, 'Farmaco per Moka');
      expect(plan.first.body, 'Antibiotico · dose delle 08:00');
      expect(plan.every((n) => n.category == NotificationCategory.medicines), isTrue);
    });

    test('a course already started only keeps the doses still ahead', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'c1',
            petName: 'Moka',
            title: 'Antibiotico',
            kind: EventKind.course,
            dueAt: DateTime(2026, 10, 6),
            courseDurationDays: 3,
            doseTimes: const ['08:00', '20:00'],
          ),
        ],
        pets: const [],
        now: now,
      );
      expect(plan.map((n) => n.at), [
        DateTime(2026, 10, 7, 20),
        DateTime(2026, 10, 8, 8),
        DateTime(2026, 10, 8, 20),
      ]);
    });

    test('no dose times: one a day at 09:00 with the day count', () {
      final plan = planNotifications(
        reminders: [
          ReminderEntry(
            id: 'c1',
            petName: 'Moka',
            title: 'Collirio',
            kind: EventKind.course,
            dueAt: DateTime(2026, 10, 8),
            courseDurationDays: 2,
          ),
        ],
        pets: const [],
        now: now,
      );
      expect(plan.map((n) => n.at), [DateTime(2026, 10, 8, 9), DateTime(2026, 10, 9, 9)]);
      expect(plan.last.body, 'Collirio · giorno 2 di 2');
    });
  });

  test('switched-off categories are left out, the cap keeps the earliest', () {
    final reminders = [
      ReminderEntry(
        id: 'c1',
        petName: 'Moka',
        title: 'Antibiotico',
        kind: EventKind.course,
        dueAt: DateTime(2026, 10, 8),
        courseDurationDays: 30,
        doseTimes: const ['08:00', '20:00'],
      ),
      ReminderEntry(
        id: 'r1',
        petName: 'Moka',
        title: 'Vaccino',
        kind: EventKind.spot,
        dueAt: DateTime(2026, 10, 9, 9),
      ),
    ];
    final noMedicines = planNotifications(
      reminders: reminders,
      pets: const [],
      now: now,
      preferences: const NotificationPreferences(medicines: false),
    );
    expect(noMedicines.map((n) => n.category).toSet(), {NotificationCategory.reminders});

    final capped = planNotifications(reminders: reminders, pets: const [], now: now, maxCount: 5);
    expect(capped.length, 5);
    expect(capped.last.at, DateTime(2026, 10, 9, 9));
  });

  group('time zone', () {
    test('wall-clock times are Italian times, summer and winter', () {
      final summer = notificationInstant(DateTime(2026, 10, 24, 8));
      final winter = notificationInstant(DateTime(2026, 10, 26, 8));
      expect(summer.hour, 8);
      expect(winter.hour, 8);
      expect(summer.toUtc().hour, 6);
      expect(winter.toUtc().hour, 7);
    });
  });
}
