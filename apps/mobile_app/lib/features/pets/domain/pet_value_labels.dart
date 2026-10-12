import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import 'pet_format.dart';

/// Display labels for pet values that are STORED (and sent to the backend)
/// as fixed Italian strings: the stored value never changes, only what the
/// owner reads. Unknown values (e.g. a free-typed species) pass through.
String localizedSpeciesLabel(String stored) {
  final l10n = appL10n;
  return switch (stored.trim().toLowerCase()) {
    'cane' => l10n.petsValueSpeciesDog,
    'gatto' => l10n.petsValueSpeciesCat,
    'piccoli mammiferi' => l10n.petsValueSpeciesSmallMammals,
    'uccello' => l10n.petsValueSpeciesBird,
    'rettili e anfibi' => l10n.petsValueSpeciesReptiles,
    'pesce' => l10n.petsValueSpeciesFish,
    'altro' => l10n.petsValueSpeciesOther,
    'tutti' => l10n.petsValueSpeciesAll,
    _ => stored,
  };
}

/// Display label for a stored sex value (see `PetDemoStore.sexOptions`).
String localizedSexLabel(String stored) {
  final l10n = appL10n;
  return switch (stored) {
    'Maschio' => l10n.petsValueSexMale,
    'Femmina' => l10n.petsValueSexFemale,
    'Maschio intero' => l10n.petsValueSexMaleIntact,
    'Maschio castrato' => l10n.petsValueSexMaleNeutered,
    'Femmina intera' => l10n.petsValueSexFemaleIntact,
    'Femmina sterilizzata' => l10n.petsValueSexFemaleSpayed,
    _ => stored,
  };
}

/// Display label for a stored dog size class (see `PetDemoStore.dogSizeCategories`).
String localizedDogSizeLabel(String stored) {
  final l10n = appL10n;
  return switch (stored) {
    'Toy' => l10n.petsValueDogSizeToy,
    'Piccola' => l10n.petsValueDogSizeSmall,
    'Media' => l10n.petsValueDogSizeMedium,
    'Grande' => l10n.petsValueDogSizeLarge,
    'Gigante' => l10n.petsValueDogSizeGiant,
    _ => stored,
  };
}

/// Display text for a stored birth date label. The stored label is always
/// Italian ("05 mag 2021", "mag 2021", "2021"); this re-renders its month in
/// the app language and leaves anything unreadable untouched.
String localizedBirthDateLabel(String stored) {
  final date = parsePetBirthDateLabel(stored);
  if (date == null) return stored;
  final parts = stored.trim().split(RegExp(r'\s+'));
  final month = appShortMonths()[date.month - 1];
  return switch (parts.length) {
    3 => '${date.day.toString().padLeft(2, '0')} $month ${date.year}',
    2 => '$month ${date.year}',
    _ => stored,
  };
}
