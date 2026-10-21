import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/monitoring/data/weight_measurements_repository.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/pages/monitoring_tab.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/settings/data/unit_settings_store.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

final _today = DateTime(2026, 10, 14);

PetProfile _pet({
  String id = 'pet-test',
  String species = 'Gatto',
  String breed = '',
  String birth = '03 mar 2020',
  List<FishStock> stock = const [],
}) =>
    PetProfile(
      id: id,
      name: 'Micio',
      species: species,
      breed: breed,
      birthDateLabel: birth,
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

class _FakeWalks extends DogWalksRepository {
  _FakeWalks([this.walks = const []]);

  final List<WalkSession> walks;

  @override
  Future<List<WalkSession>> loadWalks(String ownerId) async => walks;
}

WalkSession _walk(String id, DateTime start,
        {double meters = 3000, int seconds = 2400}) =>
    WalkSession(
      id: id,
      ownerId: 'o',
      petId: 'pet-test',
      status: WalkStatus.completed,
      startedAt: start,
      distanceMeters: meters,
      durationSeconds: seconds,
    );

Future<WeightMeasurementsRepository> _seed(
  PetProfile pet,
  List<(DateTime, double, BodyCondition?)> rows,
) async {
  final repository = WeightMeasurementsRepository(ownerIdResolver: () => 'o');
  for (final (day, kg, bcs) in rows) {
    await repository.add(
      repository.create(
          petId: pet.id, measuredOn: day, weightKg: kg, bodyCondition: bcs),
    );
  }
  return repository;
}

/// A screen of this size (logical pixels), seen by MediaQuery too.
void _setScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester,
  PetProfile pet, {
  WeightMeasurementsRepository? repository,
  DogWalksRepository? walks,
}) async {
  // Tall enough that the whole list is built.
  _setScreen(tester, const Size(420, 2600));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MonitoringTab(
          pet: pet,
          repository: repository ??
              WeightMeasurementsRepository(ownerIdResolver: () => 'o'),
          walksRepository: walks ?? _FakeWalks(),
          now: () => _today,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

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

  testWidgets('no weighings yet: a clear message and no chart', (tester) async {
    await _open(tester, _pet());

    expect(find.text('Nessuna misurazione ancora'), findsOneWidget);
    expect(find.byKey(const ValueKey('weight-chart')), findsNothing);
    expect(find.byKey(const ValueKey('monitoring-add')), findsOneWidget);
    // A cat has no walks, so no activity either.
    expect(find.text('Attività'), findsNothing);
  });

  testWidgets(
      'shows the latest weight, its date, the change, the body condition, chart and history',
      (tester) async {
    final pet = _pet();
    final repository = await _seed(pet, [
      (DateTime(2026, 9, 1), 4.8, BodyCondition.normal),
      (DateTime(2026, 10, 1), 5.2, null),
    ]);
    await _open(tester, pet, repository: repository);

    expect(
        tester.widget<Text>(find.byKey(const ValueKey('current-weight'))).data,
        '5,2 kg');
    expect(find.text('Misurato il 1 ott 2026'), findsOneWidget);
    expect(find.text('+400 g dal 1 set'), findsOneWidget);
    // The body condition is the last one that was recorded, with its date.
    expect(tester.widget<Text>(find.byKey(const ValueKey('current-bcs'))).data,
        '3/5 · Normale');
    expect(find.text('Dalla misurazione del 1 set 2026'), findsOneWidget);
    expect(find.text('Andamento peso'), findsOneWidget);
    expect(find.byKey(const ValueKey('weight-chart')), findsOneWidget);
    expect(find.text('Storico'), findsOneWidget);
    expect(find.text('4,8 kg'), findsOneWidget); // history row
    expect(find.text('5,2 kg'), findsNWidgets(2)); // header + history row
  });

  testWidgets('the five body condition segments use the palette colours',
      (tester) async {
    final pet = _pet();
    final repository =
        await _seed(pet, [(DateTime(2026, 10, 1), 5.2, BodyCondition.thin)]);
    await _open(tester, pet, repository: repository);

    for (final condition in BodyCondition.values) {
      final box = tester.widget<Container>(
          find.byKey(ValueKey('bcs-segment-${condition.score}')));
      final color = (box.decoration! as BoxDecoration).color!;
      expect(
          color.a, condition == BodyCondition.thin ? 1.0 : closeTo(0.25, 0.01));
    }
  });

  testWidgets('a pet under a year old gets the growth curve', (tester) async {
    final pet = _pet(birth: '14 lug 2026');
    final repository = await _seed(pet, [(DateTime(2026, 8, 14), 1.2, null)]);
    await _open(tester, pet, repository: repository);

    expect(find.text('Curva di crescita'), findsOneWidget);
    expect(find.text('Andamento peso'), findsNothing);
    expect(find.text('Aggiungi un\'altra misurazione per vedere l\'andamento.'),
        findsOneWidget);
  });

  testWidgets('weights are shown in pounds for the USA', (tester) async {
    await UnitSettingsStore.instance.setSystem(UnitSystem.us);
    final pet = _pet();
    final repository = await _seed(pet, [(DateTime(2026, 10, 1), 5.2, null)]);
    await _open(tester, pet, repository: repository);

    expect(
        tester.widget<Text>(find.byKey(const ValueKey('current-weight'))).data,
        '11,46 lb');
  });

  testWidgets(
      'a dog with walks sees the weekly activity and can switch distance / time',
      (tester) async {
    final pet = _pet(species: 'Cane');
    await _open(
      tester,
      pet,
      walks: _FakeWalks([
        _walk('a', DateTime(2026, 10, 13, 8), meters: 3000, seconds: 2400),
        _walk('b', DateTime(2026, 10, 6, 8), meters: 5000, seconds: 3600),
      ]),
    );

    expect(find.text('Attività'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-empty')), findsNothing);
    expect(find.byKey(const ValueKey('activity-chart')), findsOneWidget);
    final totals = find.byKey(const ValueKey('activity-totals'));
    expect(
        find.descendant(of: totals, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: totals, matching: find.text('8 km')),
        findsOneWidget);
    expect(find.descendant(of: totals, matching: find.text('1h 40min')),
        findsOneWidget);

    await tester.tap(find.text('Tempo').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('activity-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a dog with no walks gets a clear message instead of an empty chart',
      (tester) async {
    await _open(tester, _pet(species: 'Cane'));

    expect(find.byKey(const ValueKey('activity-empty')), findsOneWidget);
    expect(find.textContaining('Nessuna passeggiata negli ultimi 3 mesi'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('activity-chart')), findsNothing);
  });

  testWidgets(
      'old walks only (more than three months ago) count as no activity',
      (tester) async {
    await _open(
      tester,
      _pet(species: 'Cane'),
      walks: _FakeWalks([_walk('old', DateTime(2026, 4, 1))]),
    );

    expect(find.byKey(const ValueKey('activity-empty')), findsOneWidget);
  });

  testWidgets(
      'adding a weighing: weight in the owner unit, body condition, saved in kg',
      (tester) async {
    final pet = _pet();
    final repository = WeightMeasurementsRepository(ownerIdResolver: () => 'o');
    await _open(tester, pet, repository: repository);

    await tester.tap(find.byKey(const ValueKey('monitoring-add')));
    await tester.pumpAndSettle();
    expect(find.text('Peso (kg)'), findsOneWidget);
    // The date starts as today.
    expect(find.text('14/10/2026'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('measurement-weight')), '9,5');
    await tester.ensureVisible(find.byKey(const ValueKey('bcs-picker-open')));
    await tester.tap(find.byKey(const ValueKey('bcs-picker-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bcs-level-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bcs-guide-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('measurement-save')));
    await tester.pumpAndSettle();

    final saved = await repository.load(pet.id);
    expect(saved, hasLength(1));
    expect(saved.single.weightKg, 9.5);
    expect(saved.single.bodyCondition, BodyCondition.thin);
    expect(saved.single.measuredOn, _today);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('current-weight'))).data,
        '9,5 kg');
  });

  testWidgets('typed in pounds it is stored in kilograms', (tester) async {
    await UnitSettingsStore.instance.setSystem(UnitSystem.uk);
    final pet = _pet();
    final repository = WeightMeasurementsRepository(ownerIdResolver: () => 'o');
    await _open(tester, pet, repository: repository);

    await tester.tap(find.byKey(const ValueKey('monitoring-add')));
    await tester.pumpAndSettle();
    expect(find.text('Peso (lb)'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('measurement-weight')), '22,5');
    await tester.tap(find.byKey(const ValueKey('measurement-save')));
    await tester.pumpAndSettle();

    expect((await repository.load(pet.id)).single.weightKg, 10.206);
  });

  testWidgets(
      'the sheet refuses an empty weight, a future date and a date before the birth',
      (tester) async {
    final pet = _pet(birth: '14 lug 2026');
    final repository = WeightMeasurementsRepository(ownerIdResolver: () => 'o');
    await _open(tester, pet, repository: repository);

    await tester.tap(find.byKey(const ValueKey('monitoring-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('measurement-save')));
    await tester.pump();
    expect(find.text('Inserisci un peso valido, maggiore di zero.'),
        findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '15102026');
    await tester.tap(find.byKey(const ValueKey('measurement-save')));
    await tester.pump();
    expect(find.text('La data non può essere nel futuro.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '01012026');
    await tester.tap(find.byKey(const ValueKey('measurement-save')));
    await tester.pump();
    expect(find.text('La data è precedente alla nascita di Micio.'),
        findsOneWidget);
    expect(await repository.load(pet.id), isEmpty);
  });

  testWidgets('editing a weighing changes it', (tester) async {
    final pet = _pet();
    final repository =
        await _seed(pet, [(DateTime(2026, 10, 1), 5.2, BodyCondition.normal)]);
    await _open(tester, pet, repository: repository);
    final id = (await repository.load(pet.id)).single.id;

    await tester.tap(find.byKey(ValueKey('history-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica misurazione'), findsOneWidget);
    expect(find.text('5,2'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('measurement-weight')), '5,6');
    // The assessment can be taken back from the guide.
    await tester.ensureVisible(find.byKey(const ValueKey('bcs-picker-open')));
    await tester.tap(find.byKey(const ValueKey('bcs-picker-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bcs-guide-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('measurement-save')));
    await tester.pumpAndSettle();

    final saved = (await repository.load(pet.id)).single;
    expect(saved.weightKg, 5.6);
    expect(saved.bodyCondition, isNull);
    expect(saved.id, id);
  });

  testWidgets('deleting a weighing asks first and then removes it',
      (tester) async {
    final pet = _pet();
    final repository = await _seed(pet, [
      (DateTime(2026, 9, 1), 4.8, null),
      (DateTime(2026, 10, 1), 5.2, null),
    ]);
    await _open(tester, pet, repository: repository);
    final newest = (await repository.load(pet.id)).last;

    await tester.tap(find.byKey(ValueKey('history-menu-${newest.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la misurazione?'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(await repository.load(pet.id), hasLength(2));

    await tester.tap(find.byKey(ValueKey('history-menu-${newest.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(await repository.load(pet.id), hasLength(1));
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('current-weight'))).data,
        '4,8 kg');
  });

  testWidgets('a narrow phone with large text still lays everything out',
      (tester) async {
    final pet = _pet(species: 'Cane');
    final repository = await _seed(pet, [
      (DateTime(2026, 9, 1), 22.4, BodyCondition.slightlyOverweight),
      (DateTime(2026, 10, 1), 23.1, BodyCondition.slightlyOverweight),
    ]);
    _setScreen(tester, const Size(320, 2600));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: MonitoringTab(
            pet: pet,
            repository: repository,
            walksRepository:
                _FakeWalks([_walk('a', DateTime(2026, 10, 13, 8))]),
            now: () => _today,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('monitoring-add')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('measurement-save')), findsOneWidget);
  });
}
