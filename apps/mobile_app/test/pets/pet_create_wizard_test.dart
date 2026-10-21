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

/// The fish chip of step 1 (the word "Pesce" also titles a card below it).
Finder _fishChip() => find.widgetWithText(InkWell, 'Pesce').first;

/// Step 1 (species and breed) for a dog or a cat, mixed breed, then step 2.
Future<void> _speciesStepMixed(WidgetTester tester, String species) async {
  await tester.tap(find.text(species));
  await tester.pump();
  await tester.tap(find.text('Meticcio'));
  await tester.pump();
  await _tapNext(tester);
}

/// Step 2 (name, sex), then step 3.
Future<void> _nameStep(WidgetTester tester, String name, [String sex = 'Maschio']) async {
  await tester.enterText(_nameField(), name);
  await tester.tap(find.text(sex));
  await tester.pump();
  await _tapNext(tester);
}

/// In the open search sheet: types [entry] in the search box (the list is
/// long and lazy) and picks it.
Future<void> _searchAndPick(WidgetTester tester, String entry) async {
  await tester.enterText(find.byType(TextField).last, entry);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, entry));
  await tester.pumpAndSettle();
}

/// Opens the breed/species search sheet of step 1 and picks [entry].
Future<void> _pickFromSheet(WidgetTester tester, String openLabel, String entry) async {
  await tester.tap(find.text(openLabel));
  await tester.pumpAndSettle();
  await _searchAndPick(tester, entry);
}

void main() {
  testWidgets('the creation flow has four steps, species first, then "Profilo creato!"',
      (tester) async {
    await _openWizard(tester);

    // 1 - species and breed
    expect(find.text('Che animale è?'), findsOneWidget);
    expect(find.text('Parlaci del tuo animale'), findsNothing);
    await tester.tap(find.text('Cane'));
    await tester.pump();
    expect(find.text('Di razza'), findsOneWidget);
    expect(find.text('Meticcio'), findsOneWidget);
    await tester.tap(find.text('Meticcio'));
    await tester.pump();
    expect(find.text('Razza'), findsNothing, reason: 'a mixed breed needs no breed picker');
    await _tapNext(tester);

    // 2 - name, photo, sex
    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    await tester.enterText(_nameField(), 'Thor');
    await tester.tap(find.text('Maschio'));
    await tester.pump();
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
    await tester.enterText(
        find.widgetWithText(TextFormField, 'N. microchip'), '380 2600 0012 3456');
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

  testWidgets('the first step does not advance without a species', (tester) async {
    await _openWizard(tester);

    await _tapNext(tester);

    expect(find.text('Che animale è?'), findsOneWidget);
    expect(find.text('Seleziona il tipo di animale.'), findsOneWidget);
  });

  testWidgets('the name step does not advance while the name is empty', (tester) async {
    await _openWizard(tester);
    await _speciesStepMixed(tester, 'Gatto');

    await _tapNext(tester);

    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
    expect(find.text('Inserisci il nome del pet.'), findsOneWidget);
  });

  testWidgets('a dog needs a breed: "Razza", mandatory, with Meticcio as the way out',
      (tester) async {
    await _openWizard(tester);
    await tester.tap(find.text('Cane'));
    await tester.pump();

    expect(find.text('Razza'), findsOneWidget);
    expect(find.text('Specie'), findsNothing);
    await _tapNext(tester);

    expect(find.text('Scegli la razza.'), findsOneWidget);
    expect(find.text('Che animale è?'), findsOneWidget);

    await _pickFromSheet(tester, 'Seleziona una razza', 'Boxer');
    await _tapNext(tester);

    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
  });

  testWidgets('"Altra razza (scrivi)" needs the breed written', (tester) async {
    await _openWizard(tester);
    await tester.tap(find.text('Cane'));
    await tester.pump();
    await _pickFromSheet(tester, 'Seleziona una razza', 'Altra razza (scrivi)');

    await _tapNext(tester);

    expect(find.text('Scrivi la razza.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quale razza?'), 'Incrocio di barboncino');
    await _tapNext(tester);
    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
  });

  testWidgets('a bird has a species, not a breed, and it is mandatory', (tester) async {
    await _openWizard(tester);
    await tester.tap(find.text('Uccello'));
    await tester.pump();

    expect(find.text('Specie'), findsOneWidget);
    expect(find.text('Razza'), findsNothing);
    expect(find.text('Di razza'), findsNothing);
    await _tapNext(tester);
    expect(find.text('Scegli la specie.'), findsOneWidget);

    await _pickFromSheet(tester, 'Seleziona una specie', 'Cocorita (Melopsittacus undulatus)');
    await _tapNext(tester);
    expect(find.text('Parlaci del tuo animale'), findsOneWidget);
  });

  testWidgets('a reptile is searched by species, scientific name included', (tester) async {
    await _openWizard(tester);
    await tester.tap(find.text('Rettili e anfibi'));
    await tester.pump();
    await tester.tap(find.text('Seleziona una specie'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'pogona');
    await tester.pumpAndSettle();

    expect(find.text('Drago barbuto (Pogona vitticeps)'), findsOneWidget);
    expect(find.text('Gecko crestato'), findsNothing);
  });

  testWidgets('back keeps everything typed on the earlier steps', (tester) async {
    await _openWizard(tester);
    await _speciesStepMixed(tester, 'Gatto');
    await tester.enterText(_nameField(), 'Luna');
    await tester.tap(find.text('Femmina'));
    await tester.pump();

    await tester.tap(find.text('Indietro'));
    await tester.pumpAndSettle();

    // The species and the mixed breed picked before are still there.
    expect(find.text('Che animale è?'), findsOneWidget);
    expect(find.text('Di razza'), findsOneWidget);

    await _tapNext(tester);
    expect(find.widgetWithText(TextFormField, 'Luna'), findsOneWidget);
  });

  testWidgets('the system back button goes to the previous step before leaving', (tester) async {
    await _openWizard(tester);
    await _speciesStepMixed(tester, 'Gatto');
    expect(find.text('Parlaci del tuo animale'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Che animale è?'), findsOneWidget);
    expect(find.byType(PetCreatePage), findsOneWidget);
  });

  testWidgets('a microchip that is not 15 digits stops the last step', (tester) async {
    await _openWizard(tester);
    await _speciesStepMixed(tester, 'Gatto');
    await _nameStep(tester, 'Micio');
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
    await _speciesStepMixed(tester, 'Gatto');
    await _nameStep(tester, 'Primo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012021');
    await _tapNext(tester);
    await _tapNext(tester, 'Conferma');
    expect(find.text('Profilo creato!'), findsOneWidget);

    await tester.tap(find.text('Aggiungi un altro animale'));
    await tester.pumpAndSettle();

    expect(find.text('Che animale è?'), findsOneWidget);
    expect(find.text('Di razza'), findsNothing, reason: 'no species is selected yet');
    expect(PetDemoStore.instance.byName('Primo'), isNotNull);
  });

  group('fish', () {
    testWidgets('two clear choices next to the fish: Pesce and Acquario', (tester) async {
      await _openWizard(tester);
      await tester.tap(_fishChip());
      await tester.pump();

      expect(find.text('Cosa vuoi registrare?'), findsOneWidget);
      expect(find.textContaining('Un solo pesce'), findsOneWidget);
      expect(find.textContaining('più specie e più esemplari'), findsOneWidget);
      expect(find.text('Acquario'), findsOneWidget);
    });

    testWidgets('a single fish: species mandatory, searchable, with a generic entry',
        (tester) async {
      await _openWizard(tester);
      await tester.tap(_fishChip());
      await tester.pump();

      expect(find.text('Specie'), findsOneWidget);
      await _tapNext(tester);
      expect(find.text('Scegli la specie.'), findsOneWidget);

      await tester.tap(find.text('Seleziona una specie'));
      await tester.pumpAndSettle();
      expect(find.text('Pesce generico (specie non nota)'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'betta');
      await tester.pumpAndSettle();
      expect(find.text('Betta (pesce combattente)'), findsOneWidget);
      expect(find.text('Guppy'), findsNothing);
      expect(find.text('Altra specie (scrivi)'), findsOneWidget,
          reason: 'free text is always offered');
    });

    testWidgets('an aquarium: species are searched, generic and written ones can be added',
        (tester) async {
      await _openWizard(tester);
      await tester.tap(_fishChip());
      await tester.pump();
      await tester.tap(find.text('Acquario'));
      await tester.pump();

      await tester.tap(find.text('Aggiungi specie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'neon');
      await tester.pumpAndSettle();
      expect(find.text('Neon tetra'), findsOneWidget);
      expect(find.text('Guppy'), findsNothing);
      await tester.tap(find.text('Neon tetra'));
      await tester.pumpAndSettle();
      expect(find.text('Neon tetra'), findsOneWidget);

      await tester.tap(find.text('Aggiungi specie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pesce generico (specie non nota)'));
      await tester.pumpAndSettle();
      expect(find.text('Pesce generico (specie non nota)'), findsOneWidget);

      await tester.tap(find.text('Aggiungi specie'));
      await tester.pumpAndSettle();
      await _searchAndPick(tester, 'Altra specie (scrivi)');
      await tester.enterText(find.byType(TextField).last, 'Pesce ghiaccio');
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      expect(find.text('Pesce ghiaccio'), findsOneWidget);

      // A species already in the tank is not offered again.
      await tester.tap(find.text('Aggiungi specie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'neon');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Neon tetra'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Neon cardinale (Paracheirodon axelrodi)'), findsOneWidget);
    });

    testWidgets('an empty aquarium does not leave the first step', (tester) async {
      await _openWizard(tester);
      await tester.tap(_fishChip());
      await tester.pump();
      await tester.tap(find.text('Acquario'));
      await tester.pump();

      await _tapNext(tester);

      expect(find.text('Che animale è?'), findsOneWidget);
      expect(find.text("Aggiungi almeno una specie all'acquario."), findsOneWidget);
    });

    testWidgets('a fish gets no sex, weight, activity, body condition or microchip',
        (tester) async {
      await _openWizard(tester);
      await tester.tap(_fishChip());
      await tester.pump();
      await _pickFromSheet(tester, 'Seleziona una specie', 'Pesce rosso');
      await _tapNext(tester);
      expect(find.text('Sesso'), findsNothing);
      await tester.enterText(_nameField(), 'Nemo');
      await _tapNext(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012024');
      expect(find.text('Corporatura'), findsNothing);
      expect(find.text('Attività'), findsNothing);
      expect(find.textContaining('Peso'), findsNothing);
      await _tapNext(tester);

      expect(find.text('Informazioni finali'), findsOneWidget);
      expect(find.text('N. microchip'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('which fields each animal sees on the general-information step', () {
    Future<void> toGeneralStep(
      WidgetTester tester, {
      required String category,
      required String entry,
    }) async {
      await _openWizard(tester);
      await tester.tap(find.text(category));
      await tester.pump();
      await _pickFromSheet(tester, 'Seleziona una specie', entry);
      await _tapNext(tester);
      await _nameStep(tester, 'Pippo', 'Femmina');
      expect(find.text('Informazioni generali'), findsOneWidget);
    }

    testWidgets('a bird: no activity or body condition, weight in grams', (tester) async {
      await toGeneralStep(
        tester,
        category: 'Uccello',
        entry: 'Cocorita (Melopsittacus undulatus)',
      );

      expect(find.text('Corporatura'), findsNothing);
      expect(find.text('Attività'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Peso (facoltativo, g)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Colore'), findsOneWidget);
    });

    testWidgets('a reptile: no activity or body condition', (tester) async {
      await toGeneralStep(
        tester,
        category: 'Rettili e anfibi',
        entry: 'Drago barbuto (Pogona vitticeps)',
      );

      expect(find.text('Corporatura'), findsNothing);
      expect(find.text('Attività'), findsNothing);
    });

    testWidgets('a rabbit has a body condition, no activity, weight in kg', (tester) async {
      await toGeneralStep(tester, category: 'Piccoli mammiferi', entry: 'Coniglio nano');

      expect(find.text('Corporatura'), findsOneWidget);
      expect(find.text('Attività'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Peso (facoltativo, kg)'), findsOneWidget);
    });

    testWidgets('a hamster: no body condition, weight in grams', (tester) async {
      await toGeneralStep(
        tester,
        category: 'Piccoli mammiferi',
        entry: 'Criceto siriano (Mesocricetus auratus)',
      );

      expect(find.text('Corporatura'), findsNothing);
      expect(find.text('Attività'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Peso (facoltativo, g)'), findsOneWidget);
    });

    testWidgets('a cat has both', (tester) async {
      await _openWizard(tester);
      await _speciesStepMixed(tester, 'Gatto');
      await _nameStep(tester, 'Micio');

      expect(find.text('Corporatura'), findsOneWidget);
      expect(find.text('Attività'), findsOneWidget);
    });

    testWidgets('neutering is asked of a rabbit', (tester) async {
      await toGeneralStep(tester, category: 'Piccoli mammiferi', entry: 'Coniglio nano');
      await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012023');
      await _tapNext(tester);

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('neutering is not asked of a parrot', (tester) async {
      await toGeneralStep(
        tester,
        category: 'Uccello',
        entry: 'Cocorita (Melopsittacus undulatus)',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012023');
      await _tapNext(tester);

      expect(find.byType(Switch), findsNothing);
    });
  });

  testWidgets('a bird is saved with its species, in grams, without activity or body condition',
      (tester) async {
    await _openWizard(tester);
    await tester.tap(find.text('Uccello'));
    await tester.pump();
    await _pickFromSheet(tester, 'Seleziona una specie', 'Cocorita (Melopsittacus undulatus)');
    await _tapNext(tester);
    await _nameStep(tester, 'Pico');
    await tester.enterText(find.widgetWithText(TextFormField, 'Data di nascita'), '01012023');
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso (facoltativo, g)'), '35');
    await _tapNext(tester);
    await _tapNext(tester, 'Conferma');

    final pet = PetDemoStore.instance.byName('Pico')!;
    expect(pet.breed, 'Cocorita (Melopsittacus undulatus)');
    expect(pet.weightLabel, '35 g');
    expect(pet.bodyCondition, isNull);
    expect(pet.activityLevel, isNull);
    expect(pet.isSterilized, isNull);
  });

  testWidgets('the Animali list shows no microchip label, even for a dog without one',
      (tester) async {
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

    await tester.pumpWidget(_app(const PetsListPage()));
    await tester.pumpAndSettle();

    expect(find.text('Senzachip'), findsOneWidget);
    expect(find.text('Microchip mancante'), findsNothing);
  });
}
