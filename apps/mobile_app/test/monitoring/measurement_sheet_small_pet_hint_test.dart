import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/measurement_sheet.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

PetProfile _pet(String weightLabel) => PetProfile(
      id: 'p-1',
      name: 'Axel',
      species: 'Anfibio',
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

Future<void> _open(WidgetTester tester, PetProfile pet) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: MeasurementSheet(pet: pet, system: UnitSystem.metric)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an animal shown in grams gets a hint on how to type it in kilos', (tester) async {
    await _open(tester, _pet('380 g'));
    expect(find.text('Peso (kg)'), findsOneWidget);
    expect(find.text('Es. 0,385 (cioè 385 g)'), findsOneWidget);
  });

  testWidgets('a heavier animal keeps the ordinary hint', (tester) async {
    await _open(tester, _pet('12 kg'));
    expect(find.text('Es. 10,5'), findsOneWidget);
    expect(find.textContaining('385 g'), findsNothing);
  });
}
