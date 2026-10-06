import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/fish_species.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_breeds.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_species_breeds.dart';

const _categories = [
  'Piccoli mammiferi',
  'Uccello',
  'Rettili e anfibi',
  'Pesce',
  'Altro',
];

/// Names every earlier release offered, per category - a pet saved with one of
/// them must not turn into free text after the lists were rebuilt.
const _legacyNames = <String, List<String>>{
  'Piccoli mammiferi': [
    'Cavia', 'Chinchilla', 'Coniglio ariete', 'Coniglio nano', 'Coniglio olandese',
    'Coniglio Rex', 'Criceto Roborovski', 'Criceto Siberiano', 'Criceto Siriano', 'Degu',
    'Furetto', 'Gerbillo', 'Istrice africano', 'Ratto domestico', 'Riccio africano',
    'Topo domestico',
  ],
  'Uccello': [
    'Agapornis (inseparabile)', 'Amazzone', 'Ara', 'Cacatua', 'Calopsite', 'Canarino',
    'Cocorita', 'Diamante mandarino', 'Fringuello', 'Lorichetto arcobaleno',
    'Pappagallo cenerino', 'Pappagallo del Senegal', 'Parrocchetto dal collare',
    'Passero del Giappone',
  ],
  'Rettili e anfibi': [
    'Axolotl', 'Boa constrictor', 'Camaleonte del velo', 'Drago barbuto', 'Gecko crestato',
    'Gecko leopardino', 'Iguana verde', 'Pitone reale', 'Rana artigliata africana',
    'Rana toro', 'Salamandra tigrata', 'Serpente del latte', 'Serpente del mais',
    'Testuggine di terra', 'Testuggine palustre', 'Tritone',
  ],
  'Pesce': [
    'Barbo di Sumatra', 'Betta (pesce combattente)', 'Corydoras', 'Danio zebra', 'Discus',
    'Gourami perla', 'Guppy', 'Killifish', 'Loach botia', 'Molly', 'Neon tetra', 'Oscar',
    'Pesce angelo (scalare)', 'Pesce gatto corazzato', 'Pesce pagliaccio', 'Pesce rosso',
    'Platy', 'Plecostomus', 'Rasbora arlecchino', 'Tetra pinna nera', 'Xifo (pesce spada)',
  ],
};

void main() {
  group('every non dog/cat category', () {
    for (final category in _categories) {
      test('$category: generic entries first, "Altra (scrivi)" last', () {
        final options = PetDemoStore.breedsForSpecies(category);
        final pinned = speciesPinnedBreeds[category.toLowerCase()]!;

        expect(options.take(pinned.length).toList(), pinned);
        expect(options.last, otherEntryLabel);
        for (final label in pinned) {
          expect(isPinnedBreedEntry(label), isTrue);
        }
        expect(options.length, greaterThan(pinned.length + 1),
            reason: 'the list itself is not empty');
      });

      test('$category: alphabetical, no duplicates, no two entries share a common name', () {
        final pinned = speciesPinnedBreeds[category.toLowerCase()]!.toSet();
        final listed = PetDemoStore.breedsForSpecies(category)
            .where((name) => !pinned.contains(name) && name != otherEntryLabel)
            .toList();

        final sorted = [...listed]..sort((a, b) => foldBreedText(a).compareTo(foldBreedText(b)));
        expect(listed, sorted);
        expect(listed.toSet().length, listed.length);
        final common = listed.map((name) => foldBreedText(breedCommonName(name))).toList();
        expect(common.toSet().length, common.length,
            reason: 'two entries with the same common name would make old saved names ambiguous');
        expect(listed, isNot(contains(otherEntryLabel)));
        for (final label in pinned) {
          expect(listed, isNot(contains(label)));
        }
      });
    }

    test('the generic entries the owners asked for exist', () {
      expect(PetDemoStore.breedsForSpecies('Piccoli mammiferi'),
          containsAll(['Coniglio comune / meticcio', 'Altro roditore']));
      expect(PetDemoStore.breedsForSpecies('Uccello'), contains('Altro uccello'));
      expect(PetDemoStore.breedsForSpecies('Rettili e anfibi'),
          containsAll(['Altro rettile', 'Altro anfibio']));
      expect(PetDemoStore.breedsForSpecies('Pesce'), contains('Altro pesce'));
    });

    test('the aquarium population editor keeps its plain species list', () {
      expect(aquariumFishSpecies, isNot(contains('Altro pesce')));
      expect(aquariumFishSpecies, isNot(contains(otherEntryLabel)));
    });

    test('dogs and cats are unchanged by all of this', () {
      expect(PetDemoStore.breedsForSpecies('Cane').last, otherBreedLabel);
      expect(PetDemoStore.breedsForSpecies('Gatto').first, catMeticcioBreedLabel);
    });
  });

  group('pets saved with an earlier name stay valid', () {
    _legacyNames.forEach((category, names) {
      for (final name in names) {
        test('$category / $name is a listed name, not free text', () {
          final options = PetDemoStore.breedsForSpecies(category);

          expect(isCustomBreed(name, options), isFalse);
        });
      }
    });

    test('an unknown name is still kept as free text', () {
      final options = PetDemoStore.breedsForSpecies('Uccello');

      expect(isCustomBreed('Corvo imperiale', options), isTrue);
      expect(isCustomBreed('Altro', options), isTrue);
    });
  });

  group('search', () {
    bool finds(String entry, String query) => breedMatchesQuery(entry, query);

    test('ignores case and accents', () {
      expect(finds('Chinchilla', 'CINCILLA'), isTrue);
      expect(finds('Lucherino (Spinus spinus)', 'lucherino'), isTrue);
    });

    test('finds by scientific name', () {
      expect(finds('Calopsite (Nymphicus hollandicus)', 'nymphicus'), isTrue);
      expect(finds('Pitone reale', 'python regius'), isTrue,
          reason: 'the alias carries the scientific name');
    });

    test('words in any order, partial words', () {
      expect(finds('Pappagallo cenerino', 'cenerino pappagallo'), isTrue);
      expect(finds('Coniglio ariete nano (Mini Lop)', 'ariet nan'), isTrue);
    });

    test('a different word for the same animal finds it', () {
      expect(finds('Testuggine di Hermann (Testudo hermanni)', 'tartaruga'), isTrue);
      expect(finds('Criceto siriano (Mesocricetus auratus)', 'hamster'), isTrue);
      expect(finds('Cavia', 'guinea pig'), isTrue);
      expect(finds('Cavia', "porcellino d'india"), isTrue);
      expect(finds('Cocorita (Melopsittacus undulatus)', 'pappagallino ondulato'), isTrue);
      expect(finds('Drago barbuto (Pogona vitticeps)', 'pogona'), isTrue);
      expect(finds('Pesce rosso', 'goldfish'), isTrue);
      expect(finds('Gecko leopardino', 'geco'), isTrue);
    });

    test('an empty query matches everything and a wrong one nothing', () {
      expect(finds('Cavia', ''), isTrue);
      expect(finds('Cavia', '   '), isTrue);
      expect(finds('Cavia', 'delfino'), isFalse);
    });

    test('filtering a real list narrows it sensibly', () {
      final birds = PetDemoStore.breedsForSpecies('Uccello');

      final lovebirds = birds.where((b) => breedMatchesQuery(b, 'lovebird')).toList();

      expect(lovebirds, contains('Agapornis (inseparabile)'));
      expect(lovebirds, contains('Inseparabile facciarosa (Agapornis roseicollis)'));
      expect(lovebirds, isNot(contains('Canarino')));
    });
  });

  test('isOtherBreedEntry recognises both free-text labels', () {
    expect(isOtherBreedEntry(otherBreedLabel), isTrue);
    expect(isOtherBreedEntry(otherEntryLabel), isTrue);
    expect(isOtherBreedEntry('Cavia'), isFalse);
  });
}
