import '../../monitoring/domain/body_condition.dart';
import 'pet_breeds.dart';
import 'pet_models.dart';

/// Optional pet details (profile v2, 2026-10-14): sex vs neutering, microchip,
/// body condition, activity level. Stored values are language-independent
/// codes (see `packages/core/domain/pet_profile/details.py`); this file also
/// holds the rules deciding which details make sense for which species.

const sexMale = 'Maschio';
const sexFemale = 'Femmina';
const sexUnknown = 'Sconosciuto';

/// The three stored sex values (neutering is a separate flag).
const petSexValues = [sexMale, sexFemale, sexUnknown];

/// Body condition codes, thinnest to heaviest (see [BodyCondition]).
final petBodyConditions = BodyCondition.codes;

const petActivityLevels = ['sedentary', 'normal', 'active'];

/// Sex and neutering of a stored sex value. Pets saved before 2026-10-14 hold
/// combined values ("Femmina sterilizzata"): they read as sex + neutering.
/// [sterilized] is null when the value says nothing about it. Mirrors
/// `split_legacy_sex` on the backend and the `migrate-sex` SQL statement.
({String? sex, bool? sterilized}) splitLegacySex(String? stored) {
  return switch (stored?.trim()) {
    'Maschio castrato' => (sex: sexMale, sterilized: true),
    'Maschio intero' => (sex: sexMale, sterilized: false),
    'Femmina sterilizzata' => (sex: sexFemale, sterilized: true),
    'Femmina intera' => (sex: sexFemale, sterilized: false),
    _ => (sex: stored, sterilized: null),
  };
}

/// Microchips follow ISO 11784/11785: 15 digits.
const microchipLength = 15;

/// Digits only: spaces and dashes of a pasted number are dropped.
String normalizeMicrochip(String? value) =>
    (value ?? '').replaceAll(RegExp(r'[\s-]'), '');

/// An empty microchip is valid (the field is optional); otherwise it must be
/// exactly 15 digits.
bool isValidMicrochip(String? value) {
  final digits = normalizeMicrochip(value);
  return digits.isEmpty || RegExp(r'^\d{15}$').hasMatch(digits);
}

/// "380 2600 0012 3456": the 15 digits in readable groups.
String formatMicrochip(String digits) {
  final clean = normalizeMicrochip(digits);
  if (clean.length != microchipLength) return clean;
  return '${clean.substring(0, 3)} ${clean.substring(3, 7)} '
      '${clean.substring(7, 11)} ${clean.substring(11)}';
}

/// What kind of animal a profile is, for deciding which details make sense.
/// The stored category ([PetProfile.species]: "Cane", "Uccello", ...) says it
/// for most; "Piccoli mammiferi", "Rettili e anfibi" and "Altro" mix animals
/// that need different questions, so the chosen species ([PetProfile.breed],
/// e.g. "Coniglio nano", "Axolotl", "Cavallo") tells them apart. A free-text
/// species we cannot place is [unknown] and gets only the safe, universal
/// questions. Backend mirror: `packages/core/domain/pet_profile/species_rules.py`.
enum PetKind {
  dog,
  cat,
  rabbit,
  smallMammal,
  /// Horse, donkey, goat, sheep, pig, camelid (the "Altro" farm mammals).
  largeMammal,
  bird,
  reptile,
  amphibian,
  fish,
  /// Snail, insect, crab, spider, scorpion.
  invertebrate,
  unknown;

  bool get isMammal => switch (this) {
        dog || cat || rabbit || smallMammal || largeMammal => true,
        _ => false,
      };
}

const _amphibianNames = ['axolotl', 'rana', 'salamandra', 'tritone', 'altro anfibio'];
const _poultryNames = ['anatra', 'gallina', 'oca'];
const _largeMammalNames = [
  'alpaca', 'asino', 'capra', 'cavallo', 'lama', 'maiale', 'pecora', 'pony', //
];
const _invertebrateNames = [
  'granchio', 'insetto', 'lumaca', 'mantide', 'scorpione', 'tarantola', //
];

bool _startsWithAny(String folded, List<String> prefixes) =>
    prefixes.any((prefix) => folded == prefix || folded.startsWith('$prefix '));

PetKind petKindOf(String? species, [String? breed]) {
  final category = (species ?? '').trim().toLowerCase();
  final name = foldBreedText(breed ?? '');
  switch (category) {
    case 'cane':
      return PetKind.dog;
    case 'gatto':
      return PetKind.cat;
    case 'pesce':
      return PetKind.fish;
    case 'uccello':
      return PetKind.bird;
    case 'piccoli mammiferi':
      return name.startsWith('coniglio') ? PetKind.rabbit : PetKind.smallMammal;
    case 'rettili e anfibi':
      return _startsWithAny(name, _amphibianNames) ? PetKind.amphibian : PetKind.reptile;
    case 'altro':
      if (_startsWithAny(name, _poultryNames)) return PetKind.bird;
      if (_startsWithAny(name, _largeMammalNames)) return PetKind.largeMammal;
      if (_startsWithAny(name, _invertebrateNames)) return PetKind.invertebrate;
      return PetKind.unknown;
    default:
      return PetKind.unknown;
  }
}

/// Dogs and cats have "breeds"; every other animal has a "species" (a
/// budgerigar is a species of bird, not a breed).
bool speciesUsesBreedWord(String? species) => species == 'Cane' || species == 'Gatto';

/// Microchips exist for dogs, cats and the mammals, birds and reptiles that
/// are kept (a transponder is also how tortoises are registered). Never for
/// fish, amphibians or invertebrates.
bool speciesHasMicrochip(String? species, {String? breed}) => switch (petKindOf(species, breed)) {
      PetKind.fish || PetKind.amphibian || PetKind.invertebrate => false,
      _ => true,
    };

/// Neutering is offered for mammals only, and only when we know it is one
/// (not birds, reptiles, fish or an unplaced free-text animal).
bool speciesHasNeutering(String? species, {String? breed}) =>
    petKindOf(species, breed).isMammal;

/// Body condition ("corporatura"): the five-level scale comes from the dog and
/// cat body condition scores; for a rabbit there is an equivalent published
/// scale (palpation of spine and ribs). Rodents, ferrets and hedgehogs are
/// scored on different, species-specific scales, and birds, reptiles and
/// amphibians are not assessed this way at all - so no profile question there.
bool speciesHasBodyCondition(String? species, {String? breed}) =>
    switch (petKindOf(species, breed)) {
      PetKind.dog || PetKind.cat || PetKind.rabbit => true,
      _ => false,
    };

/// Activity level (sedentary / normal / active) sets a dog's or cat's energy
/// needs. It has no meaning for the other animals.
bool speciesHasActivity(String? species, {String? breed}) =>
    switch (petKindOf(species, breed)) {
      PetKind.dog || PetKind.cat => true,
      _ => false,
    };

/// A weight is asked for every animal except fish (see `supportsWeightMonitoring`).
bool speciesHasWeight(String? species) => species != 'Pesce';

/// A coat colour is asked for everything but fish.
bool speciesHasCoatColor(String? species) => species != 'Pesce';

/// Size classes are only offered for dogs.
bool speciesHasSize(String? species) => species == 'Cane';

/// "Coat" for furred animals, plain "colour" for the rest.
bool speciesHasCoat(String? species, {String? breed}) {
  final kind = petKindOf(species, breed);
  return kind.isMammal;
}

/// In Italy a dog must be microchipped: the pets list flags dogs without one.
/// Pets in Ricordi are not nagged.
bool isMicrochipMissingForDog(PetProfile pet) =>
    pet.species == 'Cane' &&
    !pet.isMemorial &&
    (pet.microchipNumber ?? '').trim().isEmpty;
