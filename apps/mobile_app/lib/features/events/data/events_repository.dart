import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/event_entry.dart';
import '../domain/event_filter.dart';

/// Esito di un caricamento: distingue "nessun evento" da "non sono riuscito a
/// leggere" - per l'utente sono situazioni diverse e la prima non deve mai
/// nascondere la seconda.
class EventsLoadResult {
  const EventsLoadResult({required this.events, this.failed = false});

  final List<EventEntry> events;
  final bool failed;
}

/// Lettura diretta della tabella `events` con la anon key: la policy RLS è di
/// sola lettura pubblica (scripts/setup/supabase_schema.sql), le scritture
/// avvengono solo da scripts/events/import_curated.py con la service role.
/// Senza backend configurato (anteprima, test) l'elenco è vuoto: nessun evento
/// di esempio, mai (vincolo del progetto: nessun dato inventato).
class EventsRepository {
  EventsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  /// Eventi che toccano la finestra [from]-[to] (estremi inclusi), ordinati per
  /// data di inizio. Regione e tipo si filtrano dopo, sul risultato: i volumi
  /// sono di decine o centinaia di righe.
  Future<EventsLoadResult> loadEvents({required DateTime from, required DateTime to}) async {
    final client = _resolveClient();
    if (client == null) {
      return const EventsLoadResult(events: []);
    }

    try {
      final response = await client
          .from('events')
          .select('*')
          .inFilter('status', ['published', 'cancelled', 'postponed'])
          .eq('audience', 'public')
          .gte('ends_on', formatEventDate(from))
          .lte('starts_on', formatEventDate(to))
          .order('starts_on', ascending: true);

      final events = <EventEntry>[];
      for (final row in response as List<dynamic>) {
        final event = parseEventRow(row as Map<String, dynamic>);
        if (event != null) events.add(event);
      }
      return EventsLoadResult(events: events);
    } catch (_) {
      return const EventsLoadResult(events: [], failed: true);
    }
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) return _client;

    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) return null;

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

/// `YYYY-MM-DD`, il formato della colonna `date`.
String formatEventDate(DateTime value) {
  final day = eventDay(value);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

/// Riga -> evento. Una riga malformata (titolo o date mancanti/illeggibili) si
/// scarta invece di far cadere l'intera pagina, come gli altri repository.
EventEntry? parseEventRow(Map<String, dynamic> row) {
  final id = (row['id'] ?? '').toString();
  final title = (row['title'] ?? '').toString().trim();
  final startsOn = DateTime.tryParse((row['starts_on'] ?? '').toString());
  final endsOn = DateTime.tryParse((row['ends_on'] ?? '').toString());
  if (id.isEmpty || title.isEmpty || startsOn == null || endsOn == null) {
    return null;
  }

  String? text(String key) {
    final value = (row[key] as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  return EventEntry(
    id: id,
    title: title,
    eventType: text('event_type') ?? 'other',
    level: EventLevel.parse(row['level'] as String?),
    startsOn: eventDay(startsOn),
    endsOn: eventDay(endsOn),
    description: text('description'),
    city: text('city'),
    provinceCode: text('province_code'),
    region: text('region'),
    venueName: text('venue_name'),
    organizerName: text('organizer_name'),
    sourceUrl: text('source_url'),
    status: EventStatus.parse(row['status'] as String?),
    lastVerifiedAt: DateTime.tryParse((row['last_verified_at'] ?? '').toString()),
  );
}
