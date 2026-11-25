import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/reminders/application/reminder_completion_service.dart';
import 'package:vet_app_mobile/features/reminders/data/reminder_postponement_store.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_category.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_completion.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_postponement.dart';
import 'package:vet_app_mobile/features/reminders/presentation/reminder_completion_prompter.dart';

ReminderEntry _reminder(
  String id, {
  DateTime? due,
  ReminderCategory category = ReminderCategory.vaccine,
}) =>
    ReminderEntry(
      id: id,
      petName: 'Moka',
      title: 'Richiamo vaccinale',
      kind: EventKind.spot,
      dueAt: due ?? DateTime(2026, 10, 21, 9),
      category: category,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the moments offered', () {
    List<(PostponeChoice, DateTime)> choices(DateTime now) =>
        [for (final option in postponeChoices(now)) (option.choice, option.at)];

    test('in an hour, this evening, tomorrow morning', () {
      expect(choices(DateTime(2026, 10, 21, 14, 23, 40)), [
        (PostponeChoice.oneHour, DateTime(2026, 10, 21, 15, 23)),
        (PostponeChoice.evening, DateTime(2026, 10, 21, 19)),
        (PostponeChoice.tomorrowMorning, DateTime(2026, 10, 22, 9)),
      ]);
    });

    test('this evening only while it is ahead', () {
      expect(choices(DateTime(2026, 10, 21, 18, 59, 59)).map((c) => c.$1),
          contains(PostponeChoice.evening));
      expect(choices(DateTime(2026, 10, 21, 19)).map((c) => c.$1),
          [PostponeChoice.oneHour, PostponeChoice.tomorrowMorning]);
    });

    test('an hour late at night is the next day; the month and the year roll over', () {
      expect(choices(DateTime(2026, 12, 31, 23, 30)), [
        (PostponeChoice.oneHour, DateTime(2027, 1, 1, 0, 30)),
        (PostponeChoice.tomorrowMorning, DateTime(2027, 1, 1, 9)),
      ]);
    });

    test('tomorrow morning stays at nine across the change of the clocks', () {
      // 25 October 2026: the clocks go back. 29 March 2026: forward.
      expect(postponeMoment(PostponeChoice.tomorrowMorning, DateTime(2026, 10, 24, 20)),
          DateTime(2026, 10, 25, 9));
      expect(postponeMoment(PostponeChoice.tomorrowMorning, DateTime(2026, 3, 28, 20)),
          DateTime(2026, 3, 29, 9));
    });

    test('whatever the hour, nothing offered is in the past', () {
      for (var minute = 0; minute < 24 * 60; minute += 7) {
        final now = DateTime(2026, 10, 21, 0, minute, 59);
        for (final option in postponeChoices(now)) {
          expect(option.at.isAfter(now), isTrue, reason: '${option.choice} at $now');
        }
      }
    });
  });

  group('what is kept on the phone', () {
    final store = ReminderPostponementStore.instance;
    final now = DateTime(2026, 10, 21, 12);

    test('a postponement outlives the app: it is read back from the disk', () async {
      final reminder = _reminder('kept');
      await store.save(reminder, DateTime(2026, 10, 21, 19), now: now);

      final disk = await SharedPreferences.getInstance();
      expect(disk.getString(ReminderPostponementStore.storageKey), contains('reminder-kept-20261021'));
      expect(await store.load(reminder), DateTime(2026, 10, 21, 19));
      expect(await store.forReminders([reminder, _reminder('other')]),
          {'kept': DateTime(2026, 10, 21, 19)});
    });

    test('nothing personal is written: the reminder id, its day and the moment', () async {
      await store.save(_reminder('private'), DateTime(2026, 10, 21, 19), now: now);

      final disk = await SharedPreferences.getInstance();
      final raw = disk.getString(ReminderPostponementStore.storageKey)!;
      expect(raw, isNot(contains('Moka')));
      expect(raw, isNot(contains('Richiamo')));
    });

    test('moving the reminder to another day drops it', () async {
      await store.save(_reminder('moved'), DateTime(2026, 10, 21, 19), now: now);

      final moved = _reminder('moved', due: DateTime(2026, 10, 30, 9));
      expect(await store.load(moved), isNull);
      expect(await store.forReminders([moved]), isEmpty);
    });

    test('forgetting one leaves the others; sign-out empties it all', () async {
      final a = _reminder('a');
      final b = _reminder('b');
      await store.save(a, DateTime(2026, 10, 21, 19), now: now);
      await store.save(b, DateTime(2026, 10, 22, 9), now: now);

      await store.forget(a);
      expect(await store.load(a), isNull);
      expect(await store.load(b), DateTime(2026, 10, 22, 9));

      await store.clear();
      expect(await store.load(b), isNull);
      expect((await SharedPreferences.getInstance()).containsKey(ReminderPostponementStore.storageKey),
          isFalse);
    });

    test('postponements too old to matter go away on the next one', () async {
      final old = _reminder('old', due: DateTime(2026, 9, 1, 9));
      await store.save(old, DateTime(2026, 9, 1, 19), now: DateTime(2026, 9, 1, 12));
      await store.save(_reminder('new'), DateTime(2026, 10, 21, 19), now: now);

      expect(await store.load(old), isNull);
      expect(await store.load(_reminder('new')), DateTime(2026, 10, 21, 19));
    });

    test('every change is announced (the notifications are planned again), no change is not',
        () async {
      final reminder = _reminder('told');
      var ticks = 0;
      void count() => ticks++;
      store.addListener(count);
      addTearDown(() => store.removeListener(count));

      await store.save(reminder, DateTime(2026, 10, 21, 19), now: now);
      expect(ticks, 1);
      await store.save(reminder, DateTime(2026, 10, 21, 19), now: now);
      expect(ticks, 1);
      await store.forget(reminder);
      await store.forget(reminder);
      expect(ticks, 2);
    });

    test('unreadable content counts as nothing postponed', () async {
      SharedPreferences.setMockInitialValues({ReminderPostponementStore.storageKey: '{broken'});
      expect(await store.load(_reminder('x')), isNull);

      await store.save(_reminder('x'), DateTime(2026, 10, 21, 19), now: now);
      expect(await store.load(_reminder('x')), DateTime(2026, 10, 21, 19));
    });
  });

  group('"Rimanda" and the reminder', () {
    test('neither its date nor its state change; answering later forgets the postponement',
        () async {
      final repository = RemindersRepository();
      final service = ReminderCompletionService(now: () => DateTime(2026, 10, 21, 12));
      final reminder = _reminder('untouched');
      await repository.saveReminder(reminder);

      await service.postpone(reminder, DateTime(2026, 10, 21, 13, 0, 40));

      final stored = (await repository.loadReminders()).firstWhere((r) => r.id == 'untouched');
      expect(stored.dueAt, DateTime(2026, 10, 21, 9));
      expect(stored.isDone, isFalse);
      // To the minute, like the notification.
      expect(await service.postponedUntil(reminder), DateTime(2026, 10, 21, 13));

      await service.dismiss(reminder);
      expect(await service.postponedUntil(reminder), isNull);
    });
  });

  group('the question in the app', () {
    test('comes back at the chosen moment, not before, even weeks after the due date', () {
      final reminder = _reminder('weeks');
      final until = DateTime(2026, 11, 15, 18);

      expect(shouldAutoPrompt(reminder, DateTime(2026, 11, 15, 17, 59), snoozedUntil: until), isFalse);
      expect(shouldAutoPrompt(reminder, until, snoozedUntil: until), isTrue);
      expect(shouldAutoPrompt(reminder, DateTime(2026, 11, 22, 10), snoozedUntil: until), isTrue);
      // Neglected again for more than a week: it no longer greets the owner.
      expect(shouldAutoPrompt(reminder, DateTime(2026, 11, 24, 10), snoozedUntil: until), isFalse);
    });

    test('comes back for a non-clinical or not yet due one too: the owner asked for it', () {
      final until = DateTime(2026, 10, 21, 13);
      final grooming = _reminder('grooming', category: ReminderCategory.grooming);
      final ahead = _reminder('ahead', due: DateTime(2026, 10, 25, 9));
      final at = DateTime(2026, 10, 21, 13, 5);

      expect(shouldAutoPrompt(grooming, at), isFalse);
      expect(shouldAutoPrompt(grooming, at, snoozedUntil: until), isTrue);
      expect(shouldAutoPrompt(ahead, at), isFalse);
      expect(shouldAutoPrompt(ahead, at, snoozedUntil: until), isTrue);
      expect(shouldAutoPrompt(ahead.copyWith(isDone: true), at, snoozedUntil: until), isFalse);
    });

    test('an old postponement does not silence the due date of a reminder set far ahead', () {
      final reminder = _reminder('far', due: DateTime(2026, 11, 20, 9));
      expect(
        shouldAutoPrompt(reminder, DateTime(2026, 11, 20, 10), snoozedUntil: DateTime(2026, 10, 21, 13)),
        isTrue,
      );
    });

    test('comes back in the same run of the app, once, and again if postponed again', () async {
      var now = DateTime(2026, 10, 21, 12);
      final service = ReminderCompletionService(now: () => now);
      final reminder = _reminder('same-run', due: DateTime(2026, 10, 21, 9));
      DateTime? postponeTo;
      var asked = 0;
      final prompter = ReminderCompletionPrompter(
        repository: _FixedReminders([reminder]),
        service: service,
        loadPets: () async => const [],
        now: () => now,
        ask: (reminder) async {
          asked++;
          final until = postponeTo;
          if (until != null) await service.postpone(reminder, until);
          return false;
        },
      );

      postponeTo = DateTime(2026, 10, 21, 13);
      await prompter.checkDue();
      expect(asked, 1);

      now = DateTime(2026, 10, 21, 12, 59);
      await prompter.checkDue();
      expect(asked, 1, reason: 'not before');

      now = DateTime(2026, 10, 21, 13, 1);
      postponeTo = DateTime(2026, 10, 21, 19);
      await prompter.checkDue();
      expect(asked, 2, reason: 'the chosen moment came, the app was never closed');

      now = DateTime(2026, 10, 21, 19, 1);
      postponeTo = null;
      await prompter.checkDue();
      expect(asked, 3, reason: 'postponed a second time');

      // Closed without an answer: not again at every return to the app.
      await prompter.checkDue();
      expect(asked, 3);
    });

    test('tapping the notification asks before the chosen moment too', () async {
      final service = ReminderCompletionService(now: () => DateTime(2026, 10, 21, 12));
      final reminder = _reminder('tapped');
      await service.postpone(reminder, DateTime(2026, 10, 21, 19));
      final asked = <String>[];
      final prompter = ReminderCompletionPrompter(
        repository: _FixedReminders([reminder]),
        service: service,
        loadPets: () async => const [],
        now: () => DateTime(2026, 10, 21, 12),
        ask: (reminder) async {
          asked.add(reminder.id);
          return false;
        },
      );

      await prompter.promptFor('tapped');
      expect(asked, ['tapped']);
    });
  });
}

class _FixedReminders extends RemindersRepository {
  _FixedReminders(this._reminders);

  final List<ReminderEntry> _reminders;

  @override
  Future<List<ReminderEntry>> loadReminders() async => _reminders;
}
