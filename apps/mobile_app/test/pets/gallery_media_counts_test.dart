import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/gallery_folders_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_gallery_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

/// QK-09: the gallery folders read the media counts of ALL the pets in one
/// request, never one full list per pet.

class _Requests {
  final calls = <({List<String> ids, bool withMediaType, int from, int to})>[];
  var pages = <List<Map<String, dynamic>>>[];
  Object? failFirstWith;

  PetMediaCountRows get source => (ids, {required withMediaType, required from, required to}) async {
        calls.add((ids: ids, withMediaType: withMediaType, from: from, to: to));
        final failure = failFirstWith;
        if (failure != null) {
          failFirstWith = null;
          throw failure;
        }
        final index = (from / 1000).floor();
        return index < pages.length ? pages[index] : <Map<String, dynamic>>[];
      };
}

Map<String, dynamic> _row(String petId, {String? type}) => {
      'pet_id': petId,
      if (type != null) 'media_type': type,
    };

PetPhotoRepository _repository(_Requests requests) =>
    PetPhotoRepository(mediaCountRows: requests.source);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('countsForPets', () {
    test('10 pets: one request, light columns, the right count for each', () async {
      final requests = _Requests()
        ..pages = [
          [
            for (var i = 0; i < 10; i++) ...[
              for (var n = 0; n <= i; n++) _row('pet-$i', type: 'photo'),
              if (i.isOdd) _row('pet-$i', type: 'video'),
            ],
          ],
        ];

      final counts = await _repository(requests).countsForPets([
        for (var i = 0; i < 10; i++) 'pet-$i',
      ]);

      expect(requests.calls, hasLength(1)); // one request for the whole group
      expect(requests.calls.single.ids, hasLength(10));
      expect(requests.calls.single.withMediaType, isTrue);
      expect(counts['pet-0']!.photos, 1);
      expect(counts['pet-0']!.videos, 0);
      expect(counts['pet-9']!.photos, 10);
      expect(counts['pet-9']!.videos, 1);
    });

    test('a pet with no media is absent and reads as zero', () async {
      final requests = _Requests()..pages = [[_row('pet-1', type: 'photo')]];

      final counts = await _repository(requests).countsForPets(['pet-1', 'pet-2']);

      expect(counts.containsKey('pet-2'), isFalse);
      expect(galleryCountLabelFor(counts['pet-2'] ?? const PetMediaCounts()), '0 foto');
    });

    test('only videos', () async {
      final requests = _Requests()
        ..pages = [[_row('pet-1', type: 'video'), _row('pet-1', type: 'video')]];

      final counts = await _repository(requests).countsForPets(['pet-1']);

      expect(galleryCountLabelFor(counts['pet-1']!), '2 video');
    });

    test('old rows without media_type count as photos', () async {
      final requests = _Requests()..pages = [[_row('pet-1'), _row('pet-1'), _row('pet-1', type: 'video')]];

      final counts = await _repository(requests).countsForPets(['pet-1']);

      expect(counts['pet-1']!.photos, 2);
      expect(galleryCountLabelFor(counts['pet-1']!), '2 foto · 1 video');
    });

    test('rows of pets that were not asked for are ignored (another owner)', () async {
      final requests = _Requests()
        ..pages = [[_row('pet-1', type: 'photo'), _row('someone-elses-pet', type: 'photo')]];

      final counts = await _repository(requests).countsForPets(['pet-1']);

      expect(counts.keys, ['pet-1']);
    });

    test('no pets, no request', () async {
      final requests = _Requests();

      final counts = await _repository(requests).countsForPets(const []);

      expect(counts, isEmpty);
      expect(requests.calls, isEmpty);
    });

    test('a big gallery is read in pages and counted in full', () async {
      final requests = _Requests()
        ..pages = [
          [for (var i = 0; i < 1000; i++) _row('pet-1', type: 'photo')],
          [for (var i = 0; i < 5; i++) _row('pet-1', type: 'video')],
        ];

      final counts = await _repository(requests).countsForPets(['pet-1']);

      expect(requests.calls.map((call) => call.from), [0, 1000]);
      expect(counts['pet-1']!.photos, 1000);
      expect(counts['pet-1']!.videos, 5);
    });

    test('a table without the video column is counted as photos, once more', () async {
      final requests = _Requests()
        ..pages = [[_row('pet-1'), _row('pet-1')]]
        ..failFirstWith = const PostgrestException(
          message: 'column pet_photos.media_type does not exist',
          code: '42703',
        );

      final counts = await _repository(requests).countsForPets(['pet-1']);

      expect(requests.calls.map((call) => call.withMediaType), [true, false]);
      expect(counts['pet-1']!.photos, 2);
    });

    test('any other error stays an error, with no second attempt', () async {
      final requests = _Requests()
        ..failFirstWith = const PostgrestException(message: 'server error', code: '500');

      await expectLater(
        _repository(requests).countsForPets(['pet-1']),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests.calls, hasLength(1));
    });
  });

  group('the folders page', () {
    final store = PetDemoStore.instance;

    setUp(() async {
      store.reset();
      await store.upsert(samplePets.first);
    });

    tearDown(store.reset);

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const GalleryFoldersPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a folder shows its caption and opens its gallery', (tester) async {
      await pumpPage(tester);

      expect(find.text(samplePets.first.name), findsOneWidget);
      expect(find.text('0 foto'), findsOneWidget); // no backend here: nothing to count

      await tester.tap(find.text(samplePets.first.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PetGalleryPage), findsOneWidget);
    });
  });
}
