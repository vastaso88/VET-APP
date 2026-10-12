import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_conversion.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

void main() {
  group('distance', () {
    test('metric keeps m and km', () {
      expect(formatDistanceIn(850, UnitSystem.metric), '850 m');
      expect(formatDistanceIn(1250, UnitSystem.metric), '1,3 km');
    });

    test('USA/UK use miles, with feet (USA) or yards (UK) when short', () {
      expect(formatDistanceIn(1609.344, UnitSystem.us), '1 mi');
      expect(formatDistanceIn(5000, UnitSystem.uk), '3,1 mi');
      expect(formatDistanceIn(100, UnitSystem.us), '328 ft');
      expect(formatDistanceIn(100, UnitSystem.uk), '109 yd');
    });

    test('kilometre radii convert to miles', () {
      expect(formatKilometersIn(25, UnitSystem.metric), '25 km');
      expect(formatKilometersIn(10, UnitSystem.us), '6 mi');
    });
  });

  group('weight', () {
    test('kg to lb and back', () {
      expect(formatWeightIn(17.8, UnitSystem.metric), '17,8 kg');
      expect(formatWeightIn(10, UnitSystem.us), '22 lb');
      expect(displayToKg(22.0462, UnitSystem.uk), closeTo(10, 0.001));
    });

    test('re-renders a stored label', () {
      expect(weightLabelIn('5,1 kg', UnitSystem.us), '11,2 lb');
      expect(weightLabelIn('boh', UnitSystem.us), 'boh');
    });
  });

  group('temperature', () {
    test('only the USA shows °F', () {
      expect(temperatureLabelIn('24-26°C', UnitSystem.metric), '24-26°C');
      expect(temperatureLabelIn('24-26°C', UnitSystem.uk), '24-26°C');
      expect(temperatureLabelIn('24-26°C', UnitSystem.us), '75-79°F');
      expect(
        temperatureLabelIn('28-35°C giorno, 22°C notte', UnitSystem.us),
        '82-95°F giorno, 72°F notte',
      );
    });

    test('typed °F is stored as °C', () {
      expect(temperatureLabelFromInput('75-79°F', UnitSystem.us), '24-26°C');
      expect(temperatureLabelFromInput('75-79', UnitSystem.us), '24-26°C');
      expect(temperatureLabelFromInput('24-26°C', UnitSystem.us), '24-26°C');
      expect(temperatureLabelFromInput('24-26°C', UnitSystem.metric), '24-26°C');
    });
  });

  group('volume and size', () {
    test('liters stay liters in the UK, become US gallons in the USA', () {
      expect(formatVolumeIn(112, UnitSystem.uk), '112 litri');
      expect(formatVolumeIn(112, UnitSystem.us), '29,6 US gal');
      expect(displayToLiters(30, UnitSystem.us), 114);
    });

    test('dimensions use inches outside the metric system', () {
      expect(formatLengthIn(60, UnitSystem.metric), '60 cm');
      expect(formatLengthIn(60, UnitSystem.us), '23,6 in');
      expect(displayToCm(23.6, UnitSystem.us), 60);
    });
  });

  test('default units by country', () {
    expect(defaultUnitsForLocale(null), UnitSystem.metric);
    expect(defaultUnitsForLocale('IT'), UnitSystem.metric);
    expect(defaultUnitsForLocale('gb'), UnitSystem.uk);
    expect(defaultUnitsForLocale('US'), UnitSystem.us);
  });
}
