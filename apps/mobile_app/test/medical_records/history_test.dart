import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/history_event.dart';
import 'package:vet_app_mobile/features/medical_records/domain/pet_condition.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pet_history_section.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

MedicalRecordEntry _record(
  String id,
  String title,
  RecordCategory category,
  DateTime? eventDate, {
  DateTime? createdOn,
}) => MedicalRecordEntry(
  id: id,
  petName: 'Moka',
  title: title,
  subtitle: '',
  meta: '',
  badge: '',
  detailSource: '',
  createdAt: '',
  category: category,
  eventDate: eventDate,
  createdOn: createdOn,
  timeline: const [],
);

PetConditionEntry _condition(String id, String name, DateTime? startedOn) =>
    PetConditionEntry(id: id, petId: 'pet-moka', name: name, startedOn: startedOn);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('history events', () {
    test('records sit on the day they happened, illnesses on the day they started', () {
      final events = buildHistoryEvents(
        records: [
          _record('v', 'Rabbia', RecordCategory.vaccine, DateTime(2026, 3, 12, 18, 30)),
          // No event date: the day it was added.
          _record('d', 'Referto', RecordCategory.document, null, createdOn: DateTime(2026, 3, 1, 9)),
        ],
        conditions: [_condition('c', 'Otite', DateTime(2026, 2, 20))],
      );

      expect(events.map((e) => e.title), ['Otite', 'Referto', 'Rabbia']);
      expect(events.map((e) => e.date), [
        DateTime(2026, 2, 20),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 12),
      ]);
      expect(events.first.isCondition, isTrue);
    });

    test('undated entries come first and two on one day keep a fixed order', () {
      final day = DateTime(2026, 5, 4);
      final events = buildHistoryEvents(
        records: [
          _record('b', 'Zeta', RecordCategory.therapy, day),
          _record('a', 'Alfa', RecordCategory.visit, day),
          _record('n', 'Senza data', RecordCategory.document, null),
        ],
        conditions: [_condition('c', 'Allergia', day)],
      );

      expect(events.map((e) => e.title), ['Senza data', 'Alfa', 'Zeta', 'Allergia']);
    });

    test('events are grouped per day and undated ones are left out', () {
      final events = buildHistoryEvents(
        records: [
          _record('a', 'Visita', RecordCategory.visit, DateTime(2026, 3, 12)),
          _record('b', 'Esame', RecordCategory.exam, DateTime(2026, 3, 12)),
          _record('c', 'Vaccino', RecordCategory.vaccine, DateTime(2026, 3, 13)),
          _record('d', 'Senza data', RecordCategory.document, null),
        ],
        conditions: const [],
      );

      final byDay = groupEventsByDay(events);

      expect(byDay.keys, [DateTime(2026, 3, 12), DateTime(2026, 3, 13)]);
      expect(byDay[DateTime(2026, 3, 12)]!.map((e) => e.title), ['Visita', 'Esame']);
    });

    test('the month grid starts on Monday and is whole weeks', () {
      // October 2026 starts on a Thursday and has 31 days.
      final cells = monthGridCells(DateTime(2026, 10, 17));

      expect(cells.length % 7, 0);
      expect(cells.take(3), everyElement(isNull));
      expect(cells[3], DateTime(2026, 10, 1));
      expect(cells.whereType<DateTime>().length, 31);
      expect(cells.whereType<DateTime>().last, DateTime(2026, 10, 31));
    });
  });

  group('Storico section', () {
    final events = buildHistoryEvents(
      records: [
        _record('v', 'Rabbia', RecordCategory.vaccine, DateTime(2026, 3, 12)),
        _record('e', 'Emocromo', RecordCategory.exam, DateTime(2026, 3, 12)),
        _record('t', 'Antibiotico', RecordCategory.therapy, DateTime(2026, 4, 2)),
      ],
      conditions: [_condition('c', 'Otite', DateTime(2026, 3, 20))],
    );

    Future<void> pumpSection(
      WidgetTester tester, {
      List<HistoryEvent>? shown,
      ValueChanged<HistoryEvent>? onOpen,
      VoidCallback? onExport,
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PetHistorySection(
                events: shown ?? events,
                onOpenEvent: onOpen ?? (_) {},
                onExport: onExport,
                now: () => DateTime(2026, 3, 25),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the current month and moves month by month', (tester) async {
      await pumpSection(tester);

      expect(find.text('Storico'), findsOneWidget);
      expect(find.text('Marzo 2026'), findsOneWidget);
      // 12 March: a vaccine and an exam; 20 March: an illness.
      expect(find.byIcon(Icons.vaccines_outlined), findsOneWidget);
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
      expect(find.byIcon(Icons.healing_outlined), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsNothing);

      await tester.tap(find.byTooltip('Mese successivo'));
      await tester.pump();
      expect(find.text('Aprile 2026'), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
      expect(find.byIcon(Icons.vaccines_outlined), findsNothing);

      await tester.tap(find.byTooltip('Mese precedente'));
      await tester.tap(find.byTooltip('Mese precedente'));
      await tester.pump();
      expect(find.text('Febbraio 2026'), findsOneWidget);
      expect(find.byIcon(Icons.healing_outlined), findsNothing);
    });

    testWidgets('a tap on a day lists its events and opens the one tapped', (tester) async {
      HistoryEvent? opened;
      await pumpSection(tester, onOpen: (event) => opened = event);

      expect(find.text('Rabbia'), findsNothing);
      await tester.tap(find.text('12'));
      await tester.pump();

      expect(find.text('Eventi del 12 mar 2026'), findsOneWidget);
      expect(find.text('Rabbia'), findsOneWidget);
      expect(find.text('Emocromo'), findsOneWidget);
      expect(find.text('Otite'), findsNothing);

      await tester.tap(find.text('Emocromo'));
      expect(opened?.record?.id, 'e');
    });

    testWidgets('a day with nothing on it says so', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.text('3'));
      await tester.pump();

      expect(find.text('Nessun evento in questo giorno'), findsOneWidget);
    });

    testWidgets('an illness opens from its start day', (tester) async {
      HistoryEvent? opened;
      await pumpSection(tester, onOpen: (event) => opened = event);

      await tester.tap(find.text('20'));
      await tester.pump();
      await tester.tap(find.text('Otite'));

      expect(opened?.isCondition, isTrue);
    });

    testWidgets('with no events it says so and offers the export only when given', (tester) async {
      await pumpSection(tester, shown: const []);
      expect(find.text('Nessun evento registrato'), findsOneWidget);
      expect(find.text('Invia storico'), findsNothing);

      var exported = 0;
      await pumpSection(tester, onExport: () => exported++);
      await tester.tap(find.text('Invia storico'));
      expect(exported, 1);
    });

    testWidgets('does not overflow on a small phone with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final crowded = buildHistoryEvents(
        records: [
          for (final category in RecordCategory.values)
            _record(category.key, 'Voce ${category.key}', category, DateTime(2026, 3, 12)),
        ],
        conditions: [_condition('c', 'Otite', DateTime(2026, 3, 12))],
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PetHistorySection(
                events: crowded,
                onOpenEvent: (_) {},
                onExport: () {},
                now: () => DateTime(2026, 3, 25),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('12'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Voce visit'), findsOneWidget);
    });
  });
}
