import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_format.dart';

void main() {
  test('the profile count uses the singular for one', () {
    expect(petProfilesCountLabel(1), '1 profilo');
    expect(petProfilesCountLabel(0), '0 profili');
    expect(petProfilesCountLabel(3), '3 profili');
  });

  test('birth date labels use lowercase months like the rest of the app', () {
    expect(formatPetBirthDate(DateTime(2021, 5, 5)), '05 mag 2021');
    expect(formatPetBirthDate(DateTime(2020, 1, 2)), '02 gen 2020');
  });

  test('labels saved with the old capitalised month still parse', () {
    expect(parsePetBirthDateLabel('05 Mag 2021'), DateTime(2021, 5, 5));
    expect(parsePetBirthDateLabel('05 mag 2021'), DateTime(2021, 5, 5));
  });
}
