import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weight_units.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_format.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_conversion.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

void main() {
  group('parseWeightInput', () {
    test('metric: kilograms with a comma or a dot', () {
      expect(parseWeightInput('10,5', UnitSystem.metric), 10.5);
      expect(parseWeightInput(' 10.5 ', UnitSystem.metric), 10.5);
      expect(parseWeightInput('0,032', UnitSystem.metric), 0.032);
    });

    test('UK and USA: typed in pounds, kept in kilograms to the gram', () {
      expect(parseWeightInput('22,5', UnitSystem.us), 10.206);
      expect(parseWeightInput('22.5', UnitSystem.uk), 10.206);
      expect(parseWeightInput('1', UnitSystem.us), 0.454);
    });

    test('empty, unreadable, zero, negative or absurd weights are refused', () {
      expect(parseWeightInput('', UnitSystem.metric), isNull);
      expect(parseWeightInput('abc', UnitSystem.metric), isNull);
      expect(parseWeightInput('0', UnitSystem.metric), isNull);
      expect(parseWeightInput('-3', UnitSystem.metric), isNull);
      expect(parseWeightInput('0,0001', UnitSystem.metric), isNull);
      expect(parseWeightInput('2500', UnitSystem.metric), isNull);
    });
  });

  group('conversion', () {
    test('kg, g, lb and oz round-trip', () {
      for (final unit in WeightUnit.values) {
        expect(unit.toKg(unit.fromKg(7.3)), closeTo(7.3, 1e-9));
      }
      expect(WeightUnit.g.fromKg(0.42), closeTo(420, 1e-9));
      expect(WeightUnit.lb.fromKg(10), closeTo(22.0462, 1e-3));
      expect(WeightUnit.oz.fromKg(0.0283495), closeTo(1, 1e-4));
    });

    test('the text of the field when editing comes back to the same weight',
        () {
      expect(weightInputText(10.206, UnitSystem.us), '22,5');
      expect(weightInputText(10.5, UnitSystem.metric), '10,5');
      expect(weightInputText(0.032, UnitSystem.metric), '0,032');
      for (final system in UnitSystem.values) {
        for (final kg in [0.032, 4.25, 10.206, 23.0]) {
          expect(parseWeightInput(weightInputText(kg, system), system),
              closeTo(kg, 0.0006));
        }
      }
    });

    test('the chart is drawn in the small unit for a tiny pet', () {
      expect(weightChartUnit(23, UnitSystem.metric), WeightUnit.kg);
      expect(weightChartUnit(0.05, UnitSystem.metric), WeightUnit.g);
      expect(weightChartUnit(23, UnitSystem.us), WeightUnit.lb);
      expect(weightChartUnit(0.3, UnitSystem.us), WeightUnit.oz);
    });
  });

  group('formatMeasuredWeight', () {
    test('metric', () {
      expect(formatMeasuredWeight(23, UnitSystem.metric), '23 kg');
      expect(formatMeasuredWeight(10.25, UnitSystem.metric), '10,25 kg');
      expect(formatMeasuredWeight(0.42, UnitSystem.metric), '420 g');
      expect(formatMeasuredWeight(0.9996, UnitSystem.metric), '1 kg');
    });

    test('UK and USA', () {
      expect(formatMeasuredWeight(10.206, UnitSystem.us), '22,5 lb');
      expect(formatMeasuredWeight(0.0283495, UnitSystem.uk), '1 oz');
    });

    test('a change keeps its sign', () {
      expect(formatWeightChange(1.5, UnitSystem.metric), '+1,5 kg');
      expect(formatWeightChange(0.5, UnitSystem.metric), '+500 g');
      expect(formatWeightChange(-0.12, UnitSystem.metric), '-120 g');
    });
  });

  group('the weight label of the profile', () {
    test('formatPetWeight writes grams under a kilogram and keeps two decimals',
        () {
      expect(formatPetWeight(23), '23 kg');
      expect(formatPetWeight(17.8), '17,8 kg');
      expect(formatPetWeight(10.206), '10,21 kg');
      expect(formatPetWeight(0.032), '32 g');
    });

    test('parseWeightLabelKg reads kg and g labels', () {
      expect(parseWeightLabelKg('17,8 kg'), 17.8);
      expect(parseWeightLabelKg('420 g'), 0.42);
      expect(parseWeightLabelKg('23kg'), 23);
      expect(parseWeightLabelKg('5'), 5);
      expect(parseWeightLabelKg('boh'), isNull);
      for (final kg in [0.032, 0.42, 4.25, 23.0]) {
        expect(parseWeightLabelKg(formatPetWeight(kg)), closeTo(kg, 0.006));
      }
    });
  });
}
