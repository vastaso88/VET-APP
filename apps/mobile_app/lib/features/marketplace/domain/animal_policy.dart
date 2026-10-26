import 'animal_policy_patterns.dart';

/// The Mercatino sells things for animals, never animals (owner decision
/// 2026-10-26, every country). Dart port of
/// packages/core/domain/marketplace/animal_policy.py: same word lists (they are
/// generated, see animal_policy_patterns.dart), same steps, so the app can say
/// "no" before the backend does - the backend is still the one that decides.
/// tests/fixtures/marketplace_animal_policy_cases.json feeds both test suites.
/// What the backend answers (400) when it refuses an animal offer.
const animalPolicyBackendMessage =
    'Sul Mercatino si vendono solo oggetti per animali, non animali.';

final _patterns = {
  for (final entry in animalPolicyPatterns.entries) entry.key: RegExp(entry.value),
};
final _nonWord = RegExp('[^a-z0-9]+');
final _spaces = RegExp(' +');

String normalizeAnimalPolicyText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = animalPolicyAccentFrom.indexOf(char);
    buffer.write(index == -1 ? char : animalPolicyAccentTo[index]);
  }
  return buffer.toString().replaceAll(_nonWord, ' ').trim();
}

/// True when the title and/or description offer, give away or swap an animal.
/// Each text is judged on its own; only the "this is about an accessory"
/// check for a lone young animal ("Cuccioli") looks at all of them together.
bool offersAnimals(String? title, [String? description]) {
  final present = [title, description].whereType<String>().where((t) => t.trim().isNotEmpty);
  final texts = present.toList();
  final aboutAccessory = _patterns['object']!.hasMatch('${normalizeAnimalPolicyText(texts.join(' '))} ');
  return texts.any((text) => _textOffersAnimals(text, aboutAccessory));
}

bool _textOffersAnimals(String text, bool aboutAccessory) {
  final normalized = '${normalizeAnimalPolicyText(text)} ';
  if (normalized.trim().isEmpty) return false;
  final left = ' $normalized'.replaceAll(_patterns['object_target']!, ' ').replaceAll(_spaces, ' ');

  if (_patterns['adoption']!.hasMatch(left)) return true;
  final ownAccessory = _patterns['object']!.hasMatch(normalized);
  final thenOffer = _patterns[ownAccessory ? 'animal_then_offer_near' : 'animal_then_offer']!;
  final offerThen = _patterns[ownAccessory ? 'offer_then_animal_near' : 'offer_then_animal']!;
  if (_patterns['animal_adjacent_offer']!.hasMatch(left) ||
      thenOffer.hasMatch(left) ||
      offerThen.hasMatch(left)) {
    return true;
  }
  if (_patterns['young_of']!.hasMatch(left)) return true;
  return _patterns['young']!.hasMatch(left) && !aboutAccessory;
}
