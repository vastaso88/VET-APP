import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/activities/presentation/pages/activities_page.dart';
import 'package:vet_app_mobile/features/travel_guide/data/travel_cards_repository.dart';
import 'package:vet_app_mobile/features/travel_guide/domain/travel_card.dart';
import 'package:vet_app_mobile/features/travel_guide/domain/travel_countries.dart';
import 'package:vet_app_mobile/features/travel_guide/domain/travel_resolver.dart';
import 'package:vet_app_mobile/features/travel_guide/presentation/pages/travel_guide_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

import '../support/fields.dart';

TravelCard _card(
  String country,
  TravelSpecies species, {
  TravelCardVisibility visibility = TravelCardVisibility.fresh,
  List<TravelBlock>? blocks,
}) =>
    TravelCard(
      id: 'via-${country.toLowerCase()}-${species.wire}',
      country: country,
      species: species,
      title: 'Titolo',
      checkedOn: DateTime(2026, 11, 16),
      officialUrl: 'https://example.com/official',
      visibility: visibility,
      blocks: visibility == TravelCardVisibility.hidden
          ? const []
          : blocks ??
              const [
                TravelBlock(kind: 'documenti', sentences: [
                  TravelSentence(text: 'Frase per tutti.'),
                  TravelSentence(text: 'Solo da UE.', origins: [TravelOrigin.eu]),
                  TravelSentence(text: 'Solo da fuori UE.', origins: [TravelOrigin.nonEu]),
                ]),
                TravelBlock(kind: 'quando_andare_dal_veterinario', sentences: [
                  TravelSentence(text: 'Parlane col veterinario.', own: true),
                ]),
              ],
    );

class _FakeRepository implements TravelCardsRepository {
  _FakeRepository(this.cards, {this.fail = false});

  final List<TravelCard> cards;
  final bool fail;

  @override
  Future<List<TravelCard>> fetchAll() async {
    if (fail) throw const TravelCardsUnavailable();
    return cards;
  }
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('countries', () {
    test('a member state is an EU origin and every other country is not', () {
      expect(originFor('DE'), TravelOrigin.eu);
      expect(originFor('it'), TravelOrigin.eu);
      expect(originFor('GB'), TravelOrigin.nonEu);
      expect(originFor('CH'), TravelOrigin.nonEu);
    });

    test('the EU has exactly 27 members and all are in the list', () {
      expect(euMemberStates.length, 27);
      for (final code in euMemberStates) {
        expect(travelCountryByCode(code), isNotNull, reason: code);
      }
    });

    test('codes are unique', () {
      final codes = travelCountries.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('search ignores accents and capitals and knows the usual aliases', () {
      expect(searchTravelCountries('PERU').map((c) => c.code), contains('PE'));
      expect(searchTravelCountries('citta del').map((c) => c.code), contains('VA'));
      expect(searchTravelCountries('uk').first.code, 'GB');
      expect(searchTravelCountries('Dubai').map((c) => c.code), ['AE']);
      expect(searchTravelCountries('zzzz'), isEmpty);
      expect(searchTravelCountries('').length, travelCountries.length);
    });

    test('the normalisation maps every accented letter to its plain one', () {
      expect(normalizeCountryText('Perù  Città-ñ'), 'peru citta n');
    });

    test('a flag is built from the code', () {
      expect(travelCountryByCode('IT')!.flag, '\u{1F1EE}\u{1F1F9}');
    });
  });

  group('resolver', () {
    final cards = [
      _card('EU', TravelSpecies.dog),
      _card('GB', TravelSpecies.dog),
      _card('EU', TravelSpecies.cat),
    ];

    test('any member state is answered by the card common to the Union', () {
      final answer = resolveTravel(
        cards: cards,
        fromCode: 'IT',
        toCode: 'DE',
        species: TravelSpecies.dog,
      );

      expect(answer, isA<TravelCardAnswer>());
      expect((answer as TravelCardAnswer).card.country, 'EU');
      expect(answer.origin, TravelOrigin.eu);
    });

    test('Great Britain has its own card and a third country is not an EU origin', () {
      final answer = resolveTravel(
        cards: cards,
        fromCode: 'IT',
        toCode: 'GB',
        species: TravelSpecies.dog,
      ) as TravelCardAnswer;
      final back = resolveTravel(
        cards: cards,
        fromCode: 'GB',
        toCode: 'IT',
        species: TravelSpecies.dog,
      ) as TravelCardAnswer;

      expect(answer.card.country, 'GB');
      expect(back.card.country, 'EU');
      expect(back.origin, TravelOrigin.nonEu);
    });

    test('no card means no card: never another country\'s', () {
      expect(
        resolveTravel(cards: cards, fromCode: 'IT', toCode: 'JP', species: TravelSpecies.dog),
        isA<NoTravelCardAnswer>(),
      );
      expect(
        resolveTravel(cards: cards, fromCode: 'IT', toCode: 'GB', species: TravelSpecies.cat),
        isA<NoTravelCardAnswer>(),
      );
    });

    test('a species without cards gets the generic answer', () {
      expect(
        resolveTravel(cards: cards, fromCode: 'IT', toCode: 'DE', species: null),
        isA<OtherSpeciesAnswer>(),
      );
    });

    test('the blocks keep only the sentences of the origin, in the fixed order', () {
      final fromEu = resolveTravel(
        cards: cards,
        fromCode: 'IT',
        toCode: 'DE',
        species: TravelSpecies.dog,
      ) as TravelCardAnswer;
      final fromOutside = resolveTravel(
        cards: cards,
        fromCode: 'GB',
        toCode: 'DE',
        species: TravelSpecies.dog,
      ) as TravelCardAnswer;

      expect(
        fromEu.blocks.first.sentences.map((s) => s.text),
        ['Frase per tutti.', 'Solo da UE.'],
      );
      expect(
        fromOutside.blocks.first.sentences.map((s) => s.text),
        ['Frase per tutti.', 'Solo da fuori UE.'],
      );
      expect(fromEu.blocks.map((b) => b.kind), ['documenti', 'quando_andare_dal_veterinario']);
    });
  });

  group('repository', () {
    const body = {
      'cards': [
        {
          'id': 'via-eu-can',
          'country': 'EU',
          'species': 'dog',
          'title': 'UE',
          'checked_on': '2026-11-16',
          'official_url': 'https://example.com',
          'visibility': 'old',
          'blocks': [
            {
              'kind': 'documenti',
              'title': 'Documenti',
              'sentences': [
                {'text': 'Frase.', 'origins': ['EU'], 'own': false, 'source_ids': ['s']},
              ],
            },
          ],
          'sources': [
            {'id': 's', 'citation': 'Fonte: x', 'url': 'https://example.com/s'},
          ],
        },
        {'id': 'x', 'country': 'XX', 'species': 'parrot'},
      ],
    };

    setUp(BackendTravelCardsRepository.resetCache);

    BackendTravelCardsRepository repo(http.Client client, {String? token = 'tok'}) =>
        BackendTravelCardsRepository(
          client: client,
          configLoader: const _Config(),
          tokenProvider: () => token,
        );

    test('it reads the cards with no query at all, and skips the unknown species', () async {
      late Uri seen;
      final client = MockClient((request) async {
        seen = request.url;
        expect(request.headers['Authorization'], 'Bearer tok');
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      });

      final cards = await repo(client).fetchAll();

      expect(seen.toString(), 'https://api.example.com/travel/cards');
      expect(seen.hasQuery, isFalse);
      expect(cards, hasLength(1));
      expect(cards.single.visibility, TravelCardVisibility.old);
      expect(cards.single.blocks.single.sentences.single.origins, [TravelOrigin.eu]);
    });

    test('a failure is reported, and without a session nothing is asked', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('no', 500);
      });

      await expectLater(repo(client).fetchAll(), throwsA(isA<TravelCardsUnavailable>()));
      BackendTravelCardsRepository.resetCache();
      await expectLater(repo(client, token: null).fetchAll(), throwsA(isA<TravelCardsUnavailable>()));
      expect(calls, 1);
    });

    test('the answer is kept: the second reading costs no request', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      });
      final repository = repo(client);

      await repository.fetchAll();
      await repository.fetchAll();

      expect(calls, 1);
    });
  });

  group('screen', () {
    testWidgets('it asks for the three choices before showing anything', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(TravelGuidePage(repository: _FakeRepository([]))));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Mostra le informazioni'));
      await tester.pump();

      expect(find.text('Scegli da dove parti, dove vai e chi porti con te.'), findsOneWidget);
      expect(find.textContaining('non incoraggia a spostare né a importare'), findsOneWidget);
    });

    testWidgets('it shows the card for the chosen trip, filtered by origin', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(TravelGuidePage(repository: _FakeRepository([_card('EU', TravelSpecies.dog)]))),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(pickerNamed('Dove vai'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'germania');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Germania'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cane'));
      await tester.pump();
      await tester.tap(find.text('Mostra le informazioni'));
      await tester.pumpAndSettle();

      expect(find.textContaining('da Italia a Germania'), findsOneWidget);
      expect(find.text('Frase per tutti.'), findsOneWidget);
      expect(find.text('Solo da UE.'), findsOneWidget);
      expect(find.text('Solo da fuori UE.'), findsNothing);
      expect(find.text('Consiglio di Quokka (non della fonte)'), findsOneWidget);
      expect(find.textContaining('Verificato il'), findsOneWidget);
      expect(find.textContaining('Le regole ufficiali prevalgono'), findsOneWidget);
    });

    testWidgets('a trip with no card says so, and an old card warns', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          TravelGuidePage(
            repository: _FakeRepository([
              _card('GB', TravelSpecies.dog, visibility: TravelCardVisibility.old),
              _card('EU', TravelSpecies.dog, visibility: TravelCardVisibility.hidden),
            ]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      Future<void> trip(String to, String pick) async {
        await tester.tap(pickerNamed('Dove vai'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), to);
        await tester.pumpAndSettle();
        await tester.tap(find.text(pick).last);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Cane'));
      await trip('giappone', 'Giappone');
      await tester.tap(find.text('Mostra le informazioni'));
      await tester.pumpAndSettle();
      expect(find.textContaining('non abbiamo ancora una scheda verificata'), findsOneWidget);

      await trip('regno', 'Regno Unito');
      await tester.tap(find.text('Mostra le informazioni'));
      await tester.pumpAndSettle();
      expect(find.textContaining('potrebbe essere cambiata'), findsOneWidget);

      await trip('francia', 'Francia');
      await tester.tap(find.text('Mostra le informazioni'));
      await tester.pumpAndSettle();
      expect(find.textContaining('non la mostriamo'), findsOneWidget);
      expect(find.text('Apri la fonte ufficiale'), findsOneWidget);
    });

    testWidgets('a failure to load offers a retry', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(TravelGuidePage(repository: _FakeRepository([], fail: true))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(pickerNamed('Dove vai'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'francia');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Francia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gatto'));
      await tester.pump();

      await tester.tap(find.text('Mostra le informazioni'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Non riesco a caricare le schede'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
    });
  });

  group('activities menu', () {
    testWidgets('the row appears only when at least one approved card exists', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(ActivitiesPage(travelCardsRepository: _FakeRepository([]))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Around the world'), findsNothing);

      await tester.pumpWidget(
        _app(ActivitiesPage(travelCardsRepository: _FakeRepository([], fail: true))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Around the world'), findsNothing);

      await tester.pumpWidget(
        _app(
          ActivitiesPage(
            key: UniqueKey(),
            travelCardsRepository: _FakeRepository([_card('EU', TravelSpecies.dog)]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Around the world'), findsOneWidget);
    });
  });
}

class _Config extends AppRuntimeConfigLoader {
  const _Config();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.example.com',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}
