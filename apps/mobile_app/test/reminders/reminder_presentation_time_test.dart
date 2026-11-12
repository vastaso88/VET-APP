import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/clock_time.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_presentation.dart';

void main() {
  final now = DateTime(2026, 10, 7, 10);

  ReminderEntry spot(DateTime at) =>
      ReminderEntry(id: 'r', petName: 'Moka', title: 'Visita', kind: EventKind.spot, dueAt: at);

  test('a reminder with a time shows it next to the day', () {
    final label = ReminderPresentation.of(spot(DateTime(2026, 10, 8, 15, 30)), now: now).dateLabel;
    expect(label, endsWith(' · 15:30'));
  });

  test('a date-only reminder shows just the day', () {
    final label = ReminderPresentation.of(spot(DateTime(2026, 10, 8)), now: now).dateLabel;
    expect(label, isNot(contains('·')));
  });

  test('a course lists its dose times', () {
    final course = ReminderEntry(
      id: 'c',
      petName: 'Moka',
      title: 'Antibiotico',
      kind: EventKind.course,
      dueAt: DateTime(2026, 10, 8),
      courseDurationDays: 90,
      doseTimes: const ['08:00', '20:00'],
    );
    expect(ReminderPresentation.of(course, now: now).kindLabel,
        'Ciclo · 90 giorni · 08:00, 20:00');
  });

  test('clock times round-trip and reject nonsense', () {
    expect(formatClockTime(8, 5), '08:05');
    expect(parseClockTime('20:00'), (hour: 20, minute: 0));
    expect(parseClockTime('24:00'), isNull);
    expect(parseClockTime('8'), isNull);
  });
}
