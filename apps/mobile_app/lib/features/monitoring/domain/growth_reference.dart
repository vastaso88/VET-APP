import 'dart:convert';

import '../../pets/domain/pet_breeds.dart';
import '../../pets/domain/pet_models.dart';

/// Reference bands of body weight by age for growing dogs and cats, drawn
/// behind the pet's own weighings. Empirical percentiles computed (see
/// scripts/growth/) from the data released with Salt et al., PLoS ONE 2017
/// (dogs, CC BY 4.0) and Salt et al., PLoS ONE 2022 (kittens, CC BY 3.0).
/// They are NOT the official WALTHAM charts and are a reference, never a
/// diagnosis.

const _daysPerMonth = 30.4375;

/// Dogs get bands up to this age (the bands cover 2 years).
const puppyBandsMonths = 24;

/// Cats get bands up to this age (the data stop at about a year and a half).
const kittenBandsMonths = 18;

/// The adult size classes of the dog bands (Salt 2017): the weight the dog is
/// expected to have as an adult. "VI" (40 kg and over) has no bands: breeds
/// that heavy grow in widely different ways and the paper does not chart them.
enum AdultSizeClass {
  i('I', null, 6.5),
  ii('II', 6.5, 9),
  iii('III', 9, 15),
  iv('IV', 15, 30),
  v('V', 30, 40),
  vi('VI', 40, null);

  const AdultSizeClass(this.code, this.fromKg, this.toKg);

  /// Stored value and key of the bands file.
  final String code;

  /// Expected adult weight from (inclusive) / to (exclusive), in kg.
  final double? fromKg;
  final double? toKg;

  /// Classes that have bands.
  bool get hasBands => this != vi;

  static AdultSizeClass? fromCode(String? code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }

  /// The class a size the owner gave implies without a doubt: only "Toy" (a
  /// toy dog never reaches 6.5 kg). Every other size spans several classes,
  /// so the owner chooses the expected adult weight.
  static AdultSizeClass? impliedBy(String? dogSizeCategory) =>
      dogSizeCategory == 'Toy' ? i : null;
}

/// Which pets can be given a kitten reference: mixed or common European
/// breeds only (the data are domestic shorthair kittens). Unknown breed
/// counts as mixed.
bool isKittenReferenceBreed(String? breed) {
  final name = (breed ?? '').trim();
  return name.isEmpty ||
      name == catMeticcioBreedLabel ||
      name == 'Europeo / comune' ||
      name == 'Europeo' ||
      name == 'Europeo a pelo corto' ||
      name == 'Razza non specificata' ||
      name == 'Altro';
}

/// One set of curves: percentile → weight in kg, at the same ages.
class GrowthCurves {
  const GrowthCurves({required this.months, required this.kg});

  /// Ages in months, ascending.
  final List<double> months;

  /// Percentile (3, 25, 50, 75, 97) → weights in kg, one per age.
  final Map<int, List<double>> kg;

  List<double> operator [](int percentile) => kg[percentile]!;
}

/// The bands drawn for one pet.
class GrowthReference {
  const GrowthReference({
    required this.curves,
    required this.attribution,
    required this.isPuppy,
    this.sizeClass,
  });

  final GrowthCurves curves;

  /// "Derivato da dati CC BY ... non sono le curve ufficiali WALTHAM".
  final String attribution;
  final bool isPuppy;

  /// The adult size class of a puppy's bands (null for kittens).
  final AdultSizeClass? sizeClass;

  /// The age of the last point of the bands.
  double get maxMonths => curves.months.last;
}

/// The two bands files, parsed once.
class GrowthBands {
  GrowthBands._(this._puppies, this._kittens);

  final Map<String, dynamic> _puppies;
  final Map<String, dynamic> _kittens;

  factory GrowthBands.fromJson(String puppies, String kittens) => GrowthBands._(
        jsonDecode(puppies) as Map<String, dynamic>,
        jsonDecode(kittens) as Map<String, dynamic>,
      );

  static const _percentiles = [3, 25, 50, 75, 97];

  /// The reference for a pet, or null when there is none to show: not a dog
  /// or a cat, too old, no (known) size class for a dog, a breed the kitten
  /// data do not describe.
  GrowthReference? forPet(
    PetProfile pet, {
    required DateTime? birthDate,
    required DateTime now,
    AdultSizeClass? sizeClass,
  }) {
    if (birthDate == null || birthDate.isAfter(now)) return null;
    final months = _monthsBetween(birthDate, now);
    switch (pet.species.trim().toLowerCase()) {
      case 'cane':
        final adult = sizeClass ?? AdultSizeClass.impliedBy(pet.dogSizeCategory);
        if (adult == null || !adult.hasBands || months >= puppyBandsMonths) {
          return null;
        }
        final curves = _curves(_bandsOf(_puppies['bands'], adult.code), pet.sex);
        if (curves == null) return null;
        return GrowthReference(
          curves: curves,
          attribution: _puppies['attribution'] as String,
          isPuppy: true,
          sizeClass: adult,
        );
      case 'gatto':
        if (!isKittenReferenceBreed(pet.breed) || months >= kittenBandsMonths) {
          return null;
        }
        final curves = _curves(_kittens['bands'] as Map<String, dynamic>, pet.sex);
        if (curves == null) return null;
        return GrowthReference(
          curves: curves,
          attribution: _kittens['attribution'] as String,
          isPuppy: false,
        );
    }
    return null;
  }

  static Map<String, dynamic> _bandsOf(Object? bands, String code) =>
      ((bands as Map<String, dynamic>)[code] as Map<String, dynamic>?) ??
      const {};

  /// The curves for [sex] ("Maschio" / "Femmina"); for an unknown sex the
  /// widest of the two (lowest low percentiles, highest high ones), at the
  /// ages both have.
  static GrowthCurves? _curves(Map<String, dynamic> bySex, String sex) {
    final male = bySex['male'] as Map<String, dynamic>?;
    final female = bySex['female'] as Map<String, dynamic>?;
    final wanted = switch (sex) {
      'Maschio' => male,
      'Femmina' => female,
      _ => null,
    };
    if (wanted != null) return _single(wanted);
    if (male == null || female == null) {
      final only = male ?? female;
      return only == null ? null : _single(only);
    }
    final a = _single(male);
    final b = _single(female);
    final both = [
      for (var i = 0; i < a.months.length; i++)
        if (b.months.any((m) => (m - a.months[i]).abs() < 1e-9)) i,
    ];
    if (both.isEmpty) return null;
    int indexIn(GrowthCurves c, double m) =>
        c.months.indexWhere((x) => (x - m).abs() < 1e-9);
    return GrowthCurves(
      months: [for (final i in both) a.months[i]],
      kg: {
        for (final p in _percentiles)
          p: [
            for (final i in both)
              () {
                final x = a[p][i];
                final y = b[p][indexIn(b, a.months[i])];
                return p <= 50 ? (x < y ? x : y) : (x > y ? x : y);
              }(),
          ],
      },
    );
  }

  static GrowthCurves _single(Map<String, dynamic> band) {
    double toMonths(num weeks) => weeks * 7 / _daysPerMonth;
    return GrowthCurves(
      months: [for (final w in band['weeks'] as List) toMonths(w as num)],
      kg: {
        for (final p in _percentiles)
          p: [for (final v in band['p$p'] as List) (v as num).toDouble()],
      },
    );
  }

  /// Whole calendar months of age (the same count as `isGrowthCurvePet`).
  static int _monthsBetween(DateTime from, DateTime to) {
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return to.day < from.day ? months - 1 : months;
  }
}
