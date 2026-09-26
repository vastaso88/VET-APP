const _kMonthAbbreviations = [
  'Gen',
  'Feb',
  'Mar',
  'Apr',
  'Mag',
  'Giu',
  'Lug',
  'Ago',
  'Set',
  'Ott',
  'Nov',
  'Dic',
];

/// e.g. "05 Mag 2021" — the display format for [PetProfile.birthDateLabel].
String formatPetBirthDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} ${_kMonthAbbreviations[date.month - 1]} ${date.year}';
}

/// e.g. "17,8 kg" — the display format for [PetProfile.weightLabel].
String formatPetWeight(double weightKg) {
  final normalized = weightKg.toStringAsFixed(weightKg.truncateToDouble() == weightKg ? 0 : 1);
  return '${normalized.replaceAll('.', ',')} kg';
}
