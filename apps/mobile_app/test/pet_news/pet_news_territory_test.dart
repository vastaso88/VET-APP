import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_edition.dart';

import '../territory/territory_test_helpers.dart';

http.Response _feed(List<(String, String)> items) => http.Response(
      jsonEncode({
        'status': 'ok',
        'items': [
          for (final (title, link) in items)
            {'title': title, 'link': link, 'pubDate': '2026-10-01 10:00:00', 'thumbnail': ''},
        ],
      }),
      200,
    );

Uri _googleNewsUri(Uri proxy) => Uri.parse(proxy.queryParameters['rss_url']!);

PetNewsEdition _edition(String language, String country) => petNewsEditionFor(language, country);

void main() {
  setUp(GoogleNewsPetNewsRepository.clearCache);
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

  group('GoogleNewsPetNewsRepository with fake feeds', () {
    test('the UK owner asks the UK edition in English, nothing Italian', () async {
      await useLanguageVariant('en-GB');
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        return _feed(const []);
      });
      await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Cane', limit: 4);

      final google = _googleNewsUri(requested.single);
      expect(google.host, 'news.google.com');
      expect(google.queryParameters['hl'], 'en-GB');
      expect(google.queryParameters['gl'], 'GB');
      expect(google.queryParameters['ceid'], 'GB:en');
      final query = google.queryParameters['q']!;
      expect(query, contains('dog'));
      expect(query, contains('-recipe'));
      expect(query, isNot(contains('cane')));
      expect(query, isNot(contains('-ricetta')));
    });

    test('the Spanish owner gets the Spanish edition and words', () async {
      await useLanguageVariant('es');
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return _feed(const []);
      });
      await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Gatto', limit: 4);

      final google = _googleNewsUri(requested!);
      expect(google.queryParameters['gl'], 'ES');
      expect(google.queryParameters['ceid'], 'ES:es');
      expect(google.queryParameters['q'], contains('gato'));
    });

    test('headlines in another language than the app are dropped', () async {
      await useLanguageVariant('en-US');
      final client = MockClient(
        (_) async => _feed(const [
          ('Vets say regular walks keep your dog healthy - Local Paper', 'https://example.org/a'),
          ('Sei consigli per la salute del cane che vive in casa - Giornale', 'https://example.org/b'),
        ]),
      );
      final items = await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Cane', limit: 4);

      expect(items.map((item) => item.sourceUrl), ['https://example.org/a']);
    });

    test('recipe headlines are dropped in every language', () async {
      await useLanguageVariant('de');
      final client = MockClient(
        (_) async => _feed(const [
          ('Hund im Park: Tierärzte warnen vor Hitze - Zeitung', 'https://example.org/hund'),
          ('Kaninchen Rezept für den Sonntag mit Kartoffeln und Salat - Kochblog', 'https://example.org/rezept'),
        ]),
      );
      final items = await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Cane', limit: 4);

      expect(items.map((item) => item.sourceUrl), ['https://example.org/hund']);
    });

    test('no local news means an empty list - never another country as fallback', () async {
      await useLanguageVariant('en-AU');
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return _feed(const []);
      });
      final items = await GoogleNewsPetNewsRepository(client: client).fetchForSpecies('Generale', limit: 4);

      expect(items, isEmpty);
      expect(requests, 1, reason: 'one edition asked, no second try with another country');
    });

    test('the cache is per edition: switching country never shows the old headlines', () async {
      await useLanguageVariant('en-GB');
      final client = MockClient(
        (request) async => _googleNewsUri(request.url).queryParameters['gl'] == 'GB'
            ? _feed(const [('New guide helps your dog stay healthy at home - UK Paper', 'https://example.org/uk')])
            : _feed(const [('New guide helps your dog stay healthy at home - US Paper', 'https://example.org/us')]),
      );
      final repository = GoogleNewsPetNewsRepository(client: client);

      final uk = await repository.fetchForSpecies('Cane', limit: 4);
      expect(uk.single.sourceUrl, 'https://example.org/uk');

      await useLanguageVariant('en-US');
      final us = await repository.fetchForSpecies('Cane', limit: 4);
      expect(us.single.sourceUrl, 'https://example.org/us');
    });
  });
}
