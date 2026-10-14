
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_details.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_value_labels.dart';

PetProfile _pet({
  String species = 'Cane',
  String sex = 'Maschio',
  String? microchip,
  bool memorial = false,
}) {
  return PetProfile(
    id: 'p',
    name: 'Tobia',
    species: species,
    breed: '',
    birthDateLabel: '',
    sex: sex,
    weightLabel: '',
    medicalNote: '',
    healthBadge: '',
    nextVisitLabel: '',
    avatarEmoji: 'T',
    accentColor: Colors.white,
    identityColor: Colors.green,
    microchipNumber: microchip,
    isMemorial: memorial,
  );
}

Map<String, dynamic> _row({String? sex, bool? sterilized}) => {
      'id': 'pet-1',
      'name': 'Luna',
      'species': 'Gatto',
      'sex': sex ?? 'Femmina',
      'is_sterilized': sterilized,
    };

void main() {
  group('sex migration on read', () {
    test('every combined value splits into sex and neutering', () {
      expect(splitLegacySex('Femmina sterilizzata'), (sex: 'Femmina', sterilized: true));
      expect(splitLegacySex('Maschio castrato'), (sex: 'Maschio', sterilized: true));
      expect(splitLegacySex('Maschio intero'), (sex: 'Maschio', sterilized: false));
      expect(splitLegacySex('Femmina intera'), (sex: 'Femmina', sterilized: false));
    });

    test('current values and unknowns are left alone', () {
      expect(splitLegacySex('Maschio'), (sex: 'Maschio', sterilized: null));
      expect(splitLegacySex('Sconosciuto'), (sex: 'Sconosciuto', sterilized: null));
      expect(splitLegacySex(null), (sex: null, sterilized: null));
      expect(splitLegacySex(''), (sex: '', sterilized: null));
    });

    test('a row with an old combined value comes out as sex + neutered', () {
      final pet = PetDemoStore.instance.petFromRow(_row(sex: 'Femmina sterilizzata'))!;

      expect(pet.sex, 'Femmina');
      expect(pet.isSterilized, isTrue);
    });

    test('an explicit is_sterilized column wins over the old value', () {
      final pet = PetDemoStore.instance.petFromRow(_row(sex: 'Femmina intera', sterilized: true))!;

      expect(pet.sex, 'Femmina');
      expect(pet.isSterilized, isTrue);
    });

    test('a current row is read as stored; neutering stays unknown when absent', () {
      final pet = PetDemoStore.instance.petFromRow(_row(sex: 'Maschio'))!;

      expect(pet.sex, 'Maschio');
      expect(pet.isSterilized, isNull);
    });

    test('the three sex values are the only options and all have a label', () {
      expect(PetDemoStore.sexOptions, ['Maschio', 'Femmina', 'Sconosciuto']);
      for (final sex in PetDemoStore.sexOptions) {
        expect(localizedSexLabel(sex), isNotEmpty);
      }
    });
  });

  group('microchip', () {
    test('15 digits are valid, with or without spaces and dashes', () {
      expect(isValidMicrochip('380260000123456'), isTrue);
      expect(isValidMicrochip('380 2600 0012 3456'), isTrue);
      expect(isValidMicrochip('380-260-000-123-456'), isTrue);
    });

    test('empty is valid because the field is optional', () {
      expect(isValidMicrochip(null), isTrue);
      expect(isValidMicrochip(''), isTrue);
      expect(isValidMicrochip('   '), isTrue);
    });

    test('anything else is rejected', () {
      expect(isValidMicrochip('12345'), isFalse);
      expect(isValidMicrochip('38026000012345'), isFalse, reason: '14 digits');
      expect(isValidMicrochip('3802600001234567'), isFalse, reason: '16 digits');
      expect(isValidMicrochip('38026000012345a'), isFalse);
    });

    test('is normalized to digits and shown in groups', () {
      expect(normalizeMicrochip(' 380 2600-0012 3456 '), '380260000123456');
      expect(formatMicrochip('380260000123456'), '380 2600 0012 3456');
      expect(formatMicrochip('123'), '123');
    });

    test('only dogs without one are flagged, never fish or pets in Ricordi', () {
      expect(isMicrochipMissingForDog(_pet()), isTrue);
      expect(isMicrochipMissingForDog(_pet(microchip: '')), isTrue);
      expect(isMicrochipMissingForDog(_pet(microchip: '380260000123456')), isFalse);
      expect(isMicrochipMissingForDog(_pet(species: 'Gatto')), isFalse);
      expect(isMicrochipMissingForDog(_pet(species: 'Pesce')), isFalse);
      expect(isMicrochipMissingForDog(_pet(memorial: true)), isFalse);
    });
  });

  group('which details a species gets', () {
    test('fish get no microchip, body condition, neutering or coat', () {
      expect(speciesHasMicrochip('Pesce'), isFalse);
      expect(speciesHasBodyDetails('Pesce'), isFalse);
      expect(speciesHasNeutering('Pesce'), isFalse);
      expect(speciesHasCoatColor('Pesce'), isFalse);
    });

    test('dogs and cats get all of them; size is for dogs only', () {
      for (final species in ['Cane', 'Gatto']) {
        expect(speciesHasMicrochip(species), isTrue);
        expect(speciesHasBodyDetails(species), isTrue);
        expect(speciesHasNeutering(species), isTrue);
      }
      expect(speciesHasSize('Cane'), isTrue);
      expect(speciesHasSize('Gatto'), isFalse);
    });

    test('birds and reptiles are not asked about neutering', () {
      expect(speciesHasNeutering('Uccello'), isFalse);
      expect(speciesHasNeutering('Rettili e anfibi'), isFalse);
      expect(speciesHasMicrochip('Uccello'), isTrue);
    });
  });

  group('storage', () {
    test('the new details round-trip through a Supabase row', () {
      final pet = _pet(microchip: '380260000123456').copyWith(
        isSterilized: true,
        coatColor: 'Nero e focato',
        bodyCondition: 'slightly_overweight',
        activityLevel: 'active',
      );

      final row = PetDemoStore.instance.petToRow(pet, 'owner-1');
      final back = PetDemoStore.instance.petFromRow(row)!;

      expect(row['is_sterilized'], isTrue);
      expect(row['microchip_number'], '380260000123456');
      expect(back.isSterilized, isTrue);
      expect(back.coatColor, 'Nero e focato');
      expect(back.bodyCondition, 'slightly_overweight');
      expect(back.activityLevel, 'active');
      expect(back.microchipNumber, '380260000123456');
    });

    test('the retry without the new SQL drops exactly the v2 columns', () {
      final row = PetDemoStore.instance.petToRow(_pet(), 'owner-1');

      expect(PetDemoStore.profileV2Columns.every(row.containsKey), isTrue);
      final fallback = Map<String, dynamic>.of(row)
        ..removeWhere((key, _) => PetDemoStore.profileV2Columns.contains(key));
      expect(fallback.keys, containsAll(['id', 'name', 'species', 'sex']));
      expect(fallback.keys.any(PetDemoStore.profileV2Columns.contains), isFalse);
    });

    test('create keeps the new details and clearing works through copyWith', () async {
      final pet = await PetDemoStore.instance.create(
        name: 'Con dettagli',
        species: 'Cane',
        breed: null,
        birthDate: DateTime(2020, 5, 1),
        sex: 'Femmina',
        identityColor: const Color(0xFF163A35),
        isSterilized: true,
        microchipNumber: '380260000123456',
        coatColor: 'Miele',
        bodyCondition: 'normal',
        activityLevel: 'sedentary',
      );

      expect(pet.isSterilized, isTrue);
      expect(pet.microchipNumber, '380260000123456');
      expect(pet.coatColor, 'Miele');
      expect(pet.bodyCondition, 'normal');
      expect(pet.activityLevel, 'sedentary');

      final cleared = pet.copyWith(clearMicrochipNumber: true, clearIsSterilized: true);
      expect(cleared.microchipNumber, isNull);
      expect(cleared.isSterilized, isNull);
      expect(cleared.coatColor, 'Miele');
    });
  });
}
