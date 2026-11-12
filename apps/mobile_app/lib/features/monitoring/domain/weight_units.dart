import '../../settings/domain/unit_conversion.dart';
import '../../settings/domain/unit_system.dart';

const _ouncesPerPound = 16;

/// Heaviest weight accepted for a pet, in kg (a horse or a large pig).
const maxWeightKg = 2000.0;

/// The unit a weight is typed or drawn in.
enum WeightUnit {
  kg,
  g,
  lb,
  oz;

  String get label => name;

  /// How many of this unit make [kg] kilograms.
  double fromKg(double kg) => switch (this) {
        WeightUnit.kg => kg,
        WeightUnit.g => kg * 1000,
        WeightUnit.lb => kgToDisplay(kg, UnitSystem.us),
        WeightUnit.oz => kgToDisplay(kg, UnitSystem.us) * _ouncesPerPound,
      };

  double toKg(double value) => switch (this) {
        WeightUnit.kg => value,
        WeightUnit.g => value / 1000,
        WeightUnit.lb => displayToKg(value, UnitSystem.us),
        WeightUnit.oz => displayToKg(value / _ouncesPerPound, UnitSystem.us),
      };
}

/// The unit weights are typed in: kg or lb, following the owner's system.
WeightUnit weightEntryUnit(UnitSystem system) =>
    system.usesPounds ? WeightUnit.lb : WeightUnit.kg;

/// The unit a chart is drawn in: the entry unit, or the small one (g / oz)
/// when even the heaviest weighing is under one unit - a budgie would
/// otherwise sit on a "0,03" axis.
WeightUnit weightChartUnit(double maxKg, UnitSystem system) {
  final big = weightEntryUnit(system);
  if (big.fromKg(maxKg) >= 1) return big;
  return system.usesPounds ? WeightUnit.oz : WeightUnit.g;
}

/// What the owner typed in the weight field (in [system]'s entry unit), as
/// kilograms rounded to the gram. Null when empty, unreadable, not above zero
/// or above [maxWeightKg].
double? parseWeightInput(String text, UnitSystem system) {
  final raw = text.trim().replaceAll(',', '.');
  if (raw.isEmpty) return null;
  final typed = double.tryParse(raw);
  if (typed == null || !typed.isFinite || typed <= 0) return null;
  final kg = (weightEntryUnit(system).toKg(typed) * 1000).round() / 1000;
  if (kg <= 0 || kg > maxWeightKg) return null;
  return kg;
}

/// The text a weight field starts with when editing [kg]: in the entry unit,
/// up to three decimals ("10,5", "22,5").
String weightInputText(double kg, UnitSystem system) =>
    formatDecimal(weightEntryUnit(system).fromKg(kg), digits: 3);

/// "23 kg", "10,25 kg", "420 g", "22,5 lb" or "1 oz": the weight in the
/// owner's system, small weights in grams / ounces.
String formatMeasuredWeight(double kg, UnitSystem system) {
  final small = system.usesPounds ? WeightUnit.oz : WeightUnit.g;
  final big = weightEntryUnit(system);
  final smallValue = small.fromKg(kg).roundToDouble();
  final bigLimit = system.usesPounds ? _ouncesPerPound : 1000;
  if (big.fromKg(kg) < 1 && smallValue < bigLimit) {
    return '${smallValue.round()} ${small.label}';
  }
  return '${formatDecimal(big.fromKg(kg), digits: 2)} ${big.label}';
}

/// A signed difference between two weights: "+0,5 kg", "-120 g".
String formatWeightChange(double deltaKg, UnitSystem system) {
  final sign = deltaKg < 0 ? '-' : '+';
  return '$sign${formatMeasuredWeight(deltaKg.abs(), system)}';
}
