import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/monitoring/data/weight_measurements_repository.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition_guide.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition_guide_texts.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/pages/monitoring_tab.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/body_condition_guide_dialog.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/body_condition_illustration.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/body_condition_picker.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/pet_profile_form.dart';
import 'package:vet_app_mobile/features/settings/data/unit_settings_store.dart';

final _today = DateTime(2026, 10, 14);

PetProfile _pet({
  String species = 'Cane',
  String breed = '',
  String? bodyCondition,
}) =>
    PetProfile(
      id: 'pet-guide',
      name: 'Micio',
      species: species,
      breed: breed,
      birthDateLabel: '03 mar 2020',
      sex: 'Maschio',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'M',
      accentColor: Colors.white,
      identityColor: Colors.green,
      bodyCondition: bodyCondition,
    );

void _setScreen(WidgetTester tester, [Size size = const Size(420, 900)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
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

  group('which species have a body condition', () {
    test('only species with a published guide: dogs, cats, rabbits', () {
      expect(bodyConditionGuideForSpecies('Cane'), BodyConditionGuideKind.dog);
      expect(bodyConditionGuideForSpecies('Gatto'), BodyConditionGuideKind.cat);
      expect(
        bodyConditionGuideForSpecies('Piccoli mammiferi',
            breed: 'Coniglio ariete nano (Mini Lop)'),
        BodyConditionGuideKind.rabbit,
      );
      expect(
        bodyConditionGuideForSpecies('Piccoli mammiferi',
            breed: 'Coniglio comune / meticcio'),
        BodyConditionGuideKind.rabbit,
      );
    });

    test('no guide, no body condition for every other species', () {
      expect(bodyConditionGuideForSpecies('Uccello'), isNull);
      expect(bodyConditionGuideForSpecies('Rettili e anfibi'), isNull);
      expect(bodyConditionGuideForSpecies('Pesce'), isNull);
      expect(bodyConditionGuideForSpecies('Altro'), isNull);
      expect(bodyConditionGuideForSpecies(null), isNull);
      expect(bodyConditionGuideForSpecies('Piccoli mammiferi'), isNull);
      expect(
        bodyConditionGuideForSpecies('Piccoli mammiferi', breed: 'Criceto'),
        isNull,
      );
      expect(supportsBodyCondition(_pet(species: 'Uccello')), isFalse);
      expect(supportsBodyCondition(_pet()), isTrue);
    });

    test('every species and level has its three descriptions and a source', () {
      for (final kind in BodyConditionGuideKind.values) {
        expect(bodyConditionGuideSource(kind), isNotEmpty);
        expect(bodyConditionGuideTip(kind), isNotEmpty);
        for (final condition in BodyCondition.values) {
          final text = bodyConditionGuideTexts(kind, condition);
          expect(text.touch, isNotEmpty);
          expect(text.above, isNotEmpty);
          expect(text.side, isNotEmpty);
        }
      }
    });

    test('the nine-point scales fold into five levels with no gap', () {
      List<String> ranges(BodyConditionGuideKind kind) => [
            for (final c in BodyCondition.values)
              bodyConditionGuideTexts(kind, c).scaleRange,
          ];
      expect(ranges(BodyConditionGuideKind.dog),
          ['1–2', '3', '4–5', '6–7', '8–9']);
      expect(ranges(BodyConditionGuideKind.cat),
          ['1–2', '3–4', '5', '6–7', '8–9']);
      expect(ranges(BodyConditionGuideKind.rabbit), ['1', '2', '3', '4', '5']);
    });

    test('the sources are cited by name', () {
      expect(bodyConditionGuideSource(BodyConditionGuideKind.dog),
          contains('WSAVA'));
      expect(bodyConditionGuideSource(BodyConditionGuideKind.cat),
          contains('WSAVA'));
      expect(bodyConditionGuideSource(BodyConditionGuideKind.rabbit),
          contains('PFMA'));
      expect(bodyConditionGuideCaveat(BodyConditionGuideKind.dog), isNull);
      expect(bodyConditionGuideCaveat(BodyConditionGuideKind.rabbit),
          isNotNull);
    });
  });

  group('the guide popup', () {
    Future<void> openGuide(
      WidgetTester tester,
      BodyConditionGuideKind kind,
      void Function(BodyConditionChoice?) onResult, {
      BodyCondition? current,
    }) async {
      _setScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await showBodyConditionGuide(
                context,
                kind: kind,
                petName: 'Micio',
                current: current,
              )),
              child: const Text('apri'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
    }

    for (final kind in BodyConditionGuideKind.values) {
      testWidgets('${kind.name}: steps, both drawings, five levels, source',
          (tester) async {
        await openGuide(tester, kind, (_) {});

        expect(find.text('Valuta la corporatura'), findsOneWidget);
        expect(find.byKey(const ValueKey('bcs-guide-steps')), findsOneWidget);
        expect(find.byKey(const ValueKey('bcs-illustration-top')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('bcs-illustration-side')),
            findsOneWidget);
        for (final condition in BodyCondition.values) {
          expect(find.byKey(ValueKey('bcs-level-${condition.score}')),
              findsOneWidget);
        }
        expect(find.byKey(const ValueKey('bcs-guide-tip')), findsOneWidget);
        // The "Consigli" block: weigh every 2-4 weeks, same way, ask the vet.
        final advice = find.byKey(const ValueKey('bcs-guide-advice-title'));
        await tester.ensureVisible(advice);
        expect(find.text('Consigli'), findsOneWidget);
        expect(find.textContaining('ogni 2-4 settimane'), findsOneWidget);
        expect(find.textContaining('chiedi al veterinario'), findsWidgets);
        // Source cited, at the bottom of the scrollable card.
        final source = find.byKey(const ValueKey('bcs-guide-source'));
        await tester.ensureVisible(source);
        expect(
          tester.widget<Text>(source).data,
          startsWith('Fonte: '),
        );
        expect(
          find.byKey(const ValueKey('bcs-guide-caveat')),
          kind == BodyConditionGuideKind.rabbit
              ? findsOneWidget
              : findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the level is chosen at the end, after reading it',
        (tester) async {
      BodyConditionChoice? result;
      await openGuide(tester, BodyConditionGuideKind.dog, (r) => result = r);

      await tester.ensureVisible(find.byKey(const ValueKey('bcs-level-4')));
      await tester.tap(find.byKey(const ValueKey('bcs-level-4')));
      await tester.pump();
      // The description follows the level being looked at.
      expect(find.textContaining('Nella scala della fonte: 6–7 su 9'),
          findsOneWidget);
      expect(find.text('Scegli: Leggermente sovrappeso'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bcs-guide-confirm')));
      await tester.pumpAndSettle();
      expect(result!.condition, BodyCondition.slightlyOverweight);
    });

    testWidgets('closing the popup chooses nothing', (tester) async {
      BodyConditionChoice? result = const BodyConditionChoice(null);
      var answered = false;
      await openGuide(tester, BodyConditionGuideKind.cat, (r) {
        result = r;
        answered = true;
      });

      await tester.tap(find.byKey(const ValueKey('bcs-guide-close')));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      expect(result, isNull);
    });

    testWidgets('an existing assessment can be removed from the popup',
        (tester) async {
      BodyConditionChoice? result;
      await openGuide(
        tester,
        BodyConditionGuideKind.cat,
        (r) => result = r,
        current: BodyCondition.thin,
      );

      await tester.tap(find.byKey(const ValueKey('bcs-guide-clear')));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.condition, isNull);
    });

    testWidgets('it fits a small phone with large text', (tester) async {
      _setScreen(tester, const Size(320, 568));
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: const Scaffold(
          body: BodyConditionGuideDialog(
            kind: BodyConditionGuideKind.rabbit,
            petName: 'Micio',
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the illustration', () {
    testWidgets('is drawn for every species and level without errors',
        (tester) async {
      _setScreen(tester, const Size(900, 600));
      for (final kind in BodyConditionGuideKind.values) {
        for (final condition in BodyCondition.values) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: BodyConditionIllustration(
                    kind: kind, condition: condition),
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
        }
      }
    });

    test('it repaints only when the level, species or view change', () {
      const base = BodyConditionPainter(
        kind: BodyConditionGuideKind.dog,
        condition: BodyCondition.normal,
        view: BodyConditionView.top,
      );
      expect(base.shouldRepaint(base), isFalse);
      expect(
        base.shouldRepaint(const BodyConditionPainter(
          kind: BodyConditionGuideKind.dog,
          condition: BodyCondition.thin,
          view: BodyConditionView.top,
        )),
        isTrue,
      );
    });
  });

  group('the picker (profile form and weighing sheet)', () {
    testWidgets('has a button, never a list to pick a level from',
        (tester) async {
      _setScreen(tester);
      BodyCondition? value;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BodyConditionPicker(
              kind: BodyConditionGuideKind.dog,
              petName: 'Micio',
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ));

      expect(find.text('Non valutata'), findsOneWidget);
      expect(find.text('Valuta la corporatura'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);

      await tester.tap(find.byKey(const ValueKey('bcs-picker-open')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('bcs-level-5')));
      await tester.tap(find.byKey(const ValueKey('bcs-level-5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bcs-guide-confirm')));
      await tester.pumpAndSettle();

      expect(value, BodyCondition.overweight);
      expect(find.text('5/5 · Sovrappeso'), findsOneWidget);
      expect(find.text('Rivaluta la corporatura'), findsOneWidget);
    });

    testWidgets('the profile form has the guide for a dog and nothing for a bird',
        (tester) async {
      _setScreen(tester, const Size(420, 2600));

      Future<void> pumpForm(PetProfile pet) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PetProfileForm(
              key: ValueKey(pet.species),
              title: 'Modifica',
              submitLabel: 'Salva',
              initialPet: pet,
              onSubmit: (_) async {},
            ),
          ),
        ));
        await tester.pump();
      }

      await pumpForm(_pet(bodyCondition: 'thin'));
      expect(find.byKey(const ValueKey('bcs-picker')), findsOneWidget);
      expect(find.text('2/5 · Magro'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
      expect(find.text('Seleziona corporatura'), findsNothing);

      await pumpForm(_pet(species: 'Uccello'));
      expect(find.byKey(const ValueKey('bcs-picker')), findsNothing);
      expect(find.text('Corporatura'), findsNothing);
    });
  });

  group('Monitoraggio', () {
    Future<WeightMeasurementsRepository> openTab(
      WidgetTester tester,
      PetProfile pet, {
      List<(DateTime, double, BodyCondition?)> rows = const [],
    }) async {
      final repository = WeightMeasurementsRepository(ownerIdResolver: () => 'o');
      for (final (day, kg, bcs) in rows) {
        await repository.add(repository.create(
            petId: pet.id, measuredOn: day, weightKg: kg, bodyCondition: bcs));
      }
      _setScreen(tester, const Size(420, 2600));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MonitoringTab(
            pet: pet,
            repository: repository,
            walksRepository: DogWalksRepository(),
            now: () => _today,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      return repository;
    }

    testWidgets('a species without a guide shows weight only', (tester) async {
      await openTab(
        tester,
        _pet(species: 'Uccello'),
        rows: [(DateTime(2026, 10, 1), 0.09, BodyCondition.normal)],
      );

      expect(find.byKey(const ValueKey('current-weight')), findsOneWidget);
      expect(find.byKey(const ValueKey('monitoring-assess-bcs')), findsNothing);
      expect(find.byKey(const ValueKey('bcs-segment-3')), findsNothing);
      expect(find.byKey(const ValueKey('current-bcs')), findsNothing);
      // A value stored by an older version is not shown either.
      expect(find.textContaining('Normale'), findsNothing);
    });

    testWidgets('a rabbit has the guide, another small mammal does not',
        (tester) async {
      await openTab(
        tester,
        _pet(species: 'Piccoli mammiferi', breed: 'Coniglio ariete'),
        rows: [(DateTime(2026, 10, 1), 1.9, null)],
      );
      expect(
          find.byKey(const ValueKey('monitoring-assess-bcs')), findsOneWidget);

      await openTab(
        tester,
        _pet(species: 'Piccoli mammiferi', breed: 'Criceto dorato'),
        rows: [(DateTime(2026, 10, 1), 0.1, null)],
      );
      expect(find.byKey(const ValueKey('monitoring-assess-bcs')), findsNothing);
    });

    testWidgets('the weighing sheet has no corporatura without a guide',
        (tester) async {
      await openTab(tester, _pet(species: 'Rettili e anfibi'));
      await tester.tap(find.byKey(const ValueKey('monitoring-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('measurement-weight')), findsOneWidget);
      expect(find.byKey(const ValueKey('bcs-picker')), findsNothing);
    });

    testWidgets(
        '"Valuta la corporatura" on the card records it on a new weighing with the latest weight',
        (tester) async {
      final pet = _pet();
      final repository = await openTab(
        tester,
        pet,
        rows: [(DateTime(2026, 10, 1), 23.4, null)],
      );

      await tester.tap(find.byKey(const ValueKey('monitoring-assess-bcs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bcs-level-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bcs-guide-confirm')));
      await tester.pumpAndSettle();

      final saved = await repository.load(pet.id);
      expect(saved, hasLength(2));
      expect(saved.last.measuredOn, _today);
      expect(saved.last.weightKg, 23.4);
      expect(saved.last.bodyCondition, BodyCondition.normal);
      expect(
          tester.widget<Text>(find.byKey(const ValueKey('current-bcs'))).data,
          '3/5 · Normale');
    });

    testWidgets('on the day of the weighing the level goes on that weighing',
        (tester) async {
      final pet = _pet(species: 'Gatto');
      final repository = await openTab(
        tester,
        pet,
        rows: [(_today, 4.2, null)],
      );

      await tester.tap(find.byKey(const ValueKey('monitoring-assess-bcs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bcs-level-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bcs-guide-confirm')));
      await tester.pumpAndSettle();

      final saved = await repository.load(pet.id);
      expect(saved, hasLength(1));
      expect(saved.single.bodyCondition, BodyCondition.thin);
    });
  });
}
