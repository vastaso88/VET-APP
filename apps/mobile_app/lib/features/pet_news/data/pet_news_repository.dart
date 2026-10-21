import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../language/data/language_store.dart';
import '../domain/pet_news_edition.dart';
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

/// Free, keyless "curiosita" source: real headlines from real newspapers,
/// via Google News' public RSS search, bridged through rss2json.com (a
/// free CORS-friendly RSS-to-JSON proxy — Google News' own RSS endpoint
/// blocks direct browser fetches). Swappable behind [PetNewsRepository]
/// for a paid/higher-quality provider later.
///
/// Only the owner's country and language are ever asked for: the edition
/// (`hl`/`gl`/`ceid`) and the search words come from [PetNewsEdition], and a
/// headline written in another language than the app's is dropped. There is
/// no fallback to another country's news: when nothing local comes back the
/// list is empty and the page says so (docs/i18n/NOTIZIE_EVENTI_MERCATINO.md).
class GoogleNewsPetNewsRepository implements PetNewsRepository {
  GoogleNewsPetNewsRepository({http.Client? client, PetNewsEdition Function()? editionProvider})
      : _client = client ?? http.Client(),
        _editionProvider = editionProvider ?? currentPetNewsEdition;

  final http.Client _client;
  final PetNewsEdition Function() _editionProvider;

  // rss2json's free/keyless tier has a low, shared burst-rate limit (it
  // actively refuses requests with "converting new feeds in a very short
  // period" once exceeded) — both Home and the News page fetching several
  // categories in quick succession can trip it. A simple in-memory cache,
  // shared across every repository instance for the lifetime of the app,
  // means repeat navigation within the TTL reuses the same response
  // instead of re-hitting the API. Cached per edition and species (a
  // language switch must never show the previous country's headlines),
  // uncapped by `limit`, so a later call asking for more items than an
  // earlier one can still be served entirely from cache.
  static final Map<String, _CacheEntry> _cache = {};
  static const _cacheTtl = Duration(minutes: 20);

  /// Empties the shared cache (tests).
  static void clearCache() => _cache.clear();

  // One retry after a short backoff for a transient failure (429, or a 5xx
  // — measured against the live endpoint on 2026-09-30 firing several
  // requests fully in parallel: failures came back as 500, not always a
  // clean 429, so both are treated as "try again once" here) before
  // falling back to a stale cache entry or an empty list.
  static const _maxAttempts = 2;
  static const _retryBackoff = Duration(milliseconds: 500);

  @override
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit = 2}) async {
    final edition = _editionProvider();
    final cacheKey = '${edition.cacheKey}|$species';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.items.take(limit).toList(growable: false);
    }

    final query = edition.queryFor(species);
    // The query term is percent-encoded on its own (spaces/parens as %20
    // etc) BEFORE being embedded in the (otherwise literal) Google News
    // URL string. rss2json's own URL validator decodes `rss_url` once
    // before checking it looks like a URL, so it needs a plain space to
    // still read as `%20` after that single decode — passing a literal,
    // un-pre-encoded space (or double-encoding everything, including
    // `://`) both make it reject the value with a 422.
    final rssUrl = 'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}'
        '&hl=${edition.hl}&gl=${edition.gl}&ceid=${edition.ceid}';
    // Note: rss2json's `count` param requires an API key even on the free
    // tier, so items are capped client-side instead (see `.take` below).
    final proxyUrl = Uri.parse(
      'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(rssUrl)}',
    );

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _client.get(proxyUrl);
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(_retryBackoff * attempt);
            continue;
          }
          return cached?.items.take(limit).toList(growable: false) ?? const [];
        }
        if (response.statusCode != 200) {
          return cached?.items.take(limit).toList(growable: false) ?? const [];
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['status'] != 'ok') {
          return cached?.items.take(limit).toList(growable: false) ?? const [];
        }

        final items = (json['items'] as List<dynamic>? ?? const [])
            .map((raw) => _toNewsItem(edition, species, raw as Map<String, dynamic>))
            .whereType<PetNewsItem>()
            .toList(growable: false);

        _cache[cacheKey] = _CacheEntry(items, DateTime.now());
        return items.take(limit).toList(growable: false);
      } catch (_) {
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(_retryBackoff * attempt);
          continue;
        }
        return cached?.items.take(limit).toList(growable: false) ?? const [];
      }
    }
    return cached?.items.take(limit).toList(growable: false) ?? const [];
  }

  PetNewsItem? _toNewsItem(PetNewsEdition edition, String species, Map<String, dynamic> item) {
    final rawTitle = (item['title'] ?? '').toString().trim();
    final link = (item['link'] ?? '').toString();
    if (rawTitle.isEmpty || link.isEmpty) {
      return null;
    }

    final normalizedTitle = rawTitle.toLowerCase();
    if (edition.blockedKeywords.any(normalizedTitle.contains)) {
      return null;
    }

    final separatorIndex = rawTitle.lastIndexOf(' - ');
    final headline = separatorIndex == -1 ? rawTitle : rawTitle.substring(0, separatorIndex);
    final source = separatorIndex == -1 ? 'Google News' : rawTitle.substring(separatorIndex + 3);

    // A headline in another language than the app's is another country's
    // content that slipped through the edition: dropped, never translated.
    if (!headlineMatchesLanguage(headline, edition.languageCode)) {
      return null;
    }

    return PetNewsItem(
      species: species,
      title: headline,
      extract: source,
      sourceUrl: link,
      imageUrl: (item['thumbnail'] as String?)?.isNotEmpty == true
          ? item['thumbnail'] as String
          : null,
      // rss2json normalizes pubDate to "yyyy-MM-dd HH:mm:ss", which
      // DateTime.tryParse accepts directly (space instead of the ISO "T").
      publishedAt: DateTime.tryParse((item['pubDate'] ?? '').toString()),
    );
  }
}

class _CacheEntry {
  const _CacheEntry(this.items, this.fetchedAt);

  final List<PetNewsItem> items;
  final DateTime fetchedAt;
}

/// Runs [tasks] in small parallel batches — [batchSize] at a time, with a
/// pause between batches — instead of either one at a time or all at once.
///
/// Measured against the real rss2json endpoint (2026-09-30): 8 requests
/// fired fully in parallel failed 2/8 (HTTP 500, the free tier's
/// shared-bucket symptom — not always a clean 429); the previous one-at-
/// a-time-with-4s-delay approach took ~32s for 8 categories. Batches of 3
/// with a 600ms pause between batches completed all 8 with zero failures
/// in under 3s total. `fetchForSpecies` also retries once on its own for
/// whatever transient failure still gets through (the shared bucket's
/// exact threshold moves with load from other callers, so no fixed pacing
/// here can promise zero 429s).
Future<void> fetchManyWithLimitStreaming<T>(
  List<Future<T> Function()> tasks, {
  required void Function(List<T> batchResults) onBatch,
  int batchSize = 3,
  Duration betweenBatches = const Duration(milliseconds: 600),
}) async {
  for (var i = 0; i < tasks.length; i += batchSize) {
    if (i > 0) {
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
  Duration betweenBatches = const Duration(milliseconds: 600),
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
