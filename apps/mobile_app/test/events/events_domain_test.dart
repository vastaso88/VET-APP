import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/events/data/events_repository.dart';
import 'package:vet_app_mobile/features/events/domain/event_entry.dart';
import 'package:vet_app_mobile/features/events/domain/event_filter.dart';

EventEntry _event(
  String id, {
  required DateTime startsOn,
  DateTime? endsOn,
  String eventType = 'pet_fair',
  String? region = 'Lombardia',
  String title = 'Evento',
  String? sourceUrl,
}) {
  return EventEntry(
    id: id,
    title: title,
    eventType: eventType,
    level: EventLevel.regional,
    startsOn: startsOn,
    endsOn: endsOn ?? startsOn,
    region: region,
    sourceUrl: sourceUrl,
  );
}

void main() {
  final today = DateTime(2026, 10, 4);

  group('EventFilter.defaultWindow', () {
    test('runs from today through the next 30 days, inclusive', () {
      final filter = EventFilter.defaultWindow(today);

      expect(filter.from, DateTime(2026, 10, 4));
      expect(filter.to, DateTime(2026, 11, 3));
      expect(filter.isDefaultWindow(today), isTrue);
    });

    test('is no longer the default once the dates are changed', () {
      final custom = EventFilter.defaultWindow(today).copyWith(to: DateTime(2026, 12, 31));

      expect(custom.isDefaultWindow(today), isFalse);
    });

    test('ignores the time of day of "today"', () {
      final filter = EventFilter.defaultWindow(DateTime(2026, 10, 4, 23, 59));

      expect(filter.from, DateTime(2026, 10, 4));
    });
  });

  group('eventOverlapsWindow', () {
    final from = DateTime(2026, 10, 4);
    final to = DateTime(2026, 11, 3);

    test('includes an event inside the window', () {
      expect(eventOverlapsWindow(_event('a', startsOn: DateTime(2026, 10, 17)), from, to), isTrue);
    });

    test('includes events on the very first and very last day', () {
      expect(eventOverlapsWindow(_event('a', startsOn: DateTime(2026, 10, 4)), from, to), isTrue);
      expect(eventOverlapsWindow(_event('b', startsOn: DateTime(2026, 11, 3)), from, to), isTrue);
    });

    test('excludes an event that ended yesterday or starts after the window', () {
      expect(eventOverlapsWindow(_event('a', startsOn: DateTime(2026, 10, 3)), from, to), isFalse);
      expect(eventOverlapsWindow(_event('b', startsOn: DateTime(2026, 11, 4)), from, to), isFalse);
    });

    test('includes a multi-day event already under way when the window opens', () {
      final underWay = _event('a', startsOn: DateTime(2026, 10, 2), endsOn: DateTime(2026, 10, 5));

      expect(eventOverlapsWindow(underWay, from, to), isTrue);
    });

    test('includes a long event that spans the whole window', () {
      final spanning = _event('a', startsOn: DateTime(2026, 9, 1), endsOn: DateTime(2026, 12, 1));

      expect(eventOverlapsWindow(spanning, from, to), isTrue);
    });
  });

  group('applyEventFilter', () {
    final events = [
      _event('late', startsOn: DateTime(2026, 10, 30), region: 'Piemonte', eventType: 'dog_show', title: 'B'),
      _event('soon-b', startsOn: DateTime(2026, 10, 10), title: 'B'),
      _event('soon-a', startsOn: DateTime(2026, 10, 10), title: 'A'),
      _event('outside', startsOn: DateTime(2027, 3, 1)),
    ];
    final window = EventFilter.defaultWindow(today);

    test('keeps only events in the window, ordered by date then title', () {
      final result = applyEventFilter(events, window);

      expect(result.map((e) => e.id), ['soon-a', 'soon-b', 'late']);
    });

    test('narrows by region', () {
      final result = applyEventFilter(events, window.copyWith(region: 'Piemonte'));

      expect(result.map((e) => e.id), ['late']);
    });

    test('narrows by type', () {
      final result = applyEventFilter(events, window.copyWith(eventType: 'dog_show'));

      expect(result.map((e) => e.id), ['late']);
    });

    test('clearing a filter shows everything in the window again', () {
      final narrowed = window.copyWith(region: 'Piemonte');

      final result = applyEventFilter(events, narrowed.copyWith(clearRegion: true));

      expect(result, hasLength(3));
    });

    test('an empty list stays empty', () {
      expect(applyEventFilter(const [], window), isEmpty);
    });
  });

  group('available filter choices', () {
    final inWindow = [
      _event('a', startsOn: DateTime(2026, 10, 10), region: 'Lombardia', eventType: 'pet_fair'),
      _event('b', startsOn: DateTime(2026, 10, 11), region: 'Piemonte', eventType: 'dog_show'),
      _event('c', startsOn: DateTime(2026, 10, 12), region: 'Lombardia', eventType: 'pet_fair'),
      _event('d', startsOn: DateTime(2026, 10, 13), region: null, eventType: 'pet_fair'),
    ];

    test('regions are de-duplicated, sorted, and skip events without one', () {
      expect(availableRegions(inWindow), ['Lombardia', 'Piemonte']);
    });

    test('types are de-duplicated and sorted by their Italian label', () {
      expect(availableEventTypes(inWindow), ['dog_show', 'pet_fair']);
    });
  });

  group('EventEntry', () {
    test('only an http(s) link is launchable', () {
      expect(_event('a', startsOn: today, sourceUrl: 'https://www.petsfestival.eu').launchableUrl, isNotNull);
      expect(_event('b', startsOn: today, sourceUrl: 'http://example.org/x').launchableUrl, isNotNull);
      expect(_event('c', startsOn: today, sourceUrl: null).launchableUrl, isNull);
      expect(_event('d', startsOn: today, sourceUrl: '   ').launchableUrl, isNull);
      expect(_event('e', startsOn: today, sourceUrl: 'javascript:alert(1)').launchableUrl, isNull);
      expect(_event('f', startsOn: today, sourceUrl: 'tel:+390000000').launchableUrl, isNull);
      expect(_event('g', startsOn: today, sourceUrl: 'solo testo').launchableUrl, isNull);
    });

    test('place label shows city with province, falling back to the region', () {
      final withProvince = EventEntry(
        id: 'a',
        title: 't',
        eventType: 'other',
        level: EventLevel.local,
        startsOn: _placeholderDay,
        endsOn: _placeholderDay,
        city: 'Cremona',
        provinceCode: 'CR',
        region: 'Lombardia',
      );
      final regionOnly = EventEntry(
        id: 'b',
        title: 't',
        eventType: 'other',
        level: EventLevel.local,
        startsOn: _placeholderDay,
        endsOn: _placeholderDay,
        region: 'Lombardia',
      );

      expect(withProvince.placeLabel, 'Cremona (CR)');
      expect(regionOnly.placeLabel, 'Lombardia');
    });

    test('an unknown event type reads as "Altro" instead of failing', () {
      expect(eventTypeLabel('pet_fair'), 'Fiera per animali');
      expect(eventTypeLabel('something_new'), 'Altro');
    });

    test('an unknown level falls back to local', () {
      expect(EventLevel.parse('national'), EventLevel.national);
      expect(EventLevel.parse('galactic'), EventLevel.local);
      expect(EventLevel.parse(null), EventLevel.local);
    });
  });

  group('parseEventRow / formatEventDate', () {
    Map<String, dynamic> row({Map<String, dynamic> overrides = const {}}) => {
          'id': 'abc',
          'title': '  Petsfestival ',
          'event_type': 'pet_fair',
          'level': 'national',
          'starts_on': '2026-10-17',
          'ends_on': '2026-10-18',
          'city': 'Cremona',
          'province_code': 'CR',
          'region': 'Lombardia',
          'source_url': 'https://www.petsfestival.eu',
          'status': 'published',
          ...overrides,
        };

    test('reads a complete row', () {
      final event = parseEventRow(row())!;

      expect(event.title, 'Petsfestival');
      expect(event.level, EventLevel.national);
      expect(event.startsOn, DateTime(2026, 10, 17));
      expect(event.endsOn, DateTime(2026, 10, 18));
      expect(event.placeLabel, 'Cremona (CR)');
      expect(event.status, EventStatus.published);
    });

    test('keeps a cancelled event visible as cancelled', () {
      expect(parseEventRow(row(overrides: {'status': 'cancelled'}))!.status, EventStatus.cancelled);
      expect(parseEventRow(row(overrides: {'status': 'postponed'}))!.status, EventStatus.postponed);
    });

    test('drops rows without a usable title or dates instead of failing', () {
      expect(parseEventRow(row(overrides: {'title': '   '})), isNull);
      expect(parseEventRow(row(overrides: {'starts_on': null})), isNull);
      expect(parseEventRow(row(overrides: {'ends_on': 'not a date'})), isNull);
      expect(parseEventRow(row(overrides: {'id': ''})), isNull);
    });

    test('blank optional text becomes null, so no link is invented', () {
      final event = parseEventRow(row(overrides: {'source_url': '  ', 'city': ''}))!;

      expect(event.sourceUrl, isNull);
      expect(event.launchableUrl, isNull);
      expect(event.city, isNull);
    });

    test('formats dates for the date column', () {
      expect(formatEventDate(DateTime(2026, 3, 7, 18, 30)), '2026-03-07');
    });
  });

  test('without a configured backend the repository returns an empty list, never demo events', () async {
    final result = await EventsRepository().loadEvents(from: DateTime(2026, 10, 4), to: DateTime(2026, 11, 3));

    expect(result.events, isEmpty);
    expect(result.failed, isFalse);
  });
}

final _placeholderDay = DateTime(2026, 1, 1);
