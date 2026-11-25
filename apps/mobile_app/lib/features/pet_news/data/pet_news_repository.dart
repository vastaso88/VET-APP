import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../language/data/language_store.dart';
import '../domain/pet_news_edition.dart';
import 'pet_news_disk_cache.dart';
import '../domain/pet_news_item.dart';

abstract class PetNewsRepository {
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit});
}

/// The complete fixed set of "curiosità" categories the app ever queries —
/// every owned-species label plus the cross-species "Generale" catch-all.
/// Shared by the News page (shows all of them), Home (a 4-slot subset —
/// see home_dashboard_page.dart's `_loadPetNews`) and the splash preload
/// warm-up, so all three agree on exactly what "every category" means and
/// hit the same cache keys.
const allPetNewsCategories = <String>[
  'Cane',
  'Gatto',
  'Piccoli mammiferi',
  'Uccello',
  'Rettili e anfibi',
  'Pesce',
  'Altro',
  'Generale',
];

/// Pool size per category — bigger than the single card a display slot
/// needs, so a duplicate-title drop (or two slots both falling back to
/// "Generale") can backfill from the same fetch instead of needing another
/// request.
const petNewsPoolLimitPerCategory = 4;

/// The edition the owner reads right now: app language x country of the
/// chosen variant (🇬🇧 → en-GB edition, 🇩🇪 → de-DE, ...).
PetNewsEdition currentPetNewsEdition() {
  final variant = LanguageStore.instance.variant;
  return petNewsEditionFor(variant.languageCode, variant.countryCode ?? 'IT');
}

/// Editions our backend (GET /news) has feeds for. Today only the Italian
/// one: the backend reads Italian pet magazines and veterinary bodies. Any
/// other edition gets an empty list and the "no news for your country yet"
/// message - never Italian headlines, never another country's
/// (docs/i18n/NOTIZIE_EVENTI_MERCATINO.md) and never a call from the phone to
/// a third-party feed or proxy. When the backend gains the feeds of another
/// country (feeds.py), add its edition here: an older server would answer it
/// with the Italian headlines, which [BackendPetNewsRepository] refuses.
const backendPetNewsEditions = <String>{'it-IT'};

/// True when [edition] (default: the owner's) has news to show.
bool petNewsEditionServed([PetNewsEdition? edition]) =>
    backendPetNewsEditions.contains((edition ?? currentPetNewsEdition()).cacheKey);

/// "Curiosità" read from our own backend (GET /news), which reads the RSS
/// feeds of pet magazines and veterinary bodies, drops off-topic and
/// recipe-like headlines, de-duplicates them and keeps a shared cache. The
/// app no longer talks to any third-party feed or proxy. Swappable behind
/// [PetNewsRepository].
///
/// Only an edition in [backendPetNewsEditions] is fetched; for any other the
/// answer is an empty list without a request (see [petNewsEditionServed]).
class BackendPetNewsRepository implements PetNewsRepository {
  BackendPetNewsRepository({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    PetNewsEdition Function()? editionProvider,
    PetNewsDiskCache? diskCache,
  })  : _client = client ?? http.Client(),
        _disk = diskCache ?? const PetNewsDiskCache(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _editionProvider = editionProvider ?? currentPetNewsEdition;

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final PetNewsEdition Function() _editionProvider;
  final PetNewsDiskCache _disk;

  // One request returns every category, so the whole answer is kept for a
  // while and shared by every repository instance (Home, News page, splash
  // warm-up): repeat navigation costs nothing. The backend refreshes its own
  // copy from the feeds every couple of hours. One answer per country.
  static final _cache = <String, _CacheEntry>{};
  static final _inFlight = <String, Future<Map<String, List<PetNewsItem>>?>>{};
  static const _cacheTtl = Duration(minutes: 20);
  // The first request after a quiet spell makes the server read the feeds
  // (a few seconds, more on a slow line): a patient wait and one more try
  // beat a section that stays "unavailable" until the app restarts.
  static const _timeout = Duration(seconds: 25);

  /// The tries after the first are shorter: the server has been woken by then.
  static const _retryTimeout = Duration(seconds: 10);

  /// Up to four asks: a cold server may answer "no headlines yet" (its feeds are
  /// read on the first request after a quiet spell and a failed read is not
  /// repeated at once), and a section that says "unavailable" on the very first
  /// opening is worse than a few more seconds of loader.
  static const _attempts = 4;

  /// Wait before the second try; it grows with each one (2, 4, 6 s). Tests set it
  /// to zero (no timer is left behind).
  @visibleForTesting
  static Duration retryPause = const Duration(seconds: 2);
  static const _itemsPerCategory = 12;

  /// With a kept copy to show, how long to wait for the network before showing it
  /// (the request goes on and refreshes the shared answer when it lands).
  static const _patience = Duration(seconds: 6);

  /// Forgets the shared answer (tests).
  static void resetCache() {
    _cache.clear();
    _inFlight.clear();
  }

  @override
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit = 2}) async {
    final edition = _editionProvider();
    if (!petNewsEditionServed(edition)) return const [];
    final byCategory = await _load(edition.countryCode);
    return (byCategory[species] ?? const <PetNewsItem>[]).take(limit).toList(growable: false);
  }

  Future<Map<String, List<PetNewsItem>>> _load(String country) async {
    final cached = _cache[country];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.byCategory;
    }

    final pending = _inFlight[country] ??= _fetchAll(country).then((value) {
      // Kept even when the caller stopped waiting, so the next ask is instant.
      if (value != null) _cache[country] = _CacheEntry(value, DateTime.now());
      return value;
    }).whenComplete(() {
      _inFlight.remove(country);
    });

    // A copy kept on the phone lets a slow request give way after a short wait.
    final kept = cached == null ? await _keptCopy(country) : null;
    final fresh = kept == null
        ? await pending
        : await pending.timeout(_patience, onTimeout: () => null);
    if (fresh != null) return fresh;
    // The backend did not answer: an older answer beats an empty section.
    return cached?.byCategory ?? kept?.byCategory ?? const {};
  }

  /// The last good answer of [country] kept on the phone, parsed; null when there is none.
  Future<_CacheEntry?> _keptCopy(String country) async {
    final stored = await _disk.load();
    if (stored == null) return null;
    final parsed = _parse(stored.body, country);
    return parsed == null ? null : _CacheEntry(parsed, stored.savedAt);
  }

  Future<Map<String, List<PetNewsItem>>?> _fetchAll(String country) async {
    for (var attempt = 0; attempt < _attempts; attempt++) {
      if (attempt > 0 && retryPause > Duration.zero) {
        await Future<void>.delayed(retryPause * attempt);
      }
      final result = await _fetchOnce(country, attempt == 0 ? _timeout : _retryTimeout);
      if (result != null) return result;
    }
    return null;
  }

  /// The headlines of one ask, or null when it gave none worth showing: a failed
  /// request, an unreadable body, or an answer with no headline at all (what a
  /// server that has not read its feeds yet sends). Null is tried again and never
  /// kept as the shared answer, so an empty first reply cannot hide the news for
  /// the next 20 minutes.
  Future<Map<String, List<PetNewsItem>>?> _fetchOnce(String country, Duration timeout) async {
    final baseUrl = _configLoader.load().apiBaseUrl;
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/news')
              .replace(queryParameters: {'limit': '$_itemsPerCategory', 'country': country}))
          .timeout(timeout);
      if (response.statusCode != 200) return null;

      final parsed = _parse(response.body, country);
      if (parsed == null || !parsed.values.any((items) => items.isNotEmpty)) return null;
      unawaited(_disk.save(response.body, DateTime.now()));
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// The headlines of [body]; null when it cannot be read or is the answer of another
  /// country. A server that does not name the country (it knows only one) means Italy.
  Map<String, List<PetNewsItem>>? _parse(String body, String country) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if ((json['country'] ?? 'IT') != country) return null;
      final categories = json['categories'] as Map<String, dynamic>? ?? const {};
      return {
        for (final entry in categories.entries)
          entry.key: [
            for (final raw in entry.value as List<dynamic>)
              if (_toNewsItem(entry.key, raw as Map<String, dynamic>) case final item?) item,
          ],
      };
    } catch (_) {
      return null;
    }
  }

  PetNewsItem? _toNewsItem(String category, Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    final link = (item['url'] ?? '').toString();
    if (title.isEmpty || link.isEmpty) return null;

    return PetNewsItem(
      species: category,
      title: title,
      extract: (item['source'] ?? '').toString(),
      sourceUrl: link,
      publishedAt: DateTime.tryParse((item['published_at'] ?? '').toString()),
    );
  }
}

class _CacheEntry {
  const _CacheEntry(this.byCategory, this.fetchedAt);

  final Map<String, List<PetNewsItem>> byCategory;
  final DateTime fetchedAt;
}

/// Runs [tasks] in small parallel batches — [batchSize] at a time, with a
/// pause between batches — instead of either one at a time or all at once.
///
/// Historical note: this paced calls to the old third-party feed proxy, which
/// refused bursts. [BackendPetNewsRepository] answers every category from one
/// shared request, so the pause defaults to none; the batching stays so the
/// first batch can be shown before the rest (the News page relies on it).
Future<void> fetchManyWithLimitStreaming<T>(
  List<Future<T> Function()> tasks, {
  required void Function(List<T> batchResults) onBatch,
  int batchSize = 3,
  Duration betweenBatches = Duration.zero,
}) async {
  for (var i = 0; i < tasks.length; i += batchSize) {
    if (i > 0 && betweenBatches > Duration.zero) {
      await Future<void>.delayed(betweenBatches);
    }
    final batch = tasks.skip(i).take(batchSize).map((task) => task());
    onBatch(await Future.wait(batch));
  }
}

/// [fetchManyWithLimitStreaming] for a caller that just wants the final,
/// combined list rather than reacting to each batch as it lands.
Future<List<T>> fetchManyWithLimit<T>(
  List<Future<T> Function()> tasks, {
  int batchSize = 3,
  Duration betweenBatches = Duration.zero,
}) async {
  final results = <T>[];
  await fetchManyWithLimitStreaming<T>(
    tasks,
    onBatch: results.addAll,
    batchSize: batchSize,
    betweenBatches: betweenBatches,
  );
  return results;
}
