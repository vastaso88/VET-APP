import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_data_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_edit_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

PetProfile _pet({
  String species = 'Cane',
  String sex = 'Maschio',
  String breed = 'Meticcio / incrocio',
  String? microchip,
  bool? sterilized,
  String? bodyCondition,
  String? activity,
  String? coat,
  String? size,
}) {
  return PetProfile(
    id: 'p-$species',
    name: 'Thor',
    species: species,
    breed: breed,
    birthDateLabel: '14 mag 2020',
    sex: sex,
    weightLabel: '23 kg',
    medicalNote: '',
    healthBadge: '',
    nextVisitLabel: '',
    avatarEmoji: 'T',
    accentColor: Colors.white,
    identityColor: Colors.green,
    microchipNumber: microchip,
    isSterilized: sterilized,
    bodyCondition: bodyCondition,
    activityLevel: activity,
    coatColor: coat,
    dogSizeCategory: size,
  );
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('Dati animale shows identity, physical traits and documents', (tester) async {
    _tallView(tester);
    final pet = _pet(
      microchip: '380260000123456',
      sterilized: true,
      bodyCondition: 'slightly_overweight',
      activity: 'active',
      coat: 'Nero e focato',
      size: 'Grande',
    );

    await tester.pumpWidget(_app(PetDataPage(petId: pet.id, initialPet: pet)));

    for (final text in [
      'Anagrafica',
      'Caratteristiche fisiche',
      'Documenti',
      'Maschio',
      '14 mag 2020',
      'Grande',
      '23 kg',
      'Leggermente sovrappeso',
      'Attivo',
      'Nero e focato',
      '380 2600 0012 3456',
      'Sì',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('Mancante'), findsNothing);
  });

  testWidgets('a dog without microchip is flagged with a way to add it', (tester) async {
    _tallView(tester);
    final pet = _pet();

    await tester.pumpWidget(_app(PetDataPage(petId: pet.id, initialPet: pet)));

    expect(find.text('Mancante'), findsOneWidget);
    expect(find.text('Per i cani il microchip è obbligatorio.'), findsOneWidget);
    expect(find.text('Aggiungi microchip'), findsOneWidget);
  });

  testWidgets('a cat without microchip is not nagged; a fish has no microchip row', (tester) async {
    _tallView(tester);
    final cat = _pet(species: 'Gatto', breed: '');
    await tester.pumpWidget(_app(PetDataPage(key: UniqueKey(), petId: cat.id, initialPet: cat)));

    expect(find.text('Mancante'), findsNothing);
    expect(find.text('Aggiungi microchip'), findsNothing);
    expect(find.text('N. microchip'), findsOneWidget);
    expect(find.text('Taglia'), findsNothing, reason: 'size is for dogs only');

    final fish = _pet(species: 'Pesce', breed: '');
    await tester.pumpWidget(_app(PetDataPage(key: UniqueKey(), petId: fish.id, initialPet: fish)));

    expect(find.text('N. microchip'), findsNothing);
    expect(find.text('Corporatura'), findsNothing);
    expect(find.text('Sesso'), findsNothing);
  });

  testWidgets('the summary row on the pet page shows sex, weight and neutering', (tester) async {
    final pet = _pet(sterilized: true);

    await tester.pumpWidget(_app(Scaffold(body: PetDataSummaryRow(pet: pet))));

    expect(find.textContaining('Dati animale · Maschio · 23 kg · sterilizzato'), findsOneWidget);
  });

  testWidgets('editing a pet saved with "Femmina sterilizzata" shows Femmina and the switch on',
      (tester) async {
    _tallView(tester);
    // What the app now makes of an old row (see PetDemoStore.petFromRow) — and
    // what a pet still held in memory with the old value is shown as.
    final pet = _pet(species: 'Gatto', sex: 'Femmina sterilizzata', breed: '');

    await tester.pumpWidget(_app(PetEditPage(pet: pet)));
    await tester.pumpAndSettle();

    final segments = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(segments.selected, {'Femmina'});
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
