import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/date/calendar_days.dart';
import '../../billing/data/subscription_required_signal.dart';
import '../../territory/domain/territory.dart';
import '../domain/event_entry.dart';
import '../domain/event_filter.dart';

/// Esito di un caricamento: distingue "nessun evento" da "non sono riuscito a
/// leggere" - per l'utente sono situazioni diverse e la prima non deve mai
/// nascondere la seconda.
class EventsLoadResult {
  const EventsLoadResult(
      {required this.events, this.failed = false, this.needsPlan = false});

  final List<EventEntry> events;
  final bool failed;

  /// The backend refused (402): the trial is over and the owner has no plan.
  /// Different from [failed]: retrying changes nothing.
  final bool needsPlan;
}

/// Gli eventi li serve il backend (`GET /events`): fanno parte di cio' che
/// include un piano e il controllo non puo' dipendere dall'app. Se il backend
/// non risponde (non ancora rilasciato, rete) si ripiega sulla lettura diretta
/// della tabella `events` con la anon key, finche' la sua policy RLS di lettura
/// pubblica esiste (scripts/setup/events_read_via_backend.sql la toglie).
/// Le scritture avvengono solo da scripts/events/import_curated.py con la
/// service role. Senza backend configurato (anteprima, test) l'elenco e'
/// vuoto: nessun evento di esempio, mai (vincolo del progetto: nessun dato
/// inventato).
class EventsRepository {
  EventsRepository({
    SupabaseClient? client,
    http.Client? httpClient,
    String? Function()? tokenProvider,
    AppRuntimeConfigLoader? configLoader,
  })  : _client = client,
        _http = httpClient,
        _tokenProvider = tokenProvider ?? CurrentUser.accessToken,
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final SupabaseClient? _client;
  final http.Client? _http;
  final String? Function() _tokenProvider;
  final AppRuntimeConfigLoader _configLoader;

  static const _apiTimeout = Duration(seconds: 20);

  /// Gli eventi dal backend: null quando non si puo' interpellare o non ha
  /// risposto in modo utile (si ripiega); un risultato `needsPlan` su 402.
  Future<EventsLoadResult?> _loadFromApi({
    required DateTime from,
    required DateTime to,
    required String countryCode,
  }) async {
    final baseUrl = _configLoader.load().apiBaseUrl.trim();
    final token = _tokenProvider();
    if (baseUrl.isEmpty || token == null || token.isEmpty) return null;

    final uri = Uri.parse('$baseUrl/events').replace(queryParameters: {
      'country': countryCode,
      'from': formatEventDate(from),
      'to': formatEventDate(to),
    });
    try {
      final response = await (_http ?? http.Client()).get(uri,
          headers: {'Authorization': 'Bearer $token'}).timeout(_apiTimeout);
      if (handleSubscriptionRequired(response.statusCode)) {
        return const EventsLoadResult(events: [], needsPlan: true);
      }
      if (response.statusCode != 200) return null;
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final events = _parseRows(json['events'] as List<dynamic>? ?? const []);
      return EventsLoadResult(
          events: filterEventsByCountry(events, countryCode));
    } catch (_) {
      return null;
    }
  }

  /// The rows of either source that parse as events; malformed ones are skipped.
  static List<EventEntry> _parseRows(List<dynamic> rows) => rows
      .map((row) => parseEventRow(row as Map<String, dynamic>))
      .whereType<EventEntry>()
      .toList();

  /// Eventi che toccano la finestra [from]-[to] (estremi inclusi), ordinati per
  /// data di inizio. Regione e tipo si filtrano dopo, sul risultato: i volumi
  /// sono di decine o centinaia di righe.
  ///
  /// Solo gli eventi di [country] (ISO alpha-2; predefinito: il paese
  /// dell'utente, vedi `currentTerritory`): mai quelli di un altro paese, ne'
  /// come ripiego quando il proprio e' vuoto.
  Future<EventsLoadResult> loadEvents({
    required DateTime from,
    required DateTime to,
    String? country,
  }) async {
    final countryCode =
        (country ?? currentTerritory().countryCode).toUpperCase();
    final fromApi =
        await _loadFromApi(from: from, to: to, countryCode: countryCode);
    if (fromApi != null) return fromApi;

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
          .eq('country', countryCode)
          .gte('ends_on', formatEventDate(from))
          .lte('starts_on', formatEventDate(to))
          .order('starts_on', ascending: true);

      final events = _parseRows(response as List<dynamic>);
      // The query already filters; this keeps a misconfigured policy from
      // leaking another country's event into the list.
      return EventsLoadResult(events: filterEventsByCountry(events, countryCode));
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
  final day = dayOnly(value);
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
    country: (text('country') ?? 'IT').toUpperCase(),
    startsOn: dayOnly(startsOn),
    endsOn: dayOnly(endsOn),
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
