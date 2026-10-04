import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vet_app_mobile/features/events/data/events_repository.dart';
import 'package:vet_app_mobile/features/events/domain/event_entry.dart';
import 'package:vet_app_mobile/features/events/presentation/event_labels.dart';
import 'package:vet_app_mobile/features/events/presentation/pages/events_page.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';

class _FakeRepository extends EventsRepository {
  _FakeRepository(this._handler);

  final Future<EventsLoadResult> Function(DateTime from, DateTime to) _handler;
  final List<(DateTime, DateTime)> calls = [];

  @override
  Future<EventsLoadResult> loadEvents({required DateTime from, required DateTime to}) {
    calls.add((from, to));
    return _handler(from, to);
  }
}

EventEntry _event(
  String id,
  String title, {
  String? sourceUrl,
  String region = 'Lombardia',
  String city = 'Cremona',
  String eventType = 'pet_fair',
  EventLevel level = EventLevel.national,
  EventStatus status = EventStatus.published,
  DateTime? startsOn,
}) {
  final start = startsOn ?? DateTime(2026, 10, 17);
  return EventEntry(
    id: id,
    title: title,
    eventType: eventType,
    level: level,
    startsOn: start,
    endsOn: start,
    city: city,
    provinceCode: 'CR',
    region: region,
    sourceUrl: sourceUrl,
    status: status,
  );
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository, {
  List<Uri>? launched,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EventsPage(
        repository: repository,
        now: () => DateTime(2026, 10, 4, 15),
        launcher: (url) async => launched?.add(url),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('shows the PetLoader while loading, then the events', (tester) async {
    final completer = Completer<EventsLoadResult>();
    final repository = _FakeRepository((_, __) => completer.future);

    await _pump(tester, repository);
    expect(find.byType(PetLoader), findsOneWidget);

    completer.complete(EventsLoadResult(events: [_event('a', 'Petsfestival')]));
    await tester.pumpAndSettle();

    expect(find.byType(PetLoader), findsNothing);
    expect(find.text('Petsfestival'), findsOneWidget);
  });

  testWidgets('opens on the next-30-days window', (tester) async {
    final repository = _FakeRepository((_, __) async => const EventsLoadResult(events: []));

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.calls.single, (DateTime(2026, 10, 4), DateTime(2026, 11, 3)));
    expect(find.text('Prossimi 30 giorni'), findsOneWidget);
  });

  testWidgets('shows an honest empty state naming the 30 days', (tester) async {
    final repository = _FakeRepository((_, __) async => const EventsLoadResult(events: []));

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Nessun evento nei prossimi 30 giorni'), findsOneWidget);
  });

  testWidgets('a failed load is not shown as an empty list, and can be retried', (tester) async {
    var attempts = 0;
    final repository = _FakeRepository((_, __) async {
      attempts++;
      return attempts == 1
          ? const EventsLoadResult(events: [], failed: true)
          : EventsLoadResult(events: [_event('a', 'Petsfestival')]);
    });

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.textContaining('Non riesco a caricare gli eventi'), findsOneWidget);
    expect(find.textContaining('Nessun evento'), findsNothing);

    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();

    expect(find.text('Petsfestival'), findsOneWidget);
  });

  testWidgets('a card shows city with province in evidence, region, type and level', (tester) async {
    final repository = _FakeRepository(
      (_, __) async => EventsLoadResult(events: [_event('a', 'Petsfestival')]),
    );

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('17 ott 2026'), findsOneWidget);
    expect(find.textContaining('Cremona (CR)', findRichText: true), findsOneWidget);
    expect(find.textContaining('Lombardia', findRichText: true), findsWidgets);
    expect(find.text('Fiera per animali'), findsOneWidget);
    expect(find.text('Nazionale'), findsOneWidget);
  });

  testWidgets('tapping a card with a link opens exactly that link', (tester) async {
    final launched = <Uri>[];
    final repository = _FakeRepository(
      (_, __) async => EventsLoadResult(
        events: [_event('a', 'Petsfestival', sourceUrl: 'https://www.petsfestival.eu/')],
      ),
    );

    await _pump(tester, repository, launched: launched);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petsfestival'));
    await tester.pump();

    expect(launched, [Uri.parse('https://www.petsfestival.eu/')]);
  });

  testWidgets('tapping a card without a link does nothing', (tester) async {
    final launched = <Uri>[];
    final repository = _FakeRepository(
      (_, __) async => EventsLoadResult(events: [_event('a', 'Petsfestival')]),
    );

    await _pump(tester, repository, launched: launched);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petsfestival'));
    await tester.pump();

    expect(launched, isEmpty);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
  });

  testWidgets('a cancelled event is labelled as such', (tester) async {
    final repository = _FakeRepository(
      (_, __) async => EventsLoadResult(
        events: [_event('a', 'Petsfestival', status: EventStatus.cancelled)],
      ),
    );

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Annullato'), findsOneWidget);
  });

  testWidgets('the region filter narrows the list and offers only regions present', (tester) async {
    final repository = _FakeRepository(
      (_, __) async => EventsLoadResult(
        events: [
          _event('a', 'Fiera lombarda'),
          _event('b', 'Fiera piemontese', region: 'Piemonte', city: 'Torino'),
        ],
      ),
    );

    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Fiera lombarda'), findsOneWidget);
    expect(find.text('Fiera piemontese'), findsOneWidget);

    await tester.tap(find.text('Tutte le regioni'));
    await tester.pumpAndSettle();
    expect(find.text('Veneto'), findsNothing);
    await tester.tap(find.text('Piemonte').last);
    await tester.pumpAndSettle();

    expect(find.text('Fiera lombarda'), findsNothing);
    expect(find.text('Fiera piemontese'), findsOneWidget);
  });

  testWidgets('filters that match nothing say so, and "Reimposta" brings the list back', (tester) async {
    final repository = _FakeRepository(
      (_, __) async => EventsLoadResult(
        events: [
          _event('a', 'Fiera lombarda', eventType: 'pet_fair'),
          _event('b', 'Esposizione', eventType: 'dog_show', region: 'Piemonte', city: 'Torino'),
        ],
      ),
    );

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tutti i tipi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esposizione canina').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutte le regioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lombardia').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Nessun evento con questi filtri'), findsOneWidget);

    await tester.tap(find.text('Reimposta'));
    await tester.pumpAndSettle();

    expect(find.text('Fiera lombarda'), findsOneWidget);
    expect(find.text('Esposizione'), findsOneWidget);
  });

  group('labels', () {
    test('date ranges read naturally across month and year boundaries', () {
      expect(eventDateRangeLabel(DateTime(2026, 10, 17), DateTime(2026, 10, 17)), '17 ott 2026');
      expect(eventDateRangeLabel(DateTime(2026, 10, 17), DateTime(2026, 10, 18)), '17-18 ott 2026');
      expect(eventDateRangeLabel(DateTime(2026, 4, 30), DateTime(2026, 5, 3)), '30 apr - 3 mag 2026');
      expect(
        eventDateRangeLabel(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        '30 dic 2026 - 2 gen 2027',
      );
    });
  });
}
