import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/area_label_geocoder.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/content_policy.dart';
import 'package:vet_app_mobile/features/marketplace/domain/listing_content.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/create_listing_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/listing_detail_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/my_listings_page.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

import '../territory/territory_test_helpers.dart';

class _ConfigWithBackend extends AppRuntimeConfigLoader {
  const _ConfigWithBackend();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

class _Gps implements LocationSampler {
  const _Gps();

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async =>
      const DeviceLocationResult.success(Coordinates(latitude: 45.46, longitude: 9.19));
}

class _Zone implements AreaLabelResolver {
  @override
  Future<String?> areaLabelOf(Coordinates approximated) async => 'Milano';
}

MarketplaceRepository _repository(MockClient client) => MarketplaceRepository(
      httpClient: client,
      configLoader: const _ConfigWithBackend(),
      tokenProvider: () => 'jwt',
    );

Map<String, dynamic> _row(String id, {String status = 'active', Object? removal}) => {
      'id': id,
      'owner_id': 'seller-1',
      'title': 'Ciotola $id',
      'category': 'feeding',
      'condition': 'good',
      'price_cents': 1000,
      'photo_urls': <String>[],
      'target_species': ['dog'],
      'latitude': 45.46,
      'longitude': 9.19,
      'country': 'IT',
      'status': status,
      'created_at': '2026-11-23T10:00:00Z',
      'updated_at': '2026-11-23T10:00:00Z',
      'removal': removal,
    };

http.Response _json(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Refuses until every wanted box is in the request, like the backend.
class _Backend {
  _Backend(this.wanted);

  final List<String> wanted;
  final bodies = <Map<String, dynamic>>[];

  late final client = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    bodies.add(body);
    final confirmed = (body['content_confirmations'] as List<dynamic>).cast<String>();
    if (wanted.every(confirmed.contains)) return _json({'listing': _row('new')}, 200);
    return _json({
      'detail': 'Il testo nomina cibo…',
      'code': 'content_confirmation_required',
      'message': '…',
      'fix': {
        'field': 'content_confirmations',
        'value': wanted,
        'terms': [
          for (final notice in wanted)
            {'notice': notice, 'text': notice == 'food' ? 'crocchette' : 'antipulci'},
        ],
      },
    }, 400);
  });
}

Future<void> _tall(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _openForm(WidgetTester tester, _Backend backend, {MarketplaceListing? existing}) async {
  await _tall(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (_) => CreateListingPage(
                existing: existing,
                locationSampler: const _Gps(),
                areaLabelResolver: _Zone(),
                repository: _repository(backend.client),
                currentOwnerId: 'seller-1',
              ),
            ),
          ),
          child: const Text('apri'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  if (existing == null) {
    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Ciotola per crocchette');
    await tester.tap(find.byType(DropdownButtonFormField<ListingCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giochi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cane'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Prezzo in €'), '10');
  }
  await tester.tap(find.byKey(const ValueKey('marketplace-private-seller')));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester, {bool editing = false}) async {
  await tester.tap(find.text(editing ? 'Salva modifiche' : 'Pubblica annuncio'));
  await tester.pumpAndSettle();
}

OutlinedButton _publishButton(WidgetTester tester) => tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('marketplace-content-publish')),
    );

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() async => useLanguageVariant('it'));
  tearDown(resetTerritoryForTest);

  group('the notice', () {
    testWidgets('its box is never pre-ticked and publishing needs it', (tester) async {
      final backend = _Backend(['food']);
      await _openForm(tester, backend);
      await _submit(tester);

      expect(find.text('Cibo o integratori?'), findsOneWidget);
      expect(find.text('Parole trovate nel testo: crocchette'), findsOneWidget);
      expect(find.textContaining('Una conferma falsa'), findsOneWidget);
      final box = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('marketplace-content-food')),
      );
      expect(box.value, isFalse);
      expect(_publishButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('marketplace-content-food')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('marketplace-content-publish')));
      await tester.pumpAndSettle();

      expect(backend.bodies.map((body) => body['content_confirmations']), [
        <String>[],
        ['food'],
      ]);
      expect(find.text('apri'), findsOneWidget, reason: 'published: back to the Mercatino');
    });

    testWidgets('"Modifica l\'annuncio" goes back to the form and sends nothing', (tester) async {
      final backend = _Backend(['food']);
      await _openForm(tester, backend);
      await _submit(tester);

      await tester.tap(find.byKey(const ValueKey('marketplace-content-edit')));
      await tester.pumpAndSettle();

      expect(backend.bodies, hasLength(1));
      expect(find.text('Ciotola per crocchette'), findsOneWidget, reason: 'the form is kept');
      expect(find.text('Pubblica annuncio'), findsOneWidget);
    });

    testWidgets('two notices need two boxes', (tester) async {
      final backend = _Backend(['food', 'active_substance']);
      await _openForm(tester, backend);
      await _submit(tester);

      expect(find.text('Principi attivi?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('marketplace-content-food')));
      await tester.pump();
      expect(_publishButton(tester).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('marketplace-content-active_substance')));
      await tester.pump();
      expect(_publishButton(tester).onPressed, isNotNull);
    });

    testWidgets('the two buttons weigh the same', (tester) async {
      final backend = _Backend(['food']);
      await _openForm(tester, backend);
      await _submit(tester);

      for (final key in ['marketplace-content-edit', 'marketplace-content-publish']) {
        expect(tester.widget(find.byKey(ValueKey(key))), isA<OutlinedButton>());
      }
    });

    testWidgets('an edit asks again', (tester) async {
      final backend = _Backend(['active_substance']);
      final now = DateTime(2026, 11, 23);
      await _openForm(
        tester,
        backend,
        existing: MarketplaceListing(
          id: 'ad',
          ownerId: 'seller-1',
          title: 'Pettine antipulci',
          category: ListingCategory.hygieneGrooming,
          condition: ListingCondition.good,
          priceCents: 500,
          species: const [ListingSpecies.dog],
          location: const Coordinates(latitude: 45.46, longitude: 9.19),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _submit(tester, editing: true);

      expect(find.text('Principi attivi?'), findsOneWidget);
    });

    test('a notice this version does not know is refused, never confirmed blindly', () {
      expect(
        ListingConfirmationRequiredException.fromJson({
          'code': 'content_confirmation_required',
          'fix': {
            'value': ['food', 'something_new'],
          },
        }),
        isNull,
      );
    });
  });

  test('a refused medicine says it was automatic and how to ask for a review', () async {
    final repository = _repository(
      MockClient(
        (_) async => _json({
          'detail': medicinePolicyBackendMessage,
          'code': 'content_refused',
          'terms': ['collare antipulci'],
        }, 400),
      ),
    );
    final now = DateTime(2026, 11, 23);

    await expectLater(
      repository.createListing(
        MarketplaceListing(
          id: 'ad',
          ownerId: 'seller-1',
          title: 'Collare antipulci',
          category: ListingCategory.other,
          condition: ListingCondition.good,
          location: const Coordinates(latitude: 45.46, longitude: 9.19),
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsA(
        isA<ListingRejectedException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('Annuncio non pubblicato'),
            contains(
              'Parole trovate nel testo: collare antipulci. '
              'Il controllo è automatico e può sbagliare.',
            ),
            contains('Impostazioni → Contattaci'),
          ),
        ),
      ),
    );
  });

  group('my ads', () {
    final removal = {
      'reason': 'food',
      'decided_at': '2026-11-23T10:00:00Z',
      'terms': ['crocchette'],
    };

    MarketplaceRepository backend() => _repository(
          MockClient((request) async {
            expect(request.url.path, '/marketplace/listings/mine');
            return _json({
              'listings': [
                _row('a'),
                _row('b', status: 'removed_policy', removal: removal),
              ],
            }, 200);
          }),
        );

    testWidgets('an ad the team took down is there, with the reason and the review', (
      tester,
    ) async {
      await _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: MyListingsPage(repository: backend(), currentOwnerId: 'seller-1')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Pubblicato'), findsOneWidget);
      expect(find.textContaining('Tolto dal team'), findsOneWidget);
      final notice = find.byKey(const ValueKey('listing-removal-notice'));
      expect(notice, findsOneWidget);
      for (final part in [
        'Motivo: cibo o mangimi',
        'una persona del team',
        'crocchette',
        'Impostazioni → Contattaci',
        'rivolgerti al giudice',
      ]) {
        expect(
          find.descendant(of: notice, matching: find.textContaining(part)),
          findsOneWidget,
          reason: part,
        );
      }
      expect(find.textContaining('In verifica'), findsNothing);
    });

    Future<void> pumpOne(WidgetTester tester, Map<String, Object?> removal) async {
      await _tall(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: MyListingsPage(
            repository: _repository(
              MockClient(
                (_) async => _json({
                  'listings': [
                    _row(
                      'x',
                      status: removal['kind'] == 'reports' ? 'removed' : 'removed_policy',
                      removal: removal,
                    ),
                  ],
                }, 200),
              ),
            ),
            currentOwnerId: 'seller-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder inNotice(String text) => find.descendant(
          of: find.byKey(const ValueKey('listing-removal-notice')),
          matching: find.textContaining(text),
        );

    testWidgets('an ad hidden after several reports waits for the team, with the date', (
      tester,
    ) async {
      await pumpOne(tester, {
        'kind': 'reports',
        'reason': null,
        'decided_at': '2026-11-23',
        'terms': <String>[],
      });

      expect(find.textContaining('Nascosto in attesa di controllo'), findsOneWidget);
      for (final part in [
        'Annuncio nascosto il 23 nov 2026',
        'segnalato da più persone',
        'La decisione è automatica',
        'Impostazioni → Contattaci',
      ]) {
        expect(inNotice(part), findsOneWidget, reason: part);
      }
      expect(inNotice('una persona del team'), findsNothing);
    });

    testWidgets('an ad taken down after a report says why, without words found', (tester) async {
      await pumpOne(tester, {
        'kind': 'team',
        'reason': 'scam',
        'decided_at': '2026-11-23T10:00:00Z',
        'terms': <String>[],
      });

      expect(inNotice('Motivo: sospetta truffa'), findsOneWidget);
      expect(inNotice('una persona del team'), findsOneWidget);
      expect(inNotice('controllo automatico del testo'), findsNothing);
    });

    testWidgets('an ad hidden by the rule on animals says the rule', (tester) async {
      await pumpOne(tester, {
        'kind': 'rule',
        'reason': 'sells_animals',
        'decided_at': '2026-11-23',
        'terms': <String>[],
      });

      expect(inNotice('Annuncio nascosto il 23 nov 2026'), findsOneWidget);
      expect(inNotice('il testo sembra offrire un animale'), findsOneWidget);
      expect(inNotice('La decisione è automatica'), findsOneWidget);
      expect(inNotice('Impostazioni → Contattaci'), findsOneWidget);
      expect(inNotice('una persona del team'), findsNothing);
    });

    testWidgets('it can be deleted but not edited', (tester) async {
      await _tall(tester);
      final ads = await backend().loadMyListings(requesterId: 'seller-1');
      await tester.pumpWidget(
        MaterialApp(
          home: ListingDetailPage(
            listing: ads.last,
            repository: backend(),
            currentOwnerId: 'seller-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('listing-removal-notice')), findsOneWidget);
      expect(find.text('Modifica annuncio'), findsNothing);
      expect(find.text('Elimina annuncio'), findsOneWidget);
    });

    testWidgets('a failed read offers to try again', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyListingsPage(
            repository: _repository(MockClient((_) async => http.Response('', 500))),
            currentOwnerId: 'seller-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riprova'), findsOneWidget);
    });

    testWidgets('a server without this list does not blame the connection', (tester) async {
      // Build 45 against the production server (24/11/2026): 404.
      for (final status in [404, 405, 500]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(status),
            home: MyListingsPage(
              repository: _repository(MockClient((_) async => http.Response('', status))),
              currentOwnerId: 'seller-1',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Controlla la connessione'), findsNothing);
        expect(find.textContaining('non è raggiungibile in questo momento'), findsOneWidget);
      }
    });

    test('without a backend each owner sees only their own ads', () async {
      final now = DateTime(2026, 11, 23);
      MarketplaceListing ad(String id, String owner) => MarketplaceListing(
            id: id,
            ownerId: owner,
            title: id,
            category: ListingCategory.toys,
            condition: ListingCondition.good,
            location: const Coordinates(latitude: 45.46, longitude: 9.19),
            createdAt: now,
            updatedAt: now,
          );
      final repository =
          MarketplaceRepository.inMemory([ad('mine', 'seller-1'), ad('theirs', 'seller-2')]);

      final mine = await repository.loadMyListings(requesterId: 'seller-1');

      expect(mine.map((item) => item.id), ['mine']);
    });
  });
}
