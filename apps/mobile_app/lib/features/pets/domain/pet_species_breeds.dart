import 'pet_breeds.dart';
import 'fish_species.dart';

// Breeds, varieties and species for every category besides dogs and cats
// (those live in pet_breeds.dart). The categories are the ones the app already
// has - "Piccoli mammiferi", "Uccello", "Rettili e anfibi", "Pesce", "Altro" -
// and are not changed here, because the chat, the news feed and saved pets all
// key on those labels.
//
// Names are the Italian ones in common use, with the scientific name in
// brackets where it helps tell animals apart. A saved name written before
// this list grew (e.g. "Calopsite", "Testuggine di terra") stays valid: the
// picker compares without the bracketed part (see isCustomBreed).
//
// Like the dog list, this was written from standard references, not copied
// from a registry: rabbit breeds follow the common ANCI/ARBA show names, the
// rest the usual pet-trade names. Anything missing is covered by the generic
// entries and by free text.

/// The free-text escape hatch for every category except dogs and cats
/// (those keep "Altra razza (scrivi)").
const otherEntryLabel = 'Altra (scrivi)';

const _rabbitGeneric = 'Coniglio comune / meticcio';
const _rodentGeneric = 'Altro roditore';
const _smallMammalGeneric = 'Altro piccolo mammifero';
const _birdGeneric = 'Altro uccello';
const _reptileGeneric = 'Altro rettile';
const _amphibianGeneric = 'Altro anfibio';
const _fishGeneric = 'Altro pesce';
const _animalGeneric = 'Altro animale';

/// Pinned at the top of each category's picker, in this order, styled like
/// "Meticcio / incrocio". Keys are the lower-case category labels.
const speciesPinnedBreeds = <String, List<String>>{
  'piccoli mammiferi': [_rabbitGeneric, _rodentGeneric, _smallMammalGeneric],
  'uccello': [_birdGeneric],
  'rettili e anfibi': [_reptileGeneric, _amphibianGeneric],
  'pesce': [_fishGeneric],
  'altro': [_animalGeneric],
};

/// Every pinned label of these categories, for the picker's visual grouping.
final Set<String> speciesPinnedLabels = {
  for (final labels in speciesPinnedBreeds.values) ...labels,
};

/// Rabbits (breeds), rodents (species and varieties) and the other small
/// mammals kept at home. Alphabetical, so each family sits together.
final List<String> smallMammalBreeds = sortedUniqueNames(const [
  // Conigli
  'Coniglio angora',
  'Coniglio ariete',
  'Coniglio ariete francese (French Lop)',
  'Coniglio ariete inglese (English Lop)',
  'Coniglio ariete nano (Mini Lop)',
  'Coniglio arlecchino (Harlequin)',
  'Coniglio argentato di Champagne',
  'Coniglio bianco di Vienna',
  'Coniglio blu di Vienna',
  'Coniglio californiano',
  'Coniglio cincillà (razza)',
  'Coniglio fulvo di Borgogna',
  'Coniglio gigante di Fiandra (Flemish Giant)',
  'Coniglio gigante grigio',
  'Coniglio Havana',
  'Coniglio Hotot nano',
  'Coniglio Jersey Wooly',
  'Coniglio nano',
  'Coniglio nano colorato',
  'Coniglio nano testa di leone (Lionhead)',
  'Coniglio Nuova Zelanda bianco',
  'Coniglio olandese',
  'Coniglio Polish (polacco)',
  'Coniglio Rex',
  'Coniglio Rex nano (Mini Rex)',
  'Coniglio volpe nano (Swiss Fox)',
  // Criceti
  'Criceto cinese (Cricetulus griseus)',
  'Criceto di Roborovski (Phodopus roborovskii)',
  'Criceto russo (Phodopus campbelli)',
  'Criceto siberiano (Phodopus sungorus)',
  'Criceto siriano (Mesocricetus auratus)',
  'Criceto siriano a pelo lungo (teddy bear)',
  // Cavie
  'Cavia',
  'Cavia abissina (rosette)',
  'Cavia americana (pelo corto)',
  'Cavia coronet',
  'Cavia peruviana (pelo lungo)',
  'Cavia Rex',
  'Cavia skinny (senza pelo)',
  'Cavia teddy',
  'Cavia Texel',
  // Altri roditori
  'Cane della prateria (Cynomys ludovicianus)',
  'Chinchilla',
  'Degu (Octodon degus)',
  'Gerbillo (Meriones unguiculatus)',
  'Gerbillo grasso (Pachyuromys duprasi)',
  'Ratto domestico',
  'Ratto domestico Dumbo',
  'Ratto domestico Rex',
  'Ratto domestico Sphynx (senza pelo)',
  'Scoiattolo striato siberiano (Tamias sibiricus)',
  'Topo domestico',
  'Topo domestico fancy',
  'Topo spinoso del Cairo (Acomys cahirinus)',
  // Altri piccoli mammiferi
  'Furetto (Mustela putorius furo)',
  'Istrice africano',
  'Opossum nano (Monodelphis domestica)',
  'Petauro dello zucchero (Petaurus breviceps)',
  'Riccio africano (Atelerix albiventris)',
]);

/// Birds kept as pets: parrots, finches and canaries, doves.
final List<String> birdBreeds = sortedUniqueNames(const [
  'Agapornis (inseparabile)',
  'Amazzone',
  'Amazzone fronte blu (Amazona aestiva)',
  'Ara',
  'Ara ararauna (blu e oro)',
  'Ara militare (Ara militaris)',
  'Ara scarlatta (Ara macao)',
  'Bengalino (Amandava amandava)',
  'Cacatua',
  'Cacatua alba (Cacatua alba)',
  'Cacatua dal ciuffo giallo (Cacatua galerita)',
  'Cacatua rosa (Eolophus roseicapilla)',
  'Calopsite (Nymphicus hollandicus)',
  'Canarino',
  'Canarino Border',
  'Canarino fattore rosso',
  'Canarino Gloster',
  'Canarino Harzer (da canto)',
  'Canarino Norwich',
  'Canarino Timbrado (da canto)',
  'Canarino Yorkshire',
  'Cardellino (Carduelis carduelis)',
  'Cocorita (Melopsittacus undulatus)',
  'Cocorita inglese (da esposizione)',
  'Conuro dalle guance verdi (Pyrrhura molinae)',
  'Conuro del sole (Aratinga solstitialis)',
  'Diamante di Gould (Chloebia gouldiae)',
  'Diamante mandarino',
  'Eclectus (Eclectus roratus)',
  'Fringuello',
  'Inseparabile facciarosa (Agapornis roseicollis)',
  'Inseparabile di Fischer (Agapornis fischeri)',
  'Inseparabile mascherato (Agapornis personatus)',
  'Lorichetto arcobaleno',
  'Lucherino (Spinus spinus)',
  'Merlo indiano (Gracula religiosa)',
  'Pappagallo cenerino',
  'Pappagallo cenerino del Congo (Psittacus erithacus)',
  'Pappagallo del Senegal',
  'Pappagallo testa nera (Pionites melanocephalus)',
  'Parrocchetto dal collare',
  'Parrocchetto di Bourke (Neopsephotus bourkii)',
  'Parrocchetto monaco (Myiopsitta monachus)',
  'Passero del Giappone',
  'Piccione domestico (Columba livia domestica)',
  'Quaglia giapponese (Coturnix japonica)',
  'Tortora domestica (Streptopelia risoria)',
  'Usignolo del Giappone (Leiothrix lutea)',
]);

/// Reptiles (tortoises and turtles, lizards, snakes) and amphibians.
final List<String> reptileAmphibianBreeds = sortedUniqueNames(const [
  // Tartarughe e testuggini terrestri
  'Testuggine di terra',
  'Testuggine di Hermann (Testudo hermanni)',
  'Testuggine egiziana (Testudo kleinmanni)',
  'Testuggine greca (Testudo graeca)',
  'Testuggine leopardo (Stigmochelys pardalis)',
  'Testuggine marginata (Testudo marginata)',
  'Testuggine russa (Testudo horsfieldii)',
  'Testuggine sulcata (Centrochelys sulcata)',
  'Testuggine dai piedi rossi (Chelonoidis carbonarius)',
  // Tartarughe acquatiche
  'Testuggine palustre',
  'Testuggine palustre europea (Emys orbicularis)',
  'Tartaruga a guscio molle (Apalone spinifera)',
  'Tartaruga dalle orecchie gialle (Trachemys scripta scripta)',
  'Tartaruga dalle orecchie rosse (Trachemys scripta elegans)',
  'Tartaruga dipinta (Chrysemys picta)',
  'Tartaruga muschiata (Sternotherus odoratus)',
  'Tartaruga Cooter (Pseudemys)',
  // Lucertole, gechi, camaleonti
  'Anolis verde (Anolis carolinensis)',
  'Camaleonte del velo',
  'Camaleonte pantera (Furcifer pardalis)',
  'Drago barbuto (Pogona vitticeps)',
  'Gecko crestato',
  'Gecko dalla coda grassa (Hemitheconyx caudicinctus)',
  'Gecko diurno (Phelsuma)',
  'Gecko gargoyle (Rhacodactylus auriculatus)',
  'Gecko leopardino',
  'Gecko tokay (Gekko gecko)',
  'Iguana verde',
  'Scinco dalla lingua blu (Tiliqua scincoides)',
  'Uromastyx (Uromastyx)',
  'Varano delle savane (Varanus exanthematicus)',
  // Serpenti
  'Boa arcobaleno (Epicrates cenchria)',
  'Boa constrictor',
  'Pitone birmano (Python bivittatus)',
  'Pitone reale',
  'Pitone tappeto (Morelia spilota)',
  'Serpente del latte',
  'Serpente del mais',
  'Serpente giarrettiera (Thamnophis sirtalis)',
  'Serpente reale californiano (Lampropeltis californiae)',
  // Anfibi
  'Axolotl',
  'Rana artigliata africana',
  'Rana dagli occhi rossi (Agalychnis callidryas)',
  'Rana di White (Litoria caerulea)',
  'Rana freccia (Dendrobates)',
  'Rana pigmea africana (Hymenochirus)',
  'Rana ornata cornuta (Ceratophrys ornata)',
  'Rana toro',
  'Salamandra tigrata',
  'Tritone',
  'Tritone dal ventre di fuoco (Cynops orientalis)',
]);

/// Everything else kept at home or on a small farm.
final List<String> otherAnimalBreeds = sortedUniqueNames(const [
  'Alpaca (Vicugna pacos)',
  'Anatra domestica',
  'Asino',
  'Capra nana',
  'Cavallo',
  'Gallina ornamentale',
  'Granchio eremita',
  'Insetto stecco',
  'Lama (Lama glama)',
  'Lumaca gigante africana (Achatina)',
  'Maiale nano (mini pig)',
  'Mantide religiosa',
  'Oca domestica',
  'Pecora',
  'Pony',
  'Scorpione imperatore (Pandinus imperator)',
  'Tarantola (Theraphosidae)',
]);

/// Freshwater and marine fish for the single-fish picker, on top of the shared
/// aquarium list ([aquariumFishSpecies]) so a lone fish and a tank offer the
/// same names.
final List<String> fishBreeds = aquariumFishSpecies;

/// The breed list (generic entries first, free text last) for a category that
/// is not a dog or a cat, or null when [speciesKey] is not one of them.
List<String>? otherSpeciesBreedOptions(String speciesKey) {
  final key = speciesKey.trim().toLowerCase();
  final pinned = speciesPinnedBreeds[key];
  if (pinned == null) return null;
  final listed = switch (key) {
    'piccoli mammiferi' => smallMammalBreeds,
    'uccello' => birdBreeds,
    'rettili e anfibi' => reptileAmphibianBreeds,
    'pesce' => fishBreeds,
    _ => otherAnimalBreeds,
  };
  return [...pinned, ...listed, otherEntryLabel];
}

/// True for the free-text entry of any category, dog/cat included.
bool isOtherBreedEntry(String label) => label == otherBreedLabel || label == otherEntryLabel;

/// Alternative names a search should also find, keyed by the listed name.
/// Terms are folded the same way as the query (accents and case ignored).
const breedSearchAliases = <String, String>{
  'Agapornis (inseparabile)': 'lovebird inseparabili',
  'Axolotl': 'assolotto ambystoma mexicanum',
  'Betta (pesce combattente)': 'betta splendens combattente',
  'Calopsite (Nymphicus hollandicus)': 'cockatiel cacatua nano',
  'Cavia': 'porcellino d india guinea pig cavia porcellus',
  'Chinchilla': 'cincilla chinchilla lanigera',
  'Cocorita (Melopsittacus undulatus)': 'pappagallino ondulato parrocchetto ondulato budgerigar',
  'Coniglio nano': 'netherland dwarf',
  'Drago barbuto (Pogona vitticeps)': 'pogona agama barbuta bearded dragon',
  'Furetto (Mustela putorius furo)': 'ferret',
  'Gecko leopardino': 'eublepharis macularius leopard gecko geco',
  'Guppy': 'poecilia reticulata lebistes',
  'Iguana verde': 'iguana iguana',
  'Neon tetra': 'paracheirodon innesi neon',
  'Pesce rosso': 'carassius auratus goldfish',
  'Pitone reale': 'python regius ball python',
  'Riccio africano (Atelerix albiventris)': 'riccio pigmeo hedgehog',
  'Serpente del mais': 'pantherophis guttatus corn snake',
  'Xifo (pesce spada)': 'xiphophorus hellerii',
};

/// Words a person types that the list spells differently: a search for
/// "tartaruga" must also show every "Testuggine ...". Query word -> the
/// word(s) to look for instead, all folded.
const _querySynonyms = <String, List<String>>{
  'tartaruga': ['testuggine'],
  'tartarughe': ['testuggine', 'tartaruga'],
  'testuggini': ['testuggine'],
  'hamster': ['criceto'],
  'rabbit': ['coniglio'],
  'ferret': ['furetto'],
  'guinea': ['cavia'],
  'porcellino': ['cavia'],
  'cockatiel': ['calopsite'],
  'lovebird': ['agapornis', 'inseparabile'],
  'budgerigar': ['cocorita'],
  'pappagallino': ['cocorita'],
  'geco': ['gecko'],
  'gechi': ['gecko'],
  'chinchilla': ['cincilla', 'chinchilla'],
  'goldfish': ['pesce rosso'],
  'koi': ['carpa'],
  'pogona': ['drago barbuto', 'pogona'],
};

/// Case-, accent- and punctuation-tolerant, word-order-free search over a
/// breed list: every word typed must appear in the name, its scientific name
/// or one of its [breedSearchAliases] (or in a synonym of that word).
bool breedMatchesQuery(String breed, String query) {
  final words = _searchFold(query).split(' ').where((word) => word.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = _searchFold('$breed ${breedSearchAliases[breed] ?? ''}');
  return words.every((word) {
    if (haystack.contains(word)) return true;
    final synonyms = _querySynonyms[word];
    return synonyms != null && synonyms.any((synonym) => haystack.contains(synonym));
  });
}

String _searchFold(String text) => foldBreedText(text)
    .replaceAll(RegExp(r"[’'\-()/,.]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// True for a label pinned at the top of some category's picker.
bool isPinnedBreedEntry(String label) =>
    pinnedBreedLabels.contains(label) || speciesPinnedLabels.contains(label);
