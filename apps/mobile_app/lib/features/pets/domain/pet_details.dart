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

/// Body condition, thinnest to heaviest.
const petBodyConditions = [
  'very_thin',
  'thin',
  'normal',
  'slightly_overweight',
  'overweight',
];

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

bool _isFish(String? species) => species == 'Pesce';

/// Microchip and body condition make no sense for fish or an aquarium.
bool speciesHasMicrochip(String? species) => !_isFish(species);

bool speciesHasBodyDetails(String? species) => !_isFish(species);

/// Neutering is offered for mammals only (not birds, reptiles or fish).
bool speciesHasNeutering(String? species) => switch (species) {
      'Cane' || 'Gatto' || 'Piccoli mammiferi' || 'Altro' => true,
      _ => false,
    };

/// A coat colour is asked for everything but fish.
bool speciesHasCoatColor(String? species) => !_isFish(species);

/// Size classes are only offered for dogs.
bool speciesHasSize(String? species) => species == 'Cane';

/// "Coat" for furred animals, plain "colour" for the rest.
bool speciesHasCoat(String? species) => switch (species) {
      'Cane' || 'Gatto' || 'Piccoli mammiferi' || 'Altro' => true,
      _ => false,
    };

/// In Italy a dog must be microchipped: the pets list flags dogs without one.
/// Pets in Ricordi are not nagged.
bool isMicrochipMissingForDog(PetProfile pet) =>
    pet.species == 'Cane' &&
    !pet.isMemorial &&
    (pet.microchipNumber ?? '').trim().isEmpty;
