import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/monitoring/data/growth_reference_repository.dart';
import 'package:vet_app_mobile/features/monitoring/data/weight_measurements_repository.dart';
import 'package:vet_app_mobile/features/monitoring/domain/growth_reference.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weight_chart.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/pages/monitoring_tab.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/settings/data/unit_settings_store.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

final _now = DateTime(2026, 10, 14);

GrowthBands _bands() => GrowthBands.fromJson(
      File('assets/growth/puppy_growth_bands.json').readAsStringSync(),
      File('assets/growth/kitten_growth_bands.json').readAsStringSync(),
    );

PetProfile _pet({
  String species = 'Cane',
  String breed = '',
  String sex = 'Maschio',
  String? size,
}) =>
    PetProfile(
      id: 'pet-growth',
      name: 'Briciola',
      species: species,
      breed: breed,
      birthDateLabel: '',
      sex: sex,
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'B',
      accentColor: Colors.white,
      identityColor: Colors.green,
      dogSizeCategory: size,
    );

DateTime _bornMonthsAgo(int months) =>
    DateTime(_now.year, _now.month - months, _now.day);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    return initializeDateFormatting('it');
  });

  group('the bands files', () {
    test('every puppy class has its bands, ordered and in range', () {
      final bands = _bands();
      for (final sizeClass in AdultSizeClass.values.where((c) => c.hasBands)) {
        for (final sex in ['Maschio', 'Femmina']) {
          final reference = bands.forPet(
            _pet(sex: sex),
            birthDate: _bornMonthsAgo(4),
            now: _now,
            sizeClass: sizeClass,
          );
          expect(reference, isNotNull, reason: '${sizeClass.code} $sex');
          final curves = reference!.curves;
          expect(curves.months.first, closeTo(2.8, 0.2)); // 12 weeks
          for (var i = 0; i < curves.months.length; i++) {
            expect(curves[3][i], lessThanOrEqualTo(curves[25][i]));
            expect(curves[25][i], lessThanOrEqualTo(curves[50][i]));
            expect(curves[50][i], lessThanOrEqualTo(curves[75][i]));
            expect(curves[75][i], lessThanOrEqualTo(curves[97][i]));
          }
          expect(reference.attribution, contains('CC BY 4.0'));
          expect(reference.attribution, contains('WALTHAM'));
        }
      }
    });

    test('a bigger class weighs more at the same age', () {
      final bands = _bands();
      double median(AdultSizeClass c) => bands
          .forPet(_pet(), birthDate: _bornMonthsAgo(5), now: _now, sizeClass: c)!
          .curves[50]
          .last;
      expect(median(AdultSizeClass.i), lessThan(median(AdultSizeClass.iv)));
      expect(median(AdultSizeClass.iv), lessThan(median(AdultSizeClass.v)));
    });

    test('no bands without a class, over 40 kg, or at two years', () {
      final bands = _bands();
      final birth = _bornMonthsAgo(5);
      expect(bands.forPet(_pet(), birthDate: birth, now: _now), isNull);
      expect(
        bands.forPet(_pet(),
            birthDate: birth, now: _now, sizeClass: AdultSizeClass.vi),
        isNull,
      );
      expect(
        bands.forPet(_pet(),
            birthDate: _bornMonthsAgo(24),
            now: _now,
            sizeClass: AdultSizeClass.iii),
        isNull,
      );
      expect(
        bands.forPet(_pet(),
            birthDate: _bornMonthsAgo(23),
            now: _now,
            sizeClass: AdultSizeClass.iii),
        isNotNull,
      );
      expect(
        bands.forPet(_pet(),
            birthDate: null, now: _now, sizeClass: AdultSizeClass.iii),
        isNull,
      );
    });

    test('only a Toy size implies a class by itself', () {
      final bands = _bands();
      expect(
        bands
            .forPet(_pet(size: 'Toy'), birthDate: _bornMonthsAgo(4), now: _now)!
            .sizeClass,
        AdultSizeClass.i,
      );
      for (final size in ['Piccola', 'Media', 'Grande', 'Gigante']) {
        expect(
          bands.forPet(_pet(size: size), birthDate: _bornMonthsAgo(4), now: _now),
          isNull,
          reason: size,
        );
      }
    });

    test('the sex picks the curves; an unknown sex gets the widest of both', () {
      final bands = _bands();
      GrowthCurves curves(String sex) => bands
          .forPet(_pet(sex: sex),
              birthDate: _bornMonthsAgo(5),
              now: _now,
              sizeClass: AdultSizeClass.iv)!
          .curves;
      final male = curves('Maschio');
      final female = curves('Femmina');
      final unknown = curves('Sconosciuto');
      expect(male[50].last, greaterThan(female[50].last));
      expect(unknown[3].last, lessThanOrEqualTo(female[3].last));
      expect(unknown[97].last, greaterThanOrEqualTo(male[97].last));
    });

    test('kittens: shorthair or mixed cats under a year and a half only', () {
      final bands = _bands();
      GrowthReference? kitten(String breed, int months) => bands.forPet(
            _pet(species: 'Gatto', breed: breed),
            birthDate: _bornMonthsAgo(months),
            now: _now,
          );
      expect(kitten('Meticcio / europeo comune', 5), isNotNull);
      expect(kitten('', 5), isNotNull);
      expect(kitten('Europeo / comune', 5)!.isPuppy, isFalse);
      expect(kitten('Europeo / comune', 5)!.attribution, contains('CC BY 3.0'));
      expect(kitten('Maine Coon', 5), isNull);
      expect(kitten('Europeo / comune', 18), isNull);
    });

    test('other species have no bands', () {
      final bands = _bands();
      for (final species in ['Uccello', 'Piccoli mammiferi', 'Pesce']) {
        expect(
          bands.forPet(_pet(species: species),
              birthDate: _bornMonthsAgo(3),
              now: _now,
              sizeClass: AdultSizeClass.i),
          isNull,
        );
      }
    });
  });

  group('the chart', () {
    final bands = _bands();

    test('a dog with bands is an age chart up to two years, bands inside the axes',
        () {
      final birth = _bornMonthsAgo(15);
      final reference = bands.forPet(_pet(),
          birthDate: birth, now: _now, sizeClass: AdultSizeClass.iii)!;
      final repository =
          WeightMeasurementsRepository(ownerIdResolver: () => 'o');
      final measurement = repository.create(
          petId: 'x', measuredOn: _bornMonthsAgo(1), weightKg: 12);

      final withBands = buildWeightChart(
        measurements: [measurement],
        birthDate: birth,
        now: _now,
        system: UnitSystem.metric,
        reference: reference,
      )!;
      expect(withBands.mode, WeightChartMode.byAge);
      expect(withBands.reference, isNotNull);
      expect(withBands.maxX, lessThanOrEqualTo(reference.maxMonths));
      expect(withBands.minX, lessThanOrEqualTo(3));

      // Without bands, 15 months is still the calendar chart.
      final plain = buildWeightChart(
        measurements: [measurement],
        birthDate: birth,
        now: _now,
        system: UnitSystem.metric,
      )!;
      expect(plain.mode, WeightChartMode.overTime);
      expect(plain.reference, isNull);
    });

    test('the weight axis holds the part of the bands that is on view', () {
      final birth = _bornMonthsAgo(4);
      final reference = bands.forPet(_pet(),
          birthDate: birth, now: _now, sizeClass: AdultSizeClass.v)!;
      final repository =
          WeightMeasurementsRepository(ownerIdResolver: () => 'o');
      final chart = buildWeightChart(
        measurements: [
          repository.create(
              petId: 'x', measuredOn: _bornMonthsAgo(1), weightKg: 9),
        ],
        birthDate: birth,
        now: _now,
        system: UnitSystem.metric,
        reference: reference,
      )!;
      final reference97 = chart.reference!;
      for (var i = 0; i < reference97.xs.length; i++) {
        if (reference97.xs[i] < chart.minX || reference97.xs[i] > chart.maxX) {
          continue;
        }
        expect(reference97.ys[97]![i], lessThanOrEqualTo(chart.maxY));
        expect(reference97.ys[3]![i], greaterThanOrEqualTo(chart.minY));
      }
    });
  });

  group('Monitoraggio', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      UnitSettingsStore.instance.resetForTest();
      WeightMeasurementsRepository.resetForTest();
      GrowthReferenceRepository.resetForTest();
    });

    Future<WeightMeasurementsRepository> open(
      WidgetTester tester,
      PetProfile pet, {
      required int ageMonths,
      double kg = 8,
    }) async {
      final birth = _bornMonthsAgo(ageMonths);
      final withBirth = PetProfile(
        id: pet.id,
        name: pet.name,
        species: pet.species,
        breed: pet.breed,
        birthDateLabel:
            '${birth.day.toString().padLeft(2, '0')} ${const [
          'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'
        ][birth.month - 1]} ${birth.year}',
        sex: pet.sex,
        weightLabel: '',
        medicalNote: '',
        healthBadge: '',
        nextVisitLabel: '',
        avatarEmoji: pet.avatarEmoji,
        accentColor: Colors.white,
        identityColor: Colors.green,
        dogSizeCategory: pet.dogSizeCategory,
      );
      final repository =
          WeightMeasurementsRepository(ownerIdResolver: () => 'o');
      await repository.add(repository.create(
          petId: pet.id, measuredOn: _bornMonthsAgo(1), weightKg: kg));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 2600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MonitoringTab(
            pet: withBirth,
            repository: repository,
            walksRepository: DogWalksRepository(),
            now: () => _now,
          ),
        ),
      ));
      // The tab loads weighings, walks, the bands asset and the saved class.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return repository;
    }

    testWidgets('a Toy puppy sees the bands with source and notice',
        (tester) async {
      await open(tester, _pet(size: 'Toy'), ageMonths: 5, kg: 2);

      expect(find.byKey(const ValueKey('growth-source')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('growth-source'))).data,
        allOf(contains('Derivato da dati CC BY 4.0 di Salt C. et al.'),
            contains('non sono le curve ufficiali WALTHAM'),
            contains('Meno di 6,5 kg')),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('growth-disclaimer'))).data,
        contains('non una diagnosi'),
      );
      expect(find.byKey(const ValueKey('growth-legend')), findsOneWidget);
      expect(find.byKey(const ValueKey('growth-prompt')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a puppy of unknown adult size is asked for it, then sees the bands',
        (tester) async {
      await open(tester, _pet(), ageMonths: 5, kg: 8);

      expect(find.byKey(const ValueKey('growth-prompt')), findsOneWidget);
      expect(find.byKey(const ValueKey('growth-source')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('growth-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('growth-class-IV')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('growth-prompt')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('growth-source'))).data,
        contains('Da 15 kg a 30 kg'),
      );
      // Remembered on this device.
      expect(
        await GrowthReferenceRepository().loadSizeClass('pet-growth'),
        AdultSizeClass.iv,
      );

      await tester.tap(find.byKey(const ValueKey('growth-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('growth-class-unknown')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('growth-prompt')), findsOneWidget);
      expect(
        await GrowthReferenceRepository().loadSizeClass('pet-growth'),
        isNull,
      );
    });

    testWidgets('over 40 kg says there are no reference curves', (tester) async {
      await open(tester, _pet(), ageMonths: 5, kg: 15);
      await tester.tap(find.byKey(const ValueKey('growth-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('growth-class-VI')));
      await tester.pumpAndSettle();

      expect(find.textContaining('sopra i 40 kg'), findsOneWidget);
      expect(find.byKey(const ValueKey('growth-source')), findsNothing);
    });

    testWidgets('the sizes are shown in pounds for the USA', (tester) async {
      await UnitSettingsStore.instance.setSystem(UnitSystem.us);
      await open(tester, _pet(size: 'Toy'), ageMonths: 5, kg: 2);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('growth-source'))).data,
        contains('lb'),
      );
    });

    testWidgets('a kitten sees the kitten bands, an adult dog sees nothing',
        (tester) async {
      await open(tester, _pet(species: 'Gatto', breed: 'Europeo / comune'),
          ageMonths: 4, kg: 2);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('growth-source'))).data,
        contains('CC BY 3.0'),
      );
      expect(find.byKey(const ValueKey('growth-choose')), findsNothing);

      await open(tester, _pet(size: 'Toy'), ageMonths: 30, kg: 4);
      expect(find.byKey(const ValueKey('growth-source')), findsNothing);
      expect(find.byKey(const ValueKey('growth-prompt')), findsNothing);
    });

    testWidgets('a pet with no bands and no growth stays as before',
        (tester) async {
      await open(tester, _pet(species: 'Gatto', breed: 'Maine Coon'),
          ageMonths: 4, kg: 2);
      expect(find.byKey(const ValueKey('growth-source')), findsNothing);
      expect(find.byKey(const ValueKey('weight-chart')), findsOneWidget);
      expect(find.textContaining('senza curve di riferimento'), findsOneWidget);
    });
  });
}
