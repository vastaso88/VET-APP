import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/walk_home_widget.dart';

void main() {
  test('isDogSpecies matches only dogs, ignoring case/whitespace', () {
    expect(isDogSpecies('Cane'), isTrue);
    expect(isDogSpecies(' cane '), isTrue);
    expect(isDogSpecies('Gatto'), isFalse);
    expect(isDogSpecies(''), isFalse);
  });
}
