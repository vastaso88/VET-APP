import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/events/data/events_repository.dart';
import 'package:vet_app_mobile/features/events/domain/event_entry.dart';
import 'package:vet_app_mobile/features/events/domain/event_filter.dart';
import 'package:vet_app_mobile/features/events/presentation/pages/events_page.dart';

import 'package:vet_app_mobile/features/territory/domain/territory.dart';

import '../territory/territory_test_helpers.dart';

EventEntry _event(String id, String country, {String region = 'Lombardia'}) => EventEntry(
      id: id,
      title: 'Event $id',
      eventType: 'pet_fair',
      level: EventLevel.regional,
      startsOn: DateTime(2026, 10, 17),
      endsOn: DateTime(2026, 10, 17),
      country: country,
      region: region,
    );

Map<String, dynamic> _row({Map<String, dynamic> overrides = const {}}) => {
      'id': 'e1',
      'title': 'Pet Expo',
      'starts_on': '2026-10-17',
      'ends_on': '2026-10-18',
      ...overrides,
    };

class _FakeRepository extends EventsRepository {
  _FakeRepository(this.events);

  final List<EventEntry> events;
  String? askedCountry;

  @override
  Future<EventsLoadResult> loadEvents({
    required DateTime from,
    required DateTime to,
    String? country,
  }) async {
    askedCountry = country;
    return EventsLoadResult(events: filterEventsByCountry(events, country ?? currentTerritory().countryCode));
  }
}

void main() {
  tearDown(resetTerritoryForTest);

  group('country of an event', () {
    test('a row without the column is an Italian event', () {
      expect(parseEventRow(_row())!.country, 'IT');
    });

    test('the country is read and normalised to upper case', () {
      expect(parseEventRow(_row(overrides: {'country': 'gb'}))!.country, 'GB');
      expect(parseEventRow(_row(overrides: {'country': ' AU '}))!.country, 'AU');
    });

    test('only the events of the asked country are kept', () {
      final events = [_event('a', 'IT'), _event('b', 'DE', region: 'Bayern'), _event('c', 'gb')];

      expect(filterEventsByCountry(events, 'IT').map((e) => e.id), ['a']);
      expect(filterEventsByCountry(events, 'de').map((e) => e.id), ['b']);
      expect(filterEventsByCountry(events, 'GB').map((e) => e.id), ['c']);
      expect(filterEventsByCountry(events, 'FR'), isEmpty,
          reason: 'no fallback to another country when the own one has nothing');
    });

    test('regions on offer are those of the events of the country', () {
      final german = filterEventsByCountry(
        [_event('a', 'IT'), _event('b', 'DE', region: 'Bayern'), _event('c', 'DE', region: 'Hessen')],
        'DE',
      );
      expect(availableRegions(german), ['Bayern', 'Hessen']);
    });
  });

  group('events page', () {
    Future<void> pump(WidgetTester tester, EventsRepository repository) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EventsPage(repository: repository, now: () => DateTime(2026, 10, 14)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a country with no events says it shows only the own country', (tester) async {
      await useLanguageVariant('en-AU');
      final repository = _FakeRepository([_event('a', 'IT'), _event('b', 'GB')]);
      await pump(tester, repository);

      expect(find.text('Event a'), findsNothing);
      expect(find.text('Event b'), findsNothing);
      expect(find.text('No events in the next 30 days'), findsOneWidget);
      expect(find.textContaining('only show events from your country'), findsOneWidget);
    });

    testWidgets('the events of the own country are listed', (tester) async {
      await useLanguageVariant('it');
      final repository = _FakeRepository([_event('a', 'IT'), _event('b', 'GB')]);
      await pump(tester, repository);

      expect(find.text('Event a'), findsOneWidget);
      expect(find.text('Event b'), findsNothing);
    });
  });
}
