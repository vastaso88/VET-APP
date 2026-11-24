import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/measurement_sheet.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

PetProfile _pet(String weightLabel) => PetProfile(
      id: 'p-1',
      name: 'Axel',
      species: 'Rettili e anfibi',
      breed: '',
      birthDateLabel: '',
      sex: 'Maschio',
      weightLabel: weightLabel,
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'A',
      accentColor: Colors.white,
      identityColor: Colors.green,
    );

final _saved = <MeasurementDraft?>[];

Future<void> _open(
  WidgetTester tester,
  PetProfile pet, {
  UnitSystem system = UnitSystem.metric,
}) async {
  _saved.clear();
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => _saved.add(
            await showMeasurementSheet(context, pet: pet, system: system),
          ),
          child: const Text('apri'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String weight) async {
  await tester.enterText(find.byKey(const ValueKey('measurement-weight')), weight);
  await tester.tap(find.byKey(const ValueKey('measurement-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an animal shown in grams is weighed in grams', (tester) async {
    await _open(tester, _pet('380 g'));
    expect(find.text('Peso (g)'), findsOneWidget);
    await _type(tester, '385');
    expect(_saved.single!.weightKg, 0.385);
  });

  testWidgets('with no weight yet the species decides', (tester) async {
    await _open(tester, _pet(''));
    expect(find.text('Peso (g)'), findsOneWidget);
    await _type(tester, '12');
    expect(_saved.single!.weightKg, 0.012);
  });

  testWidgets('in pounds a light animal is weighed in ounces', (tester) async {
    await _open(tester, _pet('0,1 kg'), system: UnitSystem.us);
    expect(find.text('Peso (oz)'), findsOneWidget);
    await _type(tester, '4');
    expect(_saved.single!.weightKg, closeTo(0.113, 0.001));
  });

  testWidgets('a heavier animal is weighed in kilos', (tester) async {
    await _open(tester, _pet('12 kg'));
    expect(find.text('Peso (kg)'), findsOneWidget);
    expect(find.text('Es. 10,5'), findsOneWidget);
    await _type(tester, '12,4');
    expect(_saved.single!.weightKg, 12.4);
  });

  testWidgets('a likely slip of the unit is asked about, never refused', (tester) async {
    await _open(tester, _pet('4 kg'));
    await _type(tester, '385');
    expect(find.text("Hai scritto 385 kg; l'ultimo peso era 4 kg. È giusto?"), findsOneWidget);

    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();
    expect(_saved, isEmpty);

    await _type(tester, '385');
    await tester.tap(find.widgetWithText(TextButton, 'Salva'));
    await tester.pumpAndSettle();
    expect(_saved.single!.weightKg, 385);
  });
}
