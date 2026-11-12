import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_eligibility.dart';

void main() {
  test('only dogs are eligible for walks, ignoring case and whitespace', () {
    expect(isDogSpecies('Cane'), isTrue);
    expect(isDogSpecies('  cane '), isTrue);
    expect(isDogSpecies('Gatto'), isFalse);
    expect(isDogSpecies('Pesce'), isFalse);
    expect(isDogSpecies(''), isFalse);
  });
}
