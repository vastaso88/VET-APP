import 'event_entry.dart';

/// Finestra predefinita della sezione: da oggi ai prossimi 30 giorni.
const int defaultEventWindowDays = 30;

DateTime eventDay(DateTime value) => DateTime(value.year, value.month, value.day);

/// Filtri scelti dall'utente. `from`/`to` sono giorni inclusi. Regione e tipo
/// sono opzionali (null = tutti).
class EventFilter {
  const EventFilter({required this.from, required this.to, this.region, this.eventType});

  /// "Nei prossimi 30 giorni", contati da [today] (oggi incluso).
  factory EventFilter.defaultWindow(DateTime today) {
    final start = eventDay(today);
    // Calendar arithmetic, not `start.add(Duration(days: 30))`: adding 30 x
    // 24h across a clock change (end of October) lands at 23:00 of the
    // previous day and the window would end a day early.
    return EventFilter(
      from: start,
      to: DateTime(start.year, start.month, start.day + defaultEventWindowDays),
    );
  }

  final DateTime from;
  final DateTime to;
  final String? region;
  final String? eventType;

  /// True se [from]/[to] sono ancora la finestra predefinita calcolata da
  /// [today] (serve a scegliere il testo dello stato vuoto).
  bool isDefaultWindow(DateTime today) {
    final reference = EventFilter.defaultWindow(today);
    return from == reference.from && to == reference.to;
  }

  bool get hasExtraFilters => region != null || eventType != null;

  EventFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? region,
    String? eventType,
    bool clearRegion = false,
    bool clearEventType = false,
  }) {
    return EventFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      region: clearRegion ? null : (region ?? this.region),
      eventType: clearEventType ? null : (eventType ?? this.eventType),
    );
  }
}

/// Un evento cade nella finestra se i due intervalli di giorni si
/// sovrappongono (un evento già iniziato e ancora in corso conta).
bool eventOverlapsWindow(EventEntry event, DateTime from, DateTime to) {
  return !eventDay(event.endsOn).isBefore(eventDay(from)) &&
      !eventDay(event.startsOn).isAfter(eventDay(to));
}

/// Solo la parte di finestra (date): usata sia dal repository che dai test.
List<EventEntry> filterEventsByWindow(List<EventEntry> events, EventFilter filter) {
  return events.where((event) => eventOverlapsWindow(event, filter.from, filter.to)).toList();
}

/// Finestra + regione + tipo, ordinato per data di inizio, poi titolo.
List<EventEntry> applyEventFilter(List<EventEntry> events, EventFilter filter) {
  final filtered = filterEventsByWindow(events, filter).where((event) {
    if (filter.region != null && event.region != filter.region) return false;
    if (filter.eventType != null && event.eventType != filter.eventType) return false;
    return true;
  }).toList();

  filtered.sort((a, b) {
    final byDate = a.startsOn.compareTo(b.startsOn);
    return byDate != 0 ? byDate : a.title.compareTo(b.title);
  });
  return filtered;
}

/// Regioni presenti nell'elenco (già filtrato per date): offrire solo scelte
/// che danno risultati, ordinate alfabeticamente.
List<String> availableRegions(List<EventEntry> events) {
  final regions = {
    for (final event in events)
      if (event.region != null && event.region!.trim().isNotEmpty) event.region!,
  }.toList()
    ..sort();
  return regions;
}

/// Tipi presenti nell'elenco (codici), ordinati per etichetta italiana.
List<String> availableEventTypes(List<EventEntry> events) {
  final types = {for (final event in events) event.eventType}.toList()
    ..sort((a, b) => eventTypeLabel(a).compareTo(eventTypeLabel(b)));
  return types;
}
