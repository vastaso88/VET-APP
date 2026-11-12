import 'package:flutter_test/flutter_test.dart';

import 'package:vet_app_mobile/features/notifications/application/notification_taps.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

void main() {
  final taps = NotificationTaps.instance;

  setUp(taps.take);

  test('only the notification that arrives when a reminder is due carries its id', () {
    final plan = planNotifications(
      reminders: [
        ReminderEntry(
          id: 'abc',
          petName: 'Moka',
          title: 'Richiamo',
          kind: EventKind.spot,
          dueAt: DateTime(2026, 10, 30, 9),
        ),
        ReminderEntry(
          id: 'cure',
          petName: 'Moka',
          title: 'Antibiotico',
          kind: EventKind.course,
          dueAt: DateTime(2026, 10, 25),
          courseDurationDays: 2,
          doseTimes: const ['08:00'],
        ),
      ],
      pets: const [],
      now: DateTime(2026, 10, 21, 10),
    );

    final withPayload = plan.where((n) => n.payload != null).toList();
    expect(withPayload, hasLength(1));
    expect(withPayload.single.payload, 'reminder:abc');
    expect(withPayload.single.at, DateTime(2026, 10, 30, 9));
    // The evening-before heads-up and the medicine doses open the app only.
    expect(plan.where((n) => n.payload == null), isNotEmpty);
  });

  test('a tap on a reminder notification is kept until the shell takes it, once', () {
    taps.add('reminder:abc');

    expect(taps.pendingReminderId.value, 'abc');
    expect(taps.take(), 'abc');
    expect(taps.take(), isNull);
  });

  test('other payloads are ignored', () {
    taps.add(null);
    taps.add('birthday:moka');
    taps.add('reminder:');

    expect(taps.pendingReminderId.value, isNull);
  });
}
