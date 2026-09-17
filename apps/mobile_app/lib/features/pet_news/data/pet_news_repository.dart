import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/pet_news_item.dart';

abstract class PetNewsRepository {
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit});
}

/// Free, keyless "curiosita" source: real headlines from real newspapers,
/// via Google News' public RSS search, bridged through rss2json.com (a
/// free CORS-friendly RSS-to-JSON proxy — Google News' own RSS endpoint
/// blocks direct browser fetches). Swappable behind [PetNewsRepository]
/// for a paid/higher-quality provider later.
class GoogleNewsPetNewsRepository implements PetNewsRepository {
  GoogleNewsPetNewsRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Every query excludes recipe/cooking terms: several of these species are
  // also common food ingredients (coniglio, pesce...), and unfiltered
  // searches surface "coniglio alla cacciatora"-style recipes alongside
  // real animal news — a bad look for a pet-care app with an
  // animal-loving audience. This is a best-effort keyword exclusion at the
  // query level; `_isBlocked` below is a second, client-side pass over the
  // actual results as a safety net for whatever slips through.
  static const _recipeExclusions =
      '-ricetta -ricette -cucina -cucinare -sagra -caccia -cacciatore -cacciatori -oroscopo';

  static const _queryBySpecies = {
    'Cane': 'cane $_recipeExclusions',
    'Gatto': 'gatto $_recipeExclusions',
    // Plain "coniglio" collides constantly with the common Italian surname
    // and with unrelated uses of the word (theatre shows, economics papers).
    // Biasing toward pet-specific companion terms cuts most of that noise.
    'Coniglio': 'coniglio (domestico OR nano OR appartamento OR veterinario) $_recipeExclusions',
    'Uccello': 'uccello $_recipeExclusions',
    'Rettile': 'rettile $_recipeExclusions',
    // Same issue as coniglio: "pesce" alone also means the zodiac sign, a
    // surname, and any number of unrelated place/route names.
    'Pesce': 'pesce (acquario OR acquariofilia OR veterinario OR domestico) $_recipeExclusions',
    'Altro': 'animali domestici $_recipeExclusions',
    'Generale': 'animali domestici (fiera OR legge OR normativa) $_recipeExclusions',
  };

  // Client-side safety net: titles/sources containing any of these are
  // dropped even if they slipped past the query-level exclusion above —
  // food/recipe content (animals as ingredients) and known off-topic
  // sources (e.g. a virtual-pet game, not real animals).
  static const _blockedKeywords = [
    'ricetta',
    'ricette',
    'cucina',
    'cucinare',
    'cotto',
    'cottura',
    'arrosto',
    'spezzatino',
    'stufato',
    'brasato',
    'padella',
    'in forno',
    'ingredienti',
    'gustoso',
    'sagra',
    'porchetta',
    'grigliata',
    'grigliato',
    'caccia',
    'cacciatore',
    'cacciatori',
    'cacciatora',
    'oroscopo',
    'tamagotchi',
    'tamaverse',
  ];

  // rss2json's free/keyless tier has a low, shared burst-rate limit (it
  // actively refuses requests with "converting new feeds in a very short
  // period" once exceeded) — both Home and the News page fetching several
  // categories in quick succession can trip it. A simple in-memory cache,
  // shared across every repository instance for the lifetime of the app,
  // means repeat navigation within the TTL reuses the same response
  // instead of re-hitting the API. Cached per species, uncapped by
  // `limit`, so a later call asking for more items than an earlier one can
  // still be served entirely from cache.
  static final Map<String, _CacheEntry> _cache = {};
  static const _cacheTtl = Duration(minutes: 20);

  @override
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit = 2}) async {
    final cached = _cache[species];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.items.take(limit).toList(growable: false);
    }

    final query = _queryBySpecies[species] ?? _queryBySpecies['Altro']!;

    try {
      // The query term is percent-encoded on its own (spaces/parens as
      // %20 etc) BEFORE being embedded in the (otherwise literal) Google
      // News URL string. rss2json's own URL validator decodes `rss_url`
      // once before checking it looks like a URL, so it needs a plain
      // space to still read as `%20` after that single decode — passing
      // a literal, un-pre-encoded space (or double-encoding everything,
      // including `://`) both make it reject the value with a 422.
      final rssUrl =
          'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=it&gl=IT&ceid=IT:it';
      // Note: rss2json's `count` param requires an API key even on the
      // free tier, so items are capped client-side instead (see `.take`
      // below).
      final proxyUrl = Uri.parse(
        'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(rssUrl)}',
      );

      final response = await _client.get(proxyUrl);
      if (response.statusCode != 200) {
        // Includes 429 (rate limited): fall back to a stale cache entry
        // rather than showing nothing, if one exists.
        return cached?.items.take(limit).toList(growable: false) ?? const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'ok') {
        return cached?.items.take(limit).toList(growable: false) ?? const [];
      }

      final items = (json['items'] as List<dynamic>? ?? const [])
          .map((raw) => _toNewsItem(species, raw as Map<String, dynamic>))
          .whereType<PetNewsItem>()
          .toList(growable: false);

      _cache[species] = _CacheEntry(items, DateTime.now());
      return items.take(limit).toList(growable: false);
    } catch (_) {
      return cached?.items.take(limit).toList(growable: false) ?? const [];
    }
  }

  PetNewsItem? _toNewsItem(String species, Map<String, dynamic> item) {
    final rawTitle = (item['title'] ?? '').toString().trim();
    final link = (item['link'] ?? '').toString();
    if (rawTitle.isEmpty || link.isEmpty) {
      return null;
    }

    final normalizedTitle = rawTitle.toLowerCase();
    if (_blockedKeywords.any(normalizedTitle.contains)) {
      return null;
    }

    final separatorIndex = rawTitle.lastIndexOf(' - ');
    final headline = separatorIndex == -1 ? rawTitle : rawTitle.substring(0, separatorIndex);
    final source = separatorIndex == -1 ? 'Google News' : rawTitle.substring(separatorIndex + 3);

    return PetNewsItem(
      species: species,
      title: headline,
      extract: source,
      sourceUrl: link,
      imageUrl: (item['thumbnail'] as String?)?.isNotEmpty == true
          ? item['thumbnail'] as String
          : null,
    );
  }
}

class _CacheEntry {
  const _CacheEntry(this.items, this.fetchedAt);

  final List<PetNewsItem> items;
  final DateTime fetchedAt;
}

/// Runs [tasks] strictly one at a time, waiting [delay] between each,
/// instead of firing them all in parallel. rss2json's free/keyless tier
/// shares one global rate-limit bucket across every anonymous caller
/// worldwide (empirically: it can reject a request seconds after a
/// completely unrelated one succeeded, and accept one seconds after a
/// prior one was rejected) — pacing our own requests can't guarantee
/// avoiding a 429, since load from other users is out of our control, but
/// it at least stops a cold cache (first load) from being the cause of
/// one itself. Each `fetchForSpecies` call already degrades gracefully on
/// a 429 (falls back to a stale cache entry, or an empty list — never an
/// error shown to the user), so a rejected category just quietly shows
/// fewer cards rather than breaking anything.
Future<List<T>> fetchManyWithLimit<T>(
  List<Future<T> Function()> tasks, {
  Duration delay = const Duration(seconds: 4),
}) async {
  final results = <T>[];
  for (var i = 0; i < tasks.length; i++) {
    if (i > 0) {
      await Future<void>.delayed(delay);
    }
    results.add(await tasks[i]());
  }
  return results;
}
