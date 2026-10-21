import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pet_medical_records_tab.dart';
import 'package:vet_app_mobile/features/monitoring/data/weight_measurements_repository.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/pages/monitoring_tab.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:vet_app_mobile/features/settings/data/unit_settings_store.dart';

PetProfile _pet(String species, {List<FishStock> stock = const []}) =>
    PetProfile(
      id: 'pet-detail-$species',
      name: 'Micio',
      species: species,
      breed: '',
      birthDateLabel: '03 mar 2020',
      sex: 'Maschio',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'M',
      accentColor: Colors.white,
      identityColor: Colors.green,
      aquariumStock: stock,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    return initializeDateFormatting('it');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UnitSettingsStore.instance.resetForTest();
    WeightMeasurementsRepository.resetForTest();
  });

  Future<void> open(WidgetTester tester, PetProfile pet) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PetDetailPage(pet: pet)));
    await tester.pump();
  }

  testWidgets('Monitoraggio is a tab of its own, not a row under Referti',
      (tester) async {
    await open(tester, _pet('Gatto'));

    expect(find.widgetWithText(Tab, 'Monitoraggio'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Referti'), findsOneWidget);

    // The Referti tab no longer holds the entry row.
    await tester.tap(find.widgetWithText(Tab, 'Referti'));
    await tester.pumpAndSettle();
    expect(find.byType(PetMedicalRecordsTab), findsOneWidget);
    expect(find.byKey(const ValueKey('monitoring-entry')), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Monitoraggio'));
    await tester.pumpAndSettle();
    expect(find.byType(MonitoringTab), findsOneWidget);
    expect(find.byKey(const ValueKey('monitoring-add')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dog has five tabs and they all fit a small phone',
      (tester) async {
    await open(tester, _pet('Cane'));

    for (final label in [
      'Promemoria',
      'Chat',
      'Referti',
      'Monitoraggio',
      'Passeggiate',
    ]) {
      expect(find.widgetWithText(Tab, label), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('fish and aquariums have no Monitoraggio tab', (tester) async {
    await open(tester, _pet('Pesce'));
    expect(find.widgetWithText(Tab, 'Monitoraggio'), findsNothing);

    await open(
      tester,
      _pet('Pesce', stock: const [FishStock(species: 'Guppy', maleCount: 1)]),
    );
    expect(find.widgetWithText(Tab, 'Monitoraggio'), findsNothing);
  });
}
