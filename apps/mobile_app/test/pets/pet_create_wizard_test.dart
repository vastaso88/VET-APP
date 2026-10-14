import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_create_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pets_list_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// Opens the creation page on top of a plain route, like the Animali list does.
Future<void> _openWizard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PetCreatePage()),
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

Future<void> _tapNext(WidgetTester tester, [String label = 'Prosegui']) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Finder _nameField() => find.widgetWithText(TextFormField, 'Nome');

void main() {
  testWidgets('the creation flow has four steps, then "Profilo creato!"', (tester) async {
    await _openWizard(tester);

    // 1 - name, photo, sex
    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    await tester.enterText(_nameField(), 'Thor');
    await tester.tap(find.text('Maschio'));
    await tester.pump();
    await _tapNext(tester);

    // 2 - species chip, then Di razza / Meticcio
    expect(find.text('Specie e razza'), findsOneWidget);
    await tester.tap(find.text('Cane'));
    await tester.pump();
    expect(find.text('Di razza'), findsOneWidget);
    expect(find.text('Meticcio'), findsOneWidget);
    await tester.tap(find.text('Meticcio'));
    await tester.pump();
    expect(find.text('Razza'), findsNothing, reason: 'a mixed breed needs no breed picker');
    await _tapNext(tester);

    // 3 - general information
    expect(find.text('Informazioni generali'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '14052020');
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso (facoltativo, kg)'), '23');
    await tester.enterText(find.widgetWithText(TextFormField, 'Colore del mantello'), 'Nero');
    await _tapNext(tester);

    // 4 - final information
    expect(find.text('Informazioni finali'), findsOneWidget);
    expect(find.text('Conferma'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'N. microchip'), '380 2600 0012 3456');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await _tapNext(tester, 'Conferma');

    expect(find.text('Profilo creato!'), findsOneWidget);
    expect(find.textContaining('Thor'), findsOneWidget);
    expect(find.text('Aggiungi un altro animale'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);

    final pet = PetDemoStore.instance.byName('Thor')!;
    expect(pet.species, 'Cane');
    expect(pet.sex, 'Maschio');
    expect(pet.breed, 'Meticcio / incrocio');
    expect(pet.isSterilized, isTrue);
    expect(pet.microchipNumber, '380260000123456');
    expect(pet.coatColor, 'Nero');
    expect(pet.weightLabel, '23 kg');

    await tester.tap(find.text('Fine'));
    await tester.pumpAndSettle();
    expect(find.text('apri'), findsOneWidget, reason: 'Fine closes the creation page');
  });

  testWidgets('a step does not advance while its required field is empty', (tester) async {
    await _openWizard(tester);

    await _tapNext(tester);

    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    expect(find.text('Inserisci il nome del pet.'), findsOneWidget);
  });

  testWidgets('back keeps everything typed on the earlier steps', (tester) async {
    await _openWizard(tester);
    await tester.enterText(_nameField(), 'Luna');
    await tester.tap(find.text('Femmina'));
    await tester.pump();
    await _tapNext(tester);
    await tester.tap(find.text('Gatto'));
    await tester.pump();

    await tester.tap(find.text('Indietro'));
    await tester.pumpAndSettle();

    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Luna'), findsOneWidget);

    await _tapNext(tester);
    // The species picked before going back is still selected: the breed
    // choice for cats is offered without choosing the species again.
    expect(find.text('Di razza'), findsOneWidget);
  });

  testWidgets('the system back button goes to the previous step before leaving', (tester) async {
    await _openWizard(tester);
    await tester.enterText(_nameField(), 'Luna');
    await tester.tap(find.text('Femmina'));
    await tester.pump();
    await _tapNext(tester);
    expect(find.text('Specie e razza'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    expect(find.byType(PetCreatePage), findsOneWidget);
  });

  testWidgets('a microchip that is not 15 digits stops the last step', (tester) async {
    await _openWizard(tester);
    await tester.enterText(_nameField(), 'Micio');
    await tester.tap(find.text('Maschio'));
    await tester.pump();
    await _tapNext(tester);
    await tester.tap(find.text('Gatto'));
    await tester.pump();
    await tester.tap(find.text('Meticcio'));
    await tester.pump();
    await _tapNext(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012021');
    await _tapNext(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'N. microchip'), '12345');
    await _tapNext(tester, 'Conferma');

    expect(find.text('Il microchip ha 15 cifre.'), findsOneWidget);
    expect(find.text('Profilo creato!'), findsNothing);
    expect(PetDemoStore.instance.byName('Micio'), isNull);
  });

  testWidgets('"Aggiungi un altro animale" restarts from an empty first step', (tester) async {
    await _openWizard(tester);
    await tester.enterText(_nameField(), 'Primo');
    await tester.tap(find.text('Maschio'));
    await tester.pump();
    await _tapNext(tester);
    await tester.tap(find.text('Gatto'));
    await tester.pump();
    await tester.tap(find.text('Meticcio'));
    await tester.pump();
    await _tapNext(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012021');
    await _tapNext(tester);
    await _tapNext(tester, 'Conferma');
    expect(find.text('Profilo creato!'), findsOneWidget);

    await tester.tap(find.text('Aggiungi un altro animale'));
    await tester.pumpAndSettle();

    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Primo'), findsNothing);
    expect(PetDemoStore.instance.byName('Primo'), isNotNull);
  });

  testWidgets('fish get no sex, microchip or body condition fields', (tester) async {
    await _openWizard(tester);
    await tester.enterText(_nameField(), 'Nemo');
    await _tapNext(tester);
    await tester.tap(find.text('Pesce'));
    await tester.pump();
    await tester.tap(find.text('Un pesce'));
    await tester.pump();
    await _tapNext(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012024');
    expect(find.text('Corporatura'), findsNothing);
    expect(find.text('Attività'), findsNothing);
    await _tapNext(tester);

    expect(find.text('Informazioni finali'), findsOneWidget);
    expect(find.text('N. microchip'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('the Animali list flags a dog without microchip, not one that has it', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await PetDemoStore.instance.create(
      name: 'Senzachip',
      species: 'Cane',
      breed: null,
      birthDate: DateTime(2020, 1, 1),
      sex: 'Maschio',
      identityColor: Colors.green,
    );
    await PetDemoStore.instance.create(
      name: 'Conchip',
      species: 'Cane',
      breed: null,
      birthDate: DateTime(2020, 1, 1),
      sex: 'Maschio',
      identityColor: Colors.blue,
      microchipNumber: '380260000123456',
    );
    await PetDemoStore.instance.create(
      name: 'Gattino',
      species: 'Gatto',
      breed: null,
      birthDate: DateTime(2020, 1, 1),
      sex: 'Maschio',
      identityColor: Colors.red,
    );

    await tester.pumpWidget(_app(const PetsListPage()));
    await tester.pumpAndSettle();

    expect(find.text('Microchip mancante'), findsOneWidget);
    final tagY = tester.getCenter(find.text('Microchip mancante')).dy;
    final dogY = tester.getCenter(find.text('Senzachip')).dy;
    expect(tagY - dogY, inInclusiveRange(10, 60), reason: 'the tag sits under the dog without chip');
  });
}
