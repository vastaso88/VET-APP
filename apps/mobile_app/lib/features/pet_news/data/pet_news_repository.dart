import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
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

/// "Curiosità" read from our own backend (GET /news), which reads the RSS
/// feeds of pet magazines and veterinary bodies, drops off-topic and
/// recipe-like headlines, de-duplicates them and keeps a shared cache. The
/// app no longer talks to any third-party feed or proxy. Swappable behind
/// [PetNewsRepository].
class BackendPetNewsRepository implements PetNewsRepository {
  BackendPetNewsRepository({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  // One request returns every category, so the whole answer is kept for a
  // while and shared by every repository instance (Home, News page, splash
  // warm-up): repeat navigation costs nothing. The backend refreshes its own
  // copy from the feeds every couple of hours.
  static _CacheEntry? _cache;
  static Future<Map<String, List<PetNewsItem>>?>? _inFlight;
  static const _cacheTtl = Duration(minutes: 20);
  static const _timeout = Duration(seconds: 15);
  static const _itemsPerCategory = 12;

  /// Forgets the shared answer (tests).
  static void resetCache() {
    _cache = null;
    _inFlight = null;
  }

  @override
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit = 2}) async {
    final byCategory = await _load();
    return (byCategory[species] ?? const <PetNewsItem>[]).take(limit).toList(growable: false);
  }

  Future<Map<String, List<PetNewsItem>>> _load() async {
    final cached = _cache;
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.byCategory;
    }

    final pending = _inFlight ??= _fetchAll().whenComplete(() => _inFlight = null);
    final fresh = await pending;
    if (fresh != null) {
      _cache = _CacheEntry(fresh, DateTime.now());
      return fresh;
    }
    // The backend did not answer: an older answer beats an empty section.
    return cached?.byCategory ?? const {};
  }

  Future<Map<String, List<PetNewsItem>>?> _fetchAll() async {
    final baseUrl = _configLoader.load().apiBaseUrl;
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/news').replace(queryParameters: {'limit': '$_itemsPerCategory'}))
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
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
