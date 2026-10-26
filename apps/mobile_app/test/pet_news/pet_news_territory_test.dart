import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_edition.dart';

import '../territory/territory_test_helpers.dart';

http.Response _news(String title) => http.Response(
      jsonEncode({
        'categories': {
          'Cane': [
            {'title': title, 'source': 'Petsblog', 'url': 'https://example.org/it'},
          ],
        },
        'available_categories': ['Cane'],
        'updated_at': '2026-10-21T10:00:00+00:00',
        'stale': false,
      }),
      200,
    );

PetNewsEdition _edition(String language, String country) => petNewsEditionFor(language, country);

void main() {
  setUp(BackendPetNewsRepository.resetCache);
  tearDown(resetTerritoryForTest);

  group('edition per country', () {
    test('each country asks Google News for its own edition and language', () {
      final cases = {
        ('it', 'IT'): ('it', 'IT', 'IT:it'),
        ('en', 'GB'): ('en-GB', 'GB', 'GB:en'),
        ('en', 'US'): ('en-US', 'US', 'US:en'),
        ('en', 'AU'): ('en-AU', 'AU', 'AU:en'),
        ('es', 'ES'): ('es', 'ES', 'ES:es'),
        ('de', 'DE'): ('de', 'DE', 'DE:de'),
        ('de', 'AT'): ('de-AT', 'AT', 'AT:de'),
        ('de', 'CH'): ('de-CH', 'CH', 'CH:de'),
        ('fr', 'FR'): ('fr', 'FR', 'FR:fr'),
        ('fr', 'BE'): ('fr-BE', 'BE', 'BE:fr'),
      };
      cases.forEach((key, expected) {
        final edition = _edition(key.$1, key.$2);
        expect((edition.hl, edition.gl, edition.ceid), expected, reason: '$key');
      });
    });

    test('every language has a query for every category', () {
      for (final language in pressLanguages) {
        final edition = _edition(language, 'IT');
        for (final category in allPetNewsCategories) {
          expect(edition.queryBySpecies[category], isNotNull, reason: '$language/$category');
        }
      }
    });

    test('a foreign-language headline is recognised, a normal one is not', () {
      expect(headlineMatchesLanguage('I cani e i gatti sono più felici con una passeggiata', 'en'), isFalse);
      expect(headlineMatchesLanguage('How to keep your dog cool in the summer heat', 'en'), isTrue);
      expect(headlineMatchesLanguage('Gli italiani e i loro cani: il nuovo rapporto', 'it'), isTrue);
      expect(headlineMatchesLanguage('The vet says the new rules are for all of the pets', 'it'), isFalse);
      expect(headlineMatchesLanguage('Der Hund ist ein treuer Begleiter für die Familie', 'de'), isTrue);
      expect(headlineMatchesLanguage('Le chien est un compagnon pour la famille et les enfants', 'fr'), isTrue);
      expect(headlineMatchesLanguage('Rex', 'en'), isTrue, reason: 'short titles are not judged');
    });
  });

  group('BackendPetNewsRepository per edition', () {
    test('the Italian edition reads our backend /news', () async {
      await useLanguageVariant('it');
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        return _news('Il cane corre nel parco');
      });
      final items = await BackendPetNewsRepository(client: client).fetchForSpecies('Cane', limit: 4);

      expect(petNewsEditionServed(), isTrue);
      expect(requested.single.path, endsWith('/news'));
      expect(items.single.sourceUrl, 'https://example.org/it');
    });

    test('an edition without backend feeds is empty, with no request at all', () async {
      for (final variant in ['en-GB', 'en-US', 'en-AU', 'de', 'de-CH', 'fr', 'es']) {
        await useLanguageVariant(variant);
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          return _news('Il cane corre nel parco');
        });
        final items = await BackendPetNewsRepository(client: client).fetchForSpecies('Cane', limit: 4);

        expect(petNewsEditionServed(), isFalse, reason: variant);
        expect(items, isEmpty, reason: '$variant: never Italian headlines as a fallback');
        expect(requests, 0, reason: '$variant: no call to the backend or to any feed');
      }
    });

    test('switching from Italian to English never shows the cached Italian headlines', () async {
      await useLanguageVariant('it');
      final client = MockClient((_) async => _news('Il cane corre nel parco'));
      final repository = BackendPetNewsRepository(client: client);
      expect(await repository.fetchForSpecies('Cane', limit: 4), isNotEmpty);

      await useLanguageVariant('en-GB');
      expect(await repository.fetchForSpecies('Cane', limit: 4), isEmpty);
    });
  });
}
