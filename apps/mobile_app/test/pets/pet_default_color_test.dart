import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_identity_colors.dart';

void main() {
  test('a pet saved without a color always gets the same one, from the palette', () {
    const ids = ['pet-1', 'pet-2', 'a1b2c3', '', '0f9d2c4e-7d1b-4a57-9f7e-1b2c3d4e5f60'];
    for (final id in ids) {
      expect(petIdentityColors, contains(defaultIdentityColorForId(id)));
      expect(defaultIdentityColorForId(id), defaultIdentityColorForId(id));
    }
  });

  test('different pets are spread over the palette (it was one pale color per species)', () {
    final colors = {for (var i = 0; i < 40; i++) defaultIdentityColorForId('pet-$i')};
    expect(colors.length, petIdentityColors.length);
  });
}
