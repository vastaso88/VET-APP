import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_breeds.dart';

void main() {
  test('no duplicates across the FCI groups, and the flat list is complete', () {
    final raw = [for (final group in fciDogGroups.values) ...group];
    expect(raw.toSet().length, raw.length, reason: 'a breed appears in more than one place');
    expect(fciDogBreeds.length, raw.length);
  });

  test('every FCI group has breeds, including rare ones', () {
    for (final entry in fciDogGroups.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
    }
    expect(fciDogGroups.length, 10);
    expect(fciDogGroups['Gruppo 1 - Cani da pastore e bovari']!, contains('Puli'));
    expect(fciDogGroups['Gruppo 2 - Pinscher, schnauzer, molossoidi e svizzeri']!, contains('Dogo del Tibet'));
    expect(fciDogGroups['Gruppo 5 - Spitz e tipi primitivi']!, contains('Kishu'));
    expect(fciDogGroups['Gruppo 6 - Segugi e cani da seguito']!, contains('Hamilton Stövare'));
    expect(fciDogGroups['Gruppo 7 - Cani da ferma']!, contains('Weimaraner'));
    expect(fciDogGroups['Gruppo 7 - Cani da ferma']!, contains('Kurzhaar'));
    expect(fciDogGroups['Gruppo 8 - Cani da riporto, da cerca e da acqua']!, contains('Sussex Spaniel'));
    expect(fciDogGroups['Gruppo 9 - Cani da compagnia']!, contains('Löwchen'));
    expect(fciDogGroups['Gruppo 10 - Levrieri']!, contains('Magyar agár'));
  });

  test('dog and cat lists are alphabetical (accents ignored) and without duplicates', () {
    for (final list in [fciDogBreeds, fifeCatBreeds]) {
      final sorted = [...list]..sort((a, b) => foldBreedText(a).compareTo(foldBreedText(b)));
      expect(list, sorted);
      expect(list.toSet().length, list.length);
    }
  });

  test('search is tolerant of case and accents', () {
    expect(foldBreedText('BICHON Frisé'), 'bichon frise');
    expect(foldBreedText('bichon frise').contains(foldBreedText('FRISÉ')), isTrue);
  });

  test('breeds saved with older names stay valid: known aliases and free text', () {
    expect(isCustomBreed('Bassotto', fciDogBreeds), isFalse);
    expect(isCustomBreed('Europeo', fifeCatBreeds), isFalse, reason: 'alias of Europeo / comune');
    expect(isCustomBreed('Cocker', fciDogBreeds), isTrue, reason: 'unlisted name is kept as free text');
    expect(isCustomBreed('Altro', fciDogBreeds), isTrue);
    expect(isCustomBreed('Incrocio di barboncino', fciDogBreeds), isTrue);
  });

  test('dogs and cats end with the free-text option, which is never a real breed', () {
    expect(PetDemoStore.breedsForSpecies('Cane').last, otherBreedLabel);
    expect(PetDemoStore.breedsForSpecies('Gatto').last, otherBreedLabel);
    expect(fciDogBreeds, isNot(contains(otherBreedLabel)));
    expect(fifeCatBreeds, isNot(contains(otherBreedLabel)));
  });

  test('sex options cover the agreed values', () {
    expect(
      PetDemoStore.sexOptions,
      containsAll([
        'Maschio',
        'Femmina',
        'Maschio intero',
        'Maschio castrato',
        'Femmina intera',
        'Femmina sterilizzata',
      ]),
    );
  });
}
