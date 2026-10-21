import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

http.Response _news(Map<String, List<Map<String, String?>>> categories) {
  return http.Response(
    jsonEncode({
      'categories': categories,
      'available_categories': categories.keys.toList(),
      'updated_at': '2026-10-21T10:00:00+00:00',
      'stale': false,
    }),
    200,
  );
}

void main() {
  setUp(BackendPetNewsRepository.resetCache);

  group('BackendPetNewsRepository', () {
    test('reads /news once for every category and maps the items', () async {
      var calls = 0;
      Uri? requested;
      final client = MockClient((request) async {
        calls++;
        requested = request.url;
        return _news({
          'Cane': [
            {
              'title': 'Il cane corre',
              'source': 'Petsblog',
              'url': 'https://a.example/1',
              'published_at': '2026-10-20T08:00:00+00:00',
            },
            {'title': 'Senza link', 'source': 'X', 'url': ''},
          ],
          'Gatto': [
            {'title': 'Il gatto dorme', 'source': 'Dogalize', 'url': 'https://a.example/2'},
          ],
        });
      });
      final repository = BackendPetNewsRepository(
        client: client,
        configLoader: const AppRuntimeConfigLoader(),
      );

      final dogs = await repository.fetchForSpecies('Cane', limit: 4);
      final cats = await repository.fetchForSpecies('Gatto', limit: 4);
      final unknown = await repository.fetchForSpecies('Pesce', limit: 4);

      expect(requested!.path, endsWith('/news'));
      expect(calls, 1, reason: 'categories share one request and one cache entry');
      expect(dogs.map((i) => i.title), ['Il cane corre']);
      expect(dogs.single.extract, 'Petsblog');
      expect(dogs.single.sourceUrl, 'https://a.example/1');
      expect(dogs.single.publishedAt, isNotNull);
      expect(cats.single.publishedAt, isNull);
      expect(unknown, isEmpty);
    });

    test('limit caps the items of a category', () async {
      final client = MockClient((request) async {
        return _news({
          'Cane': [
            for (var i = 0; i < 5; i++)
              {'title': 'Cane $i', 'source': 'S', 'url': 'https://a.example/$i'},
          ],
        });
      });

      final items = await BackendPetNewsRepository(client: client)
          .fetchForSpecies('Cane', limit: 2);

      expect(items, hasLength(2));
    });

    test('an error from the backend gives an empty list, not an exception', () async {
      final client = MockClient((request) async => http.Response('boom', 502));

      final items = await BackendPetNewsRepository(client: client)
          .fetchForSpecies('Cane', limit: 2);

      expect(items, isEmpty);
    });

    test('an unreadable body gives an empty list', () async {
      final client = MockClient((request) async => http.Response('<html>', 200));

      final items = await BackendPetNewsRepository(client: client)
          .fetchForSpecies('Cane', limit: 2);

      expect(items, isEmpty);
    });
  });
}
