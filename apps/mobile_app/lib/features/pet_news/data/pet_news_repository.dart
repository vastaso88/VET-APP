import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/pet_news_item.dart';

abstract class PetNewsRepository {
  Future<List<PetNewsItem>> fetchForSpecies(String species);
}

/// Free, keyless "curiosita" source: real headlines from real newspapers,
/// via Google News' public RSS search, bridged through rss2json.com (a
/// free CORS-friendly RSS-to-JSON proxy — Google News' own RSS endpoint
/// blocks direct browser fetches). Swappable behind [PetNewsRepository]
/// for a paid/higher-quality provider later.
class GoogleNewsPetNewsRepository implements PetNewsRepository {
  GoogleNewsPetNewsRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _queryBySpecies = {
    'Cane': 'cane',
    'Gatto': 'gatto',
    'Coniglio': 'coniglio',
    'Uccello': 'uccello',
    'Rettile': 'rettile',
    'Pesce': 'pesce',
    'Altro': 'animali domestici',
    'Generale': 'animali domestici (fiera OR legge OR normativa)',
  };

  static const _maxItemsPerSpecies = 2;

  @override
  Future<List<PetNewsItem>> fetchForSpecies(String species) async {
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
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'ok') {
        return const [];
      }

      final items = (json['items'] as List<dynamic>? ?? const [])
          .take(_maxItemsPerSpecies)
          .map((raw) => _toNewsItem(species, raw as Map<String, dynamic>))
          .whereType<PetNewsItem>()
          .toList(growable: false);
      return items;
    } catch (_) {
      return const [];
    }
  }

  PetNewsItem? _toNewsItem(String species, Map<String, dynamic> item) {
    final rawTitle = (item['title'] ?? '').toString().trim();
    final link = (item['link'] ?? '').toString();
    if (rawTitle.isEmpty || link.isEmpty) {
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
