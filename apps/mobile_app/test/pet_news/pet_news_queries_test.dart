import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';

http.Response _feed(List<Map<String, String>> items) {
  return http.Response(
    jsonEncode({
      'status': 'ok',
      'items': [
        for (final item in items)
          {
            'title': item['title'],
            'link': item['link'],
            'pubDate': '2026-10-01 10:00:00',
            'thumbnail': '',
          },
      ],
    }),
    200,
  );
}

String _decodedRssQuery(Uri proxyUri) {
  final rssUrl = Uri.parse(proxyUri.queryParameters['rss_url']!);
  return rssUrl.queryParameters['q']!;
}

void main() {
  group('GoogleNewsPetNewsRepository queries', () {
    test('Pesce query is aquarium-anchored and excludes culinary terms', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return _feed(const []);
      });
      await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Pesce', limit: 4);

      final query = _decodedRssQuery(requested!);
      expect(query, contains('acquario'));
      expect(query, contains('acquariofilia'));
      expect(query, contains('-ricetta'));
      expect(query, contains('-cucina'));
      expect(query, contains('-forno'));
      expect(query, isNot(contains(' pesce (')), reason: 'bare "pesce" term must not lead the query');
    });

    test('Uccello query stays on companion birds and excludes hunting/cooking', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return _feed(const []);
      });
      await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Uccello', limit: 4);

      final query = _decodedRssQuery(requested!);
      expect(query, contains('pappagallo'));
      expect(query, contains('-caccia'));
      expect(query, contains('-cucina'));
    });

    test('culinary headlines are dropped client-side, aquarium headlines kept', () async {
      final client = MockClient((request) async {
        return _feed([
          {'title': 'Ricetta del pesce al forno - Cucina Oggi', 'link': 'https://a.example/1'},
          {'title': 'Filetti fritti di pesce - Gusto', 'link': 'https://a.example/2'},
          {'title': 'Acquario: come curare il pesce rosso - Pet News', 'link': 'https://a.example/3'},
        ]);
      });

      // A distinct species key: the repository's cache is process-wide, so
      // reusing 'Pesce' would return the empty result cached by the first test.
      final items = await GoogleNewsPetNewsRepository(client: client)
          .fetchForSpecies('Altro', limit: 10);

      expect(items.map((i) => i.title), ['Acquario: come curare il pesce rosso']);
    });
  });
}
