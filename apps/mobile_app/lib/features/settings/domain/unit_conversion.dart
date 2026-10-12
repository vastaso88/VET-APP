import 'unit_system.dart';

/// Pure metric ⇄ imperial/USA conversion and formatting. Callers pass the
/// [UnitSystem]; see `UnitSettingsStore` for the owner's current choice.
const _metersPerMile = 1609.344;
const _metersPerYard = 0.9144;
const _metersPerFoot = 0.3048;
const _kgPerPound = 0.45359237;
const _litersPerUsGallon = 3.785411784;
const _cmPerInch = 2.54;

/// The decimal separator of the app language. The one place to change when
/// the app is translated (English: '.'); every number shown with units goes
/// through [formatDecimal].
String decimalSeparator = ',';

/// A number with up to [digits] decimals (trailing zeros dropped unless
/// [trimZeros] is false), written with
/// the app language's [decimalSeparator]: 1,3 (Italian) / 1.3 (English).
String formatDecimal(double value, {int digits = 1, bool trimZeros = true}) {
  final rounded = value.toStringAsFixed(digits);
  final trimmed = trimZeros && rounded.contains('.')
      ? rounded.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : rounded;
  return trimmed.replaceAll('.', decimalSeparator);
}

/// "850 m" / "1,2 km" — or "930 yd" / "310 ft" below a tenth of a mile.
String formatDistanceIn(double meters, UnitSystem system) {
  if (!system.usesMiles) {
    if (meters < 1000) return '${meters.round()} m';
    return '${formatDecimal(meters / 1000)} km';
  }
  if (meters < _metersPerMile / 10) {
    return system == UnitSystem.uk
        ? '${(meters / _metersPerYard).round()} yd'
        : '${(meters / _metersPerFoot).round()} ft';
  }
  return '${formatDecimal(meters / _metersPerMile)} mi';
}

/// A whole-kilometre figure ("25 km" search radius, ...) in the chosen system.
String formatKilometersIn(double kilometers, UnitSystem system) {
  if (!system.usesMiles) return '${formatDecimal(kilometers, digits: 0)} km';
  return '${formatDecimal(kilometers * 1000 / _metersPerMile, digits: kilometers < 10 ? 1 : 0)} mi';
}

/// Average speed from a distance and a duration: "5,2 km/h" or "3,2 mph".
String formatSpeedIn(double meters, int seconds, UnitSystem system) {
  if (seconds <= 0) return system.usesMiles ? '0 mph' : '0 km/h';
  final metersPerHour = meters / seconds * 3600;
  if (!system.usesMiles) return '${formatDecimal(metersPerHour / 1000)} km/h';
  return '${formatDecimal(metersPerHour / _metersPerMile)} mph';
}

double kgToDisplay(double kg, UnitSystem system) => system.usesPounds ? kg / _kgPerPound : kg;

double displayToKg(double value, UnitSystem system) =>
    system.usesPounds ? value * _kgPerPound : value;

/// "17,8 kg" or "39,2 lb".
String formatWeightIn(double kg, UnitSystem system) =>
    '${formatDecimal(kgToDisplay(kg, system))} ${system.usesPounds ? 'lb' : 'kg'}';

/// Re-renders a stored weight label ("17,8 kg") in the chosen system.
/// Unreadable labels are returned untouched.
String weightLabelIn(String storedLabel, UnitSystem system) {
  final kg = parseWeightLabelKg(storedLabel);
  return kg == null ? storedLabel : formatWeightIn(kg, system);
}

/// The kilograms inside a stored label such as "17,8 kg".
double? parseWeightLabelKg(String label) {
  final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(label);
  if (match == null) return null;
  return double.tryParse(match.group(0)!.replaceAll(',', '.'));
}

double celsiusToFahrenheit(double celsius) => celsius * 9 / 5 + 32;
double fahrenheitToCelsius(double fahrenheit) => (fahrenheit - 32) * 5 / 9;

final _numberPattern = RegExp(r'\d+(?:[.,]\d+)?');

String _mapNumbers(String text, double Function(double) convert) {
  return text.replaceAllMapped(_numberPattern, (match) {
    final value = double.parse(match.group(0)!.replaceAll(',', '.'));
    return convert(value).round().toString();
  });
}

/// A stored temperature label ("24-26°C", "28-35°C giorno, 22°C notte") in the
/// chosen system. Free text that has no °C is left alone.
String temperatureLabelIn(String storedLabel, UnitSystem system) {
  if (!system.usesFahrenheit || !storedLabel.contains(RegExp(r'°\s*C', caseSensitive: false))) {
    return storedLabel;
  }
  final converted = _mapNumbers(storedLabel, celsiusToFahrenheit);
  return converted.replaceAll(RegExp(r'°\s*C', caseSensitive: false), '°F');
}

/// What the owner typed, back to the stored °C label. Outside the USA the text
/// is kept as typed; in the USA the figures are read as °F unless they are
/// explicitly marked °C.
String temperatureLabelFromInput(String input, UnitSystem system) {
  final text = input.trim();
  if (!system.usesFahrenheit || text.isEmpty) return text;
  if (RegExp(r'°\s*C', caseSensitive: false).hasMatch(text)) return text;
  if (!_numberPattern.hasMatch(text)) return text;
  final withoutUnit = text.replaceAll(RegExp(r'°\s*F?', caseSensitive: false), '');
  return '${_mapNumbers(withoutUnit, fahrenheitToCelsius).trim()}°C';
}

double litersToDisplay(double liters, UnitSystem system) =>
    system.usesUsGallons ? liters / _litersPerUsGallon : liters;

int displayToLiters(double value, UnitSystem system) =>
    (system.usesUsGallons ? value * _litersPerUsGallon : value).round();

/// "112 litri" / "30 US gal".
String formatVolumeIn(int liters, UnitSystem system) {
  if (!system.usesUsGallons) return '$liters litri';
  return '${formatDecimal(litersToDisplay(liters.toDouble(), system))} US gal';
}

String volumeUnitName(UnitSystem system) => system.usesUsGallons ? 'US gal' : 'litri';

double cmToDisplay(int cm, UnitSystem system) =>
    system.usesInches ? cm / _cmPerInch : cm.toDouble();

int displayToCm(double value, UnitSystem system) =>
    (system.usesInches ? value * _cmPerInch : value).round();

/// "60 cm" / "23,6 in".
String formatLengthIn(int cm, UnitSystem system) =>
    system.usesInches ? '${formatDecimal(cmToDisplay(cm, system))} in' : '$cm cm';

String lengthUnitName(UnitSystem system) => system.usesInches ? 'in' : 'cm';
