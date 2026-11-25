import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/design_system/atoms/animal_figure.dart';
import 'package:vet_app_mobile/features/pets/application/pet_face.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_video_rules.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_gallery_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/pet_avatar.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/species_figure.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// One face for an animal, on every page (cards G1-D01 and G1-H02).

final _pet = samplePets.first;

PetPhotoEntry _photo(String id, {bool chosen = false, bool video = false}) => PetPhotoEntry(
      id: id,
      petId: _pet.id,
      storagePath: 'owner/pet/$id.jpg',
      createdAt: DateTime(2026, 11, 25),
      isProfile: chosen,
      kind: video ? PetMediaKind.video : PetMediaKind.photo,
    );

Uint8List _jpeg(int width, int height) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: width, height: height)));

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: home,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('the photo chosen as face', () {
    test('a photo chosen in the gallery becomes the face (it used to erase it)', () {
      final pet = _pet.copyWith(photoPath: 'owner/pet/old.jpg', photoBytes: Uint8List(1));
      final chosen = pet.copyWith(photoPath: 'owner/pet/new.jpg', clearPhoto: true);
      expect(chosen.photoPath, 'owner/pet/new.jpg');
      expect(chosen.photoBytes, isNull);
      final removed = chosen.copyWith(clearPhoto: true);
      expect(removed.photoPath, isNull);
    });

    test('the store shows it on every page at once', () async {
      final store = PetDemoStore.instance..reset();
      addTearDown(store.reset);
      await store.upsert(_pet.copyWith(photoBytes: Uint8List(1)));
      final before = PetDemoStore.changes.value;
      store.setPhotoLocal(_pet.id, 'owner/pet/new.jpg');
      expect(store.byId(_pet.id)!.photoPath, 'owner/pet/new.jpg');
      expect(store.byId(_pet.id)!.photoBytes, isNull);
      expect(PetDemoStore.changes.value, greaterThan(before));
    });

    test('photos only added to the gallery: the newest becomes the face by itself', () {
      expect(faceToAdopt(_pet, [_photo('new'), _photo('old')])!.id, 'new');
      expect(faceToAdopt(_pet, [_photo('film', video: true), _photo('old')])!.id, 'old');
      expect(faceToAdopt(_pet, [_photo('film', video: true)]), isNull);
      expect(faceToAdopt(_pet, const []), isNull);
    });

    test('the face deleted from the gallery: the newest photo left takes its place', () {
      // The row of the deleted face went with it: nothing says "chosen" any more.
      expect(faceToAdopt(_pet, [_photo('newer'), _photo('older')])!.id, 'newer');
    });

    test('a face already there, or taken away by the owner, is left as it is', () {
      expect(faceToAdopt(_pet.copyWith(photoPath: 'owner/pet/x.jpg'), [_photo('new')]), isNull);
      expect(faceToAdopt(_pet.copyWith(photoBytes: Uint8List(1)), [_photo('new')]), isNull);
      expect(faceToAdopt(_pet, [_photo('new'), _photo('old', chosen: true)]), isNull);
      expect(faceToAdopt(_pet.copyWith(isMemorial: true), [_photo('new')]), isNull);
    });
  });

  group('the avatar', () {
    Future<void> pump(WidgetTester tester, PetProfile pet, {double size = 48}) =>
        tester.pumpWidget(_app(Center(child: PetRingAvatar(pet: pet, size: size))));

    BoxDecoration ringOf(WidgetTester tester) => tester
        .widget<Container>(
          find.descendant(of: find.byType(PetRingAvatar), matching: find.byType(Container)).first,
        )
        .decoration! as BoxDecoration;

    testWidgets('without a photo: the figure of the species in a ring of its colour',
        (tester) async {
      await pump(tester, _pet);
      expect(ringOf(tester).border, Border.all(color: _pet.identityColor, width: 3));
      expect(
        tester.widget<AnimalFigureIcon>(find.byType(AnimalFigureIcon)).figure,
        AnimalFigure.dog,
      );
      expect(find.byType(Text), findsNothing, reason: 'no initial, let alone two');
    });

    testWidgets('with a photo: the photo, decoded at the size shown', (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      for (final (width, height) in [(1600, 1200), (1200, 1600)]) {
        await tester.pumpWidget(const SizedBox());
        final bytes = _jpeg(width, height);
        await pump(tester, _pet.copyWith(photoBytes: bytes));
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.cover);
        await tester.runAsync(
          () => precacheImage(image.image, tester.element(find.byType(Image))),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(SpeciesFigure), findsNothing);

        final side = tester.getSize(find.byType(Image)).width;
        final decoded = tester.renderObject<RenderBox>(find.byType(RawImage));
        expect(decoded.size, Size.square(side), reason: 'it fills the ring');
        final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
        // Not its own 1600 px, and not stretched; sharp on its short side too.
        expect(pixels.width / pixels.height, closeTo(width / height, 0.02));
        expect(pixels.width, lessThan(400));
        expect(pixels.height, lessThan(400));
        expect(
          pixels.width < pixels.height ? pixels.width : pixels.height,
          greaterThanOrEqualTo((side * 2).floor()),
        );
      }
    });

    testWidgets('bytes that are no picture: the figure', (tester) async {
      await pump(tester, _pet.copyWith(photoBytes: Uint8List.fromList([1, 2, 3])));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      tester.takeException();
      expect(find.byType(SpeciesFigure), findsOneWidget);
    });

    testWidgets('a saved photo that is not there yet: the figure meanwhile', (tester) async {
      await pump(tester, _pet.copyWith(photoPath: 'owner/pet/face.jpg'));
      expect(find.byType(StoredPetPhoto), findsOneWidget);
      expect(find.byType(SpeciesFigure), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('the figures', () {
    test('one drawing per species; the neutral paw for an animal without one', () {
      AnimalFigure of(String species, [String? breed]) => SpeciesFigure.figureFor(species, breed);
      expect(of('Cane'), AnimalFigure.dog);
      expect(of('Gatto'), AnimalFigure.cat);
      expect(of('Piccoli mammiferi'), AnimalFigure.smallMammal);
      expect(of('Piccoli mammiferi', 'Coniglio nano'), AnimalFigure.rabbit);
      expect(of('Uccello'), AnimalFigure.bird);
      expect(of('Altro', 'Gallina'), AnimalFigure.bird);
      expect(of('Rettili e anfibi'), AnimalFigure.reptile);
      expect(of('Pesce'), AnimalFigure.fish);
      expect(of('Rettili e anfibi', 'Axolotl'), AnimalFigure.paw);
      expect(of('Altro', 'Cavallo'), AnimalFigure.paw);
      expect(of('Altro'), AnimalFigure.paw);
      expect(of('Generale'), AnimalFigure.paw);
    });

    testWidgets('every drawing fits its box and is not empty', (tester) async {
      for (final figure in AnimalFigure.values) {
        await tester.pumpWidget(
          Center(
            child: RepaintBoundary(
              child: AnimalFigureIcon(figure, size: 32, color: const Color(0xFF000000)),
            ),
          ),
        );
        await expectLater(
          find.byType(CustomPaint),
          paints..path(color: const Color(0xFF000000)),
          reason: figure.name,
        );
      }
    });

    testWidgets('inside a pill: only the figure, in the colour of the text', (tester) async {
      await tester.pumpWidget(const Center(
        child: SpeciesFigure.glyph(species: 'Gatto', size: 20, color: Color(0xFF123456)),
      ));
      final icon = tester.widget<AnimalFigureIcon>(find.byType(AnimalFigureIcon));
      expect(icon.color, const Color(0xFF123456));
      expect(tester.getSize(find.byType(AnimalFigureIcon)), const Size.square(20));
    });

    test('no page shows an animal emoji of its own', () {
      // The strip is not on any page; the texts of the app are the translators'.
      const allowed = ['lib/app/splash/', 'lib/l10n/'];
      final animals = RegExp('[\u{1F400}-\u{1F43F}\u{1F980}-\u{1F9AE}]', unicode: true);
      final offenders = [
        for (final entity in Directory('lib').listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            if (entity.path.replaceAll(r'\', '/') case final path
                when !allowed.any(path.startsWith) && animals.hasMatch(entity.readAsStringSync()))
              path,
      ];
      expect(offenders, isEmpty, reason: 'use SpeciesFigure');
    });
  });

  group('the gallery of one animal', () {
    testWidgets('empty: its face, one command to add the first photo', (tester) async {
      await tester.pumpWidget(_app(PetGalleryPage(pet: _pet)));
      await tester.pumpAndSettle();
      expect(find.byType(PetRingAvatar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
      await tester.pumpAndSettle();
      expect(find.text('Scatta foto'), findsOneWidget);
    });

    testWidgets('in Ricordi: nothing is asked', (tester) async {
      await tester.pumpWidget(_app(PetGalleryPage(pet: _pet.copyWith(isMemorial: true))));
      await tester.pumpAndSettle();
      expect(find.text('Non ci sono ancora foto.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
