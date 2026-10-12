import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';

// formato salvato: sempre italiano ("05 mag 2021"), mai tradotto.
const _kMonthAbbreviations = [
  'gen',
  'feb',
  'mar',
  'apr',
  'mag',
  'giu',
  'lug',
  'ago',
  'set',
  'ott',
  'nov',
  'dic',
];

/// e.g. "05 mag 2021" — the SAVED format of [PetProfile.birthDateLabel]
/// (always Italian, whatever the app language). To show it to the owner use
/// [petBirthDateDisplayLabel].
String formatPetBirthDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} ${_kMonthAbbreviations[date.month - 1]} ${date.year}';
}

/// e.g. "17,8 kg" — the display format for [PetProfile.weightLabel].
String formatPetWeight(double weightKg) {
  final normalized = weightKg.toStringAsFixed(weightKg.truncateToDouble() == weightKg ? 0 : 1);
  return '${normalized.replaceAll('.', ',')} kg';
}

// formato salvato: sempre italiano
const _kMonthNumbers = {
  'gen': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'mag': 5,
  'giu': 6,
  'lug': 7,
  'ago': 8,
  'set': 9,
  'ott': 10,
  'nov': 11,
  'dic': 12,
};

/// Reads [PetProfile.birthDateLabel]: "05 mag 2021", the older "mag 2021"
/// (day 1) or just "2021" (1 January). Null for an empty or unreadable label.
DateTime? parsePetBirthDateLabel(String? label) {
  final parts = (label ?? '').trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty || parts.length > 3) return null;

  final year = int.tryParse(parts.last);
  if (year == null || year < 1900) return null;
  if (parts.length == 1) return DateTime(year);

  final month = _kMonthNumbers[parts[parts.length - 2].toLowerCase()];
  if (month == null) return null;
  final day = parts.length == 3 ? int.tryParse(parts.first) : 1;
  if (day == null || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// The birthday from a birth date label, only when the label has the day
/// ("05 mag 2021"): "mag 2021" or "2021" would make up a day the owner
/// never gave.
DateTime? parsePetBirthdayLabel(String? label) {
  final parts = (label ?? '').trim().split(RegExp(r'\s+'));
  if (parts.length != 3) return null;
  return parsePetBirthDateLabel(label);
}

/// "3 anni", "1 anno", "8 mesi", "1 mese" or "Meno di un mese" - the age at
/// [now] for a birth date label. Null when the label is empty, unreadable or
/// in the future.
String? petAgeLabel(String? birthDateLabel, {DateTime? now, AppLocalizations? l10n}) {
  final birth = parsePetBirthDateLabel(birthDateLabel);
  if (birth == null) return null;
  final today = now ?? DateTime.now();
  if (birth.isAfter(today)) return null;

  final t = l10n ?? appL10n;
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (today.day < birth.day) months -= 1;
  if (months < 1) return t.petsAgeLessThanMonth;
  if (months < 12) return t.petsAgeMonths(months);
  return t.petsAgeYears(months ~/ 12);
}

/// The saved birth date label ("05 mag 2021", "mag 2021" or "2021") as the
/// owner reads it in the app language. An unreadable label is returned as is.
String petBirthDateDisplayLabel(String? label) {
  final raw = (label ?? '').trim();
  final date = parsePetBirthDateLabel(raw);
  if (date == null) return raw;
  final partCount = raw.split(RegExp(r'\s+')).length;
  final pattern = switch (partCount) {
    3 => 'dd MMM y',
    2 => 'MMM y',
    _ => 'y',
  };
  return formatAppDate(date, pattern);
}

/// "1 profilo", "2 profili".
String petProfilesCountLabel(int count, {AppLocalizations? l10n}) =>
    (l10n ?? appL10n).petsProfilesCount(count);

/// What an enclosure is called for [species]: "Acquario", "Terrario",
/// "Voliera" or the generic "Habitat".
String petHabitatLabel(String? species, [AppLocalizations? l10n]) {
  final t = l10n ?? appL10n;
  return switch (species) {
    'Pesce' => t.petsHabitatAquarium,
    'Rettili e anfibi' => t.petsHabitatTerrarium,
    'Uccello' => t.petsHabitatAviary,
    _ => t.petsHabitatGeneric,
  };
}
