import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/history_event.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_details.dart';
import 'package:vet_app_mobile/features/reminders/application/reminder_completion_service.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_category.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_completion.dart';
import 'package:vet_app_mobile/features/reminders/presentation/reminder_completion_prompter.dart';

final _now = DateTime(2026, 10, 21, 12);

ReminderEntry _reminder(
  String id, {
  String title = 'Richiamo vaccinale di Moka',
  EventKind kind = EventKind.spot,
  DateTime? due,
  ReminderCategory? category = ReminderCategory.vaccine,
  String? subtype,
  IntervalUnit? unit,
  int? every,
  RecurrenceEnd? end,
  int? count,
  DateTime? endDate,
  int? courseDays,
}) {
  return ReminderEntry(
    id: id,
    petName: 'Moka',
    title: title,
    kind: kind,
    dueAt: due ?? DateTime(2026, 10, 21, 9),
    intervalUnit: unit,
    intervalValue: every,
    recurrenceEnd: end,
    occurrenceCount: count,
    recurrenceEndDate: endDate,
    courseDurationDays: courseDays,
    category: category,
    subtype: subtype,
  );
}

Future<ReminderEntry> _stored(RemindersRepository repository, String id) async {
  final all = await repository.loadReminders();
  return all.firstWhere((reminder) => reminder.id == id);
}

List<MedicalRecordEntry> _recordsOf(String reminderId) => MedicalRecordsRepository.previewRecords
    .where((record) => record.id.startsWith('reminder-$reminderId-'))
    .toList();

void main() {
  late RemindersRepository reminders;
  late ReminderCompletionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reminders = RemindersRepository();
    service = ReminderCompletionService(now: () => _now);
  });

  group('confirm: the record goes into the Storico', () {
    test('a vaccine reminder becomes a vaccine entry with its title, date and notes', () async {
      final reminder = _reminder('conf-vaccine');
      await reminders.saveReminder(reminder);

      final record = await service.confirmDone(
        reminder,
        category: ReminderCategory.vaccine,
        eventDate: DateTime(2026, 10, 19),
        notes: ' Nessuna reazione ',
      );

      expect(record, isNotNull);
      final stored = _recordsOf('conf-vaccine').single;
      expect(stored.category, RecordCategory.vaccine);
      expect(stored.title, 'Richiamo vaccinale di Moka');
      expect(stored.petName, 'Moka');
      expect(stored.eventDate, DateTime(2026, 10, 19));
      expect(stored.notes, 'Nessuna reazione');
      expect(stored.id, 'reminder-conf-vaccine-20261021');
      // The reminder is finished.
      expect((await _stored(reminders, 'conf-vaccine')).isDone, isTrue);
    });

    test('category and type chosen in the sheet win over the reminder\'s own', () async {
      final reminder = _reminder('conf-exam', title: 'Controllo', category: ReminderCategory.visit);
      await reminders.saveReminder(reminder);

      await service.confirmDone(
        reminder,
        category: ReminderCategory.exam,
        subtype: 'blood',
        eventDate: DateTime(2026, 10, 21),
        title: 'Emocromo',
      );

      final stored = _recordsOf('conf-exam').single;
      expect(stored.category, RecordCategory.exam);
      expect(stored.subtype, 'blood');
      expect(stored.title, 'Emocromo');
    });

    test('a blank title falls back to the reminder\'s', () async {
      final reminder = _reminder('conf-blank');
      await reminders.saveReminder(reminder);

      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21), title: '  ');

      expect(_recordsOf('conf-blank').single.title, 'Richiamo vaccinale di Moka');
    });

    test('the entry shows up in the Storico with its category (and so in the counters and PDF)',
        () async {
      final reminder = _reminder('conf-history', category: ReminderCategory.therapy);
      await reminders.saveReminder(reminder);
      final before = MedicalRecordsRepository.changes.value;

      await service.confirmDone(reminder,
          category: ReminderCategory.therapy, eventDate: DateTime(2026, 10, 20));

      // The records list reloads on this notifier.
      expect(MedicalRecordsRepository.changes.value, greaterThan(before));
      final records = await MedicalRecordsRepository().loadRecords();
      final events = buildHistoryEvents(records: records, conditions: const []);
      final event = events.firstWhere((e) => e.id == 'record:reminder-conf-history-20261021');
      expect(event.category, RecordCategory.therapy);
      expect(event.date, DateTime(2026, 10, 20));
      // Per-category counters are a count over these same records.
      expect(records.where((r) => r.category == RecordCategory.therapy), contains(event.record));
    });

    test('confirming the same occurrence twice never makes a duplicate', () async {
      final reminder = _reminder('conf-twice');
      await reminders.saveReminder(reminder);

      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));
      // A retry after a failed second step, or a double tap, uses the same reminder again.
      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));

      expect(_recordsOf('conf-twice'), hasLength(1));
    });

    test('a non-clinical reminder is only ticked: no record', () async {
      final reminder = _reminder('conf-grooming', title: 'Toelettatura', category: ReminderCategory.grooming);
      await reminders.saveReminder(reminder);

      final record = await service.confirmDone(reminder,
          category: ReminderCategory.grooming, eventDate: DateTime(2026, 10, 21));

      expect(record, isNull);
      expect(_recordsOf('conf-grooming'), isEmpty);
      expect((await _stored(reminders, 'conf-grooming')).isDone, isTrue);
    });
  });

  group('"Non fatto" and "Rimanda"', () {
    test('"Non fatto" closes the occurrence and writes nothing', () async {
      final reminder = _reminder('skip-spot');
      await reminders.saveReminder(reminder);

      await service.dismiss(reminder);

      expect(_recordsOf('skip-spot'), isEmpty);
      expect((await _stored(reminders, 'skip-spot')).isDone, isTrue);
    });

    test('"Non fatto" on a repeating reminder moves to the next date, still no record', () async {
      final reminder = _reminder('skip-repeat',
          kind: EventKind.recurring, unit: IntervalUnit.days, every: 30, due: DateTime(2026, 10, 21, 9));
      await reminders.saveReminder(reminder);

      await service.dismiss(reminder);

      expect(_recordsOf('skip-repeat'), isEmpty);
      final stored = await _stored(reminders, 'skip-repeat');
      expect(stored.isDone, isFalse);
      expect(stored.dueAt, DateTime(2026, 11, 20, 9));
    });

    test('"Rimanda" changes nothing now and asks again tomorrow morning', () async {
      final reminder = _reminder('snooze');
      await reminders.saveReminder(reminder);

      await service.postpone(reminder);

      expect(_recordsOf('snooze'), isEmpty);
      final stored = await _stored(reminders, 'snooze');
      expect(stored.isDone, isFalse);
      final until = await service.postponedUntil(reminder);
      expect(until, DateTime(2026, 10, 22, 9));
      expect(shouldAutoPrompt(stored, _now, snoozedUntil: until), isFalse);
      expect(shouldAutoPrompt(stored, DateTime(2026, 10, 22, 9, 1), snoozedUntil: until), isTrue);
    });
  });

  group('repeating reminders move to the next date', () {
    test('confirming one occurrence advances the due date and keeps the series', () async {
      final reminder = _reminder('rep-days',
          kind: EventKind.recurring,
          unit: IntervalUnit.days,
          every: 30,
          end: RecurrenceEnd.afterOccurrences,
          count: 6,
          due: DateTime(2026, 10, 21, 9));
      await reminders.saveReminder(reminder);

      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));

      final stored = await _stored(reminders, 'rep-days');
      expect(stored.isDone, isFalse);
      expect(stored.dueAt, DateTime(2026, 11, 20, 9));
      expect(stored.occurrenceCount, 5);
      expect(stored.category, ReminderCategory.vaccine);
      expect(_recordsOf('rep-days').single.eventDate, DateTime(2026, 10, 21));
    });

    test('the next occurrence is a new record, not the same one', () async {
      var reminder = _reminder('rep-twice',
          kind: EventKind.recurring, unit: IntervalUnit.months, every: 1, due: DateTime(2026, 10, 21, 9));
      await reminders.saveReminder(reminder);
      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));

      reminder = await _stored(reminders, 'rep-twice');
      expect(reminder.dueAt, DateTime(2026, 11, 21, 9));
      final later = ReminderCompletionService(now: () => DateTime(2026, 11, 21, 10));
      await later.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 11, 21));

      expect(_recordsOf('rep-twice').map((r) => r.id),
          unorderedEquals(['reminder-rep-twice-20261021', 'reminder-rep-twice-20261121']));
    });

    test('the last occurrence of a limited series finishes the reminder', () async {
      final reminder = _reminder('rep-last',
          kind: EventKind.recurring,
          unit: IntervalUnit.days,
          every: 7,
          end: RecurrenceEnd.afterOccurrences,
          count: 1);
      await reminders.saveReminder(reminder);

      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));

      expect((await _stored(reminders, 'rep-last')).isDone, isTrue);
    });

    test('a series ending on a date stops after it', () {
      final reminder = _reminder('rep-until',
          kind: EventKind.recurring,
          unit: IntervalUnit.days,
          every: 10,
          end: RecurrenceEnd.onDate,
          endDate: DateTime(2026, 11, 5),
          due: DateTime(2026, 10, 21, 9));

      final next = advanceReminder(reminder, _now);
      expect(next.isDone, isFalse);
      expect(next.dueAt, DateTime(2026, 10, 31, 9));
      // 10 November is past the end date: the following step finishes it.
      expect(advanceReminder(next, DateTime(2026, 10, 31, 10)).isDone, isTrue);
    });

    test('one neglected for months jumps to the next date still ahead, no queue of questions', () {
      final reminder = _reminder('rep-late',
          kind: EventKind.recurring, unit: IntervalUnit.days, every: 30, due: DateTime(2026, 5, 1, 9));

      final next = advanceReminder(reminder, _now);

      expect(next.dueAt.isAfter(_now), isTrue);
      expect(next.dueAt.difference(_now).inDays, lessThan(31));
    });

    test('monthly: 31 January goes to the end of February', () {
      final reminder = _reminder('rep-month',
          kind: EventKind.recurring, unit: IntervalUnit.months, every: 1, due: DateTime(2027, 1, 31, 9));

      expect(nextDueAfter(reminder), DateTime(2027, 2, 28, 9));
    });

    test('a course ends with its last day: asked after it, record dated by the owner', () async {
      final course = _reminder('course',
          kind: EventKind.course,
          category: ReminderCategory.therapy,
          due: DateTime(2026, 10, 14, 8),
          courseDays: 7,
          title: 'Ciclo antibiotico');
      await reminders.saveReminder(course);

      expect(occurrenceDay(course), DateTime(2026, 10, 20));
      expect(completionDueAt(course), DateTime(2026, 10, 21));
      expect(isAwaitingConfirmation(course, DateTime(2026, 10, 20, 23)), isFalse);
      expect(isAwaitingConfirmation(course, _now), isTrue);

      await service.confirmDone(course,
          category: ReminderCategory.therapy, eventDate: DateTime(2026, 10, 20));

      final stored = _recordsOf('course').single;
      expect(stored.category, RecordCategory.therapy);
      expect(stored.id, 'reminder-course-20261020');
      expect((await _stored(reminders, 'course')).isDone, isTrue);
    });
  });

  group('deleting the entry', () {
    test('does not complete the reminder again on its own', () async {
      final reminder = _reminder('del-once',
          kind: EventKind.recurring, unit: IntervalUnit.days, every: 30, due: DateTime(2026, 10, 21, 9));
      await reminders.saveReminder(reminder);
      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));

      await MedicalRecordsRepository().deleteRecord('reminder-del-once-20261021');

      // Nothing watches the records: the reminder keeps its next date, still ahead.
      final stored = await _stored(reminders, 'del-once');
      expect(stored.dueAt, DateTime(2026, 11, 20, 9));
      expect(isAwaitingConfirmation(stored, _now), isFalse);
      expect(shouldAutoPrompt(stored, _now), isFalse);
      expect(_recordsOf('del-once'), isEmpty);
    });

    test('a finished one stays finished', () async {
      final reminder = _reminder('del-done');
      await reminders.saveReminder(reminder);
      await service.confirmDone(reminder,
          category: ReminderCategory.vaccine, eventDate: DateTime(2026, 10, 21));

      await MedicalRecordsRepository().deleteRecord('reminder-del-done-20261021');

      final stored = await _stored(reminders, 'del-done');
      expect(stored.isDone, isTrue);
      expect(isAwaitingConfirmation(stored, _now), isFalse);
    });
  });

  group('categories', () {
    test('the clinical ones are the record categories, grooming and other are not', () {
      expect(ReminderCategory.visit.recordCategory, RecordCategory.visit);
      expect(ReminderCategory.exam.recordCategory, RecordCategory.exam);
      expect(ReminderCategory.vaccine.recordCategory, RecordCategory.vaccine);
      expect(ReminderCategory.therapy.recordCategory, RecordCategory.therapy);
      expect(ReminderCategory.grooming.isClinical, isFalse);
      expect(ReminderCategory.other.isClinical, isFalse);
      // Same types as the cartella clinica.
      expect(ReminderCategory.exam.subtypes, RecordCategory.exam.subtypes);
      expect(ReminderCategory.grooming.subtypes, isEmpty);
    });

    test('keys round-trip; an unknown or missing one is no category', () {
      for (final category in ReminderCategory.values) {
        expect(ReminderCategory.tryFromKey(category.key), category);
      }
      expect(ReminderCategory.tryFromKey('nonsense'), isNull);
      expect(ReminderCategory.tryFromKey(null), isNull);
    });

    test('old reminders without a category get a prudent guess', () {
      ReminderCategory guess(String title, [EventKind kind = EventKind.spot]) =>
          legacyReminderCategory(title: title, kind: kind);

      expect(guess('Richiamo vaccinale di Moka'), ReminderCategory.vaccine);
      expect(guess('Visita dal dentista'), ReminderCategory.visit);
      expect(guess('Emocromo annuale'), ReminderCategory.exam);
      expect(guess('Antiparassitario'), ReminderCategory.therapy);
      // A bare "controllo" is not a vet visit.
      expect(guess('Controllo peso di Moka'), ReminderCategory.other);
      expect(guess('Compleanno del gatto'), ReminderCategory.other);
      expect(guess('Pappa speciale', EventKind.course), ReminderCategory.therapy);
      expect(_reminder('legacy', category: null, title: 'Controllo peso').effectiveCategory,
          ReminderCategory.other);
      expect(_reminder('legacy2', category: ReminderCategory.grooming, title: 'Visita').effectiveCategory,
          ReminderCategory.grooming);
    });

    test('no vaccines for fish, reptiles, amphibians, birds or rodents', () {
      bool offered(String species, [String? breed]) =>
          ReminderCategory.vaccine.isOfferedFor(species, breed: breed);

      expect(offered('Cane'), isTrue);
      expect(offered('Gatto'), isTrue);
      expect(offered('Piccoli mammiferi', 'Coniglio nano'), isTrue);
      expect(offered('Piccoli mammiferi', 'Furetto (Mustela putorius furo)'), isTrue);
      expect(offered('Altro', 'Cavallo'), isTrue);
      expect(offered('Pesce'), isFalse);
      expect(offered('Uccello'), isFalse);
      expect(offered('Rettili e anfibi', 'Tartaruga'), isFalse);
      expect(offered('Rettili e anfibi', 'Axolotl'), isFalse);
      expect(offered('Piccoli mammiferi', 'Criceto'), isFalse);
      expect(offered('Altro', 'Granchio'), isFalse);
      expect(offered('Altro', 'Gallina'), isFalse);
      // An animal we cannot place keeps the option.
      expect(offered('Altro', 'Qualcosa di strano'), isTrue);
      // The rule is the one in pet_details.dart, not a copy.
      expect(speciesHasVaccines('Pesce'), isFalse);
    });

    test('other categories are always offered, vaccine only where it makes sense', () {
      expect(ReminderCategory.offeredFor('Pesce'), isNot(contains(ReminderCategory.vaccine)));
      expect(ReminderCategory.offeredFor('Pesce'),
          containsAll([ReminderCategory.visit, ReminderCategory.exam, ReminderCategory.grooming]));
      expect(ReminderCategory.offeredFor('Cane'), ReminderCategory.values);
      // The record forms follow the same rule, and old entries stay visible.
      expect(RecordCategory.vaccine.isOfferedFor('Pesce'), isFalse);
      expect(RecordCategory.visit.isOfferedFor('Pesce'), isTrue);
      expect(RecordCategory.document.isOfferedFor('Uccello'), isTrue);
    });
  });

  group('asking on its own', () {
    Future<List<String>> run(
      List<ReminderEntry> due, {
      DateTime? at,
      ReminderCompletionService? withService,
    }) async {
      final asked = <String>[];
      final prompter = ReminderCompletionPrompter(
        repository: _FixedReminders(due),
        service: withService ?? service,
        now: () => at ?? _now,
        ask: (reminder) async {
          asked.add(reminder.id);
          return true;
        },
      );
      await prompter.checkDue();
      return asked;
    }

    test('asks about clinical reminders that fell due, not about others or future ones', () async {
      final asked = await run([
        _reminder('p-vaccine', due: DateTime(2026, 10, 21, 8)),
        _reminder('p-grooming', category: ReminderCategory.grooming, due: DateTime(2026, 10, 21, 8)),
        _reminder('p-future', due: DateTime(2026, 10, 25, 8)),
        _reminder('p-done', due: DateTime(2026, 10, 20, 8)).copyWith(isDone: true),
      ]);

      expect(asked, ['p-vaccine']);
    });

    test('a reminder neglected for weeks does not greet the owner with a question', () async {
      final asked = await run([_reminder('p-old', due: DateTime(2026, 9, 1, 9))]);

      expect(asked, isEmpty);
    });

    test('a postponed one is left alone until tomorrow morning', () async {
      final reminder = _reminder('p-postponed', due: DateTime(2026, 10, 21, 8));
      await service.postpone(reminder);

      expect(await run([reminder]), isEmpty);
      expect(await run([reminder], at: DateTime(2026, 10, 22, 9, 30)), ['p-postponed']);
    });

    test('at most two questions in one go', () async {
      final asked = await run([
        for (var i = 0; i < 5; i++) _reminder('p-many-$i', due: DateTime(2026, 10, 21, 8)),
      ]);

      expect(asked, hasLength(ReminderCompletionPrompter.maxAutoPrompts));
    });
  });
}

class _FixedReminders extends RemindersRepository {
  _FixedReminders(this._reminders);

  final List<ReminderEntry> _reminders;

  @override
  Future<List<ReminderEntry>> loadReminders() async => _reminders;
}
