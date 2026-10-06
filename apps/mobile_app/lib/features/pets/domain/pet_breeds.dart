// Recognised breeds. The text is the working set for the owner-facing picker;
// each list is grouped by its FCI group in the comments below so it can be
// checked against the official FCI nomenclature. Italian names are the ENCI
// ones where ENCI uses one; otherwise the original name is kept.
//
// Verification note: this list was written from the FCI group structure, not
// copied from the live FCI register, so every name still needs a check against
// it before release. Saved breeds that are not in this list stay valid as free
// text (see [isCustomBreed]).

/// FCI group 1 - Cani da pastore e bovari (esclusi i bovari svizzeri).
const _fciGroup1 = <String>[
  'Bearded Collie',
  'Beauceron',
  'Bergamasco',
  'Bobtail',
  'Border Collie',
  'Bouvier des Flandres',
  'Briard',
  'Cane da pastore dei Pirenei',
  'Cane da pastore dell\'Anatolia',
  'Cane da pastore del Caucaso',
  'Collie a pelo lungo',
  'Collie a pelo ruvido',
  'Lupo cecoslovacco',
  'Mudi',
  'Pastore belga',
  'Pastore della Beauce',
  'Pastore delle Shetland',
  'Pastore di Tatra',
  'Pastore islandese',
  'Pastore maremmano-abruzzese',
  'Pastore polacco della Bassa Slesia',
  'Pastore tedesco',
  'Puli',
  'Pumi',
  'Welsh Corgi Cardigan',
  'Welsh Corgi Pembroke',
];

/// FCI group 2 - Pinscher, schnauzer, molossoidi e cani di tipo svizzero.
const _fciGroup2 = <String>[
  'Alano',
  'Bovaro dell\'Appenzell',
  'Bovaro dell\'Entlebuch',
  'Bovaro del Bernese',
  'Bovaro svizzero grande',
  'Boxer',
  'Bullmastiff',
  'Cane corso',
  'Cane di San Bernardo',
  'Dobermann',
  'Dogo argentino',
  'Dogo canario',
  'Dogo del Tibet',
  'Dogo tedesco',
  'Dogue de Bordeaux',
  'Landseer',
  'Mastiff',
  'Mastino napoletano',
  'Mastino spagnolo',
  'Pinscher nano',
  'Pinscher tedesco',
  'Rottweiler',
  'Schnauzer gigante',
  'Schnauzer medio',
  'Schnauzer nano',
  'Terranova',
];

/// FCI group 3 - Terrier.
const _fciGroup3 = <String>[
  'Airedale Terrier',
  'American Staffordshire Terrier',
  'Australian Terrier',
  'Bedlington Terrier',
  'Border Terrier',
  'Bull Terrier',
  'Bull Terrier in miniatura',
  'Cairn Terrier',
  'Cesky Terrier',
  'Dandie Dinmont Terrier',
  'Fox Terrier a pelo liscio',
  'Fox Terrier a pelo ruvido',
  'Irish Terrier',
  'Jack Russell Terrier',
  'Kerry Blue Terrier',
  'Lakeland Terrier',
  'Manchester Terrier',
  'Norfolk Terrier',
  'Norwich Terrier',
  'Parson Russell Terrier',
  'Sealyham Terrier',
  'Skye Terrier',
  'Soft-Coated Wheaten Terrier',
  'Staffordshire Bull Terrier',
  'Welsh Terrier',
  'West Highland White Terrier',
];

/// FCI group 4 - Bassotti.
const _fciGroup4 = <String>[
  'Bassotto',
  'Bassotto a pelo lungo',
  'Bassotto a pelo ruvido',
  'Bassotto nano',
  'Bassotto nano a pelo lungo',
  'Bassotto nano a pelo ruvido',
];

/// FCI group 5 - Spitz e tipi primitivi.
const _fciGroup5 = <String>[
  'Akita',
  'Alaskan Malamute',
  'Basenji',
  'Chow Chow',
  'Cirneco dell\'Etna',
  'Eurasier',
  'Hokkaido',
  'Husky siberiano',
  'Ibizan Hound',
  'Jindo coreano',
  'Kai Ken',
  'Kishu',
  'Lapphund svedese',
  'Pharaoh Hound',
  'Podenco canario',
  'Podenco ibicenco',
  'Podenco portoghese',
  'Samoiedo',
  'Shiba Inu',
  'Shikoku',
  'Spitz finlandese',
  'Spitz giapponese',
  'Spitz nano',
  'Spitz tedesco',
  'Volpino italiano',
];

/// FCI group 6 - Segugi e cani da seguito.
const _fciGroup6 = <String>[
  'Basset Hound',
  'Basset Artésien Normand',
  'Basset Fauve de Bretagne',
  'Beagle',
  'Bloodhound',
  'Dalmata',
  'Grand Bleu de Gascogne',
  'Hamilton Stövare',
  'Harrier',
  'Petit Basset Griffon Vendéen',
  'Segugio italiano a pelo forte',
  'Segugio italiano a pelo raso',
  'Segugio maremmano',
  'Segugio svizzero',
  'Foxhound inglese',
  'Foxhound americano',
];

/// FCI group 7 - Cani da ferma.
const _fciGroup7 = <String>[
  'Bracco italiano',
  'Bracco tedesco a pelo corto',
  'Bracco tedesco a pelo ruvido',
  'Bracco ungherese',
  'Bretone',
  'Cane da ferma tedesco a pelo corto',
  'Cane da ferma tedesco a pelo ruvido',
  'Epagneul di Pont-Audemer',
  'Epagneul francese',
  'Griffone a pelo ruvido',
  'Kurzhaar',
  'Drahthaar',
  'Pointer',
  'Setter gordon',
  'Setter inglese',
  'Setter irlandese',
  'Setter irlandese rosso e bianco',
  'Spinone italiano',
  'Vizsla',
  'Vizsla a pelo ruvido',
  'Weimaraner',
];

/// FCI group 8 - Cani da riporto, da cerca e da acqua.
const _fciGroup8 = <String>[
  'Boykin Spaniel',
  'Chesapeake Bay Retriever',
  'Clumber Spaniel',
  'Cocker Spaniel americano',
  'Cocker Spaniel inglese',
  'Cane d\'acqua irlandese',
  'Curly-Coated Retriever',
  'Field Spaniel',
  'Flat-Coated Retriever',
  'Golden Retriever',
  'Labrador Retriever',
  'Nova Scotia Duck Tolling Retriever',
  'Cane d\'acqua portoghese',
  'Springer Spaniel gallese',
  'Springer Spaniel inglese',
  'Sussex Spaniel',
];

/// FCI group 9 - Cani da compagnia e cani di tipo primitivo (Asia).
const _fciGroup9 = <String>[
  'Affenpinscher',
  'Barboncino',
  'Bichon frisé',
  'Bichon havanese',
  'Bichon maltese',
  'Bolognese',
  'Carlino',
  'Cavalier King Charles Spaniel',
  'Chihuahua',
  'Chin giapponese',
  'Coton de Tuléar',
  'Cane cinese crestato',
  'Griffon Bruxellois',
  'King Charles Spaniel',
  'Lhasa Apso',
  'Löwchen',
  'Papillon',
  'Pechinese',
  'Petit Brabançon',
  'Pug',
  'Shih Tzu',
  'Spaniel tibetano',
  'Terrier tibetano',
];

/// FCI group 10 - Levrieri.
const _fciGroup10 = <String>[
  'Azawakh',
  'Borzoi',
  'Chart polacco',
  'Galgo spagnolo',
  'Levriero afgano',
  'Levriero inglese',
  'Levriero irlandese',
  'Levriero italiano',
  'Levriero scozzese',
  'Magyar agár',
  'Saluki',
  'Sloughi',
  'Whippet',
];

/// The FCI groups, keyed by their FCI name. Kept public so a test can check
/// the raw lists for duplicates before they are merged.
const fciDogGroups = <String, List<String>>{
  'Gruppo 1 - Cani da pastore e bovari': _fciGroup1,
  'Gruppo 2 - Pinscher, schnauzer, molossoidi e svizzeri': _fciGroup2,
  'Gruppo 3 - Terrier': _fciGroup3,
  'Gruppo 4 - Bassotti': _fciGroup4,
  'Gruppo 5 - Spitz e tipi primitivi': _fciGroup5,
  'Gruppo 6 - Segugi e cani da seguito': _fciGroup6,
  'Gruppo 7 - Cani da ferma': _fciGroup7,
  'Gruppo 8 - Cani da riporto, da cerca e da acqua': _fciGroup8,
  'Gruppo 9 - Cani da compagnia': _fciGroup9,
  'Gruppo 10 - Levrieri': _fciGroup10,
};

/// Every FCI breed above, alphabetical and without duplicates.
final List<String> fciDogBreeds = _sortedUnique([
  for (final group in fciDogGroups.values) ...group,
]);

/// Recognised cat breeds (FIFe names, Italian where common).
final List<String> fifeCatBreeds = _sortedUnique([
  'Abissino',
  'American Bobtail',
  'American Curl',
  'American Shorthair',
  'American Wirehair',
  'Angora turco',
  'Asian',
  'Balinese',
  'Bengala',
  'Birmano',
  'Bombay',
  'British Longhair',
  'British Shorthair',
  'Burmese',
  'Burmilla',
  'Certosino',
  'Chartreux',
  'Cornish Rex',
  'Cymric',
  'Devon Rex',
  'Donskoy',
  'Europeo / comune',
  'Exotic Shorthair',
  'German Rex',
  'Havana',
  'Highlander',
  'Khao Manee',
  'Korat',
  'Kurilian Bobtail',
  'LaPerm',
  'Maine Coon',
  'Manx',
  'Munchkin',
  'Norvegese delle foreste',
  'Ocicat',
  'Orientale',
  'Persiano',
  'Peterbald',
  'Ragamuffin',
  'Ragdoll',
  'Russo blu',
  'Savannah',
  'Scottish Fold',
  'Scottish Straight',
  'Selkirk Rex',
  'Siamese',
  'Siberiano',
  'Singapura',
  'Snowshoe',
  'Somalo',
  'Sphynx',
  'Thai',
  'Tonchinese',
  'Toyger',
  'Turkish Van',
]);

/// The free-text escape hatch, always last in a species' list.
const otherBreedLabel = 'Altra razza (scrivi)';

/// Pinned at the top of the picker: the neutral term for a mixed-breed pet.
const meticcioBreedLabel = 'Meticcio / incrocio';
const catMeticcioBreedLabel = 'Meticcio / europeo comune';

/// The pinned entries, which the picker shows first and separates visually.
const pinnedBreedLabels = <String>{meticcioBreedLabel, catMeticcioBreedLabel};

/// Names saved before the list was complete, still accepted as known.
const _knownAliases = <String, Set<String>>{
  'Europeo / comune': {'Europeo'},
  'Cane di San Bernardo': {'San Bernardo'},
  meticcioBreedLabel: {'Meticcio / altra razza', 'Meticcio'},
  catMeticcioBreedLabel: {'Meticcio'},
  'Criceto di Roborovski (Phodopus roborovskii)': {'Criceto Roborovski'},
};

/// Lowercase and without accents, for tolerant search and comparison.
String foldBreedText(String text) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüýÿçñ';
  const to = 'aaaaaaeeeeiiiiooooouuuuyycn';
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString().trim();
}

/// True when a saved breed is free text rather than one of the listed breeds
/// (or an alias of one), so the form shows the "altra razza" field for it.
bool isCustomBreed(String breed, List<String> listed) {
  if (breed == 'Altro') return true;
  if (pinnedBreedLabels.contains(breed)) return false;
  final folded = foldBreedText(breed);
  for (final known in [...listed, ...pinnedBreedLabels]) {
    if (foldBreedText(known) == folded) return false;
    // "Calopsite (Nymphicus hollandicus)" also accepts the older, shorter
    // "Calopsite" - a name saved before the scientific name was added.
    if (foldBreedText(_withoutBrackets(known)) == folded) return false;
    if (_knownAliases[known]?.any((alias) => foldBreedText(alias) == folded) ?? false) {
      return false;
    }
  }
  return true;
}

/// [name] without a trailing "(...)": the common name alone.
String _withoutBrackets(String name) => name.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '');

/// [name] without a trailing "(...)" - the common name alone, as saved by older
/// versions that listed no scientific names.
String breedCommonName(String name) => _withoutBrackets(name);

/// Names alphabetical (accents and case ignored) and without duplicates.
List<String> sortedUniqueNames(List<String> names) => _sortedUnique(names);

List<String> _sortedUnique(List<String> names) {
  final unique = names.toSet().toList()
    ..sort((a, b) => foldBreedText(a).compareTo(foldBreedText(b)));
  return List<String>.unmodifiable(unique);
}
