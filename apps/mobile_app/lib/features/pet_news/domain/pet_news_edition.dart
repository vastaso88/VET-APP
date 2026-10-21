/// The news a country reads, in the language it reads them in: which Google
/// News edition to ask for, the search words per species and the words that
/// mark a headline as off-topic (recipes, hunting, horoscopes). One
/// [PetNewsEdition] per app language; the country picks the edition
/// parameters. The per-species keys are the stored category values
/// ('Cane', 'Gatto'...), never shown: the labels come from the ARB files.
class PetNewsEdition {
  const PetNewsEdition({
    required this.languageCode,
    required this.countryCode,
    required this.hl,
    required this.gl,
    required this.ceid,
    required this.queryBySpecies,
    required this.blockedKeywords,
  });

  final String languageCode;
  final String countryCode;

  /// Google News edition parameters (`hl`, `gl`, `ceid`).
  final String hl;
  final String gl;
  final String ceid;

  /// Search text per category, with the off-topic exclusions already in.
  final Map<String, String> queryBySpecies;

  /// Lower-case fragments; a headline containing any is dropped.
  final List<String> blockedKeywords;

  /// Cache key: two editions never share cached headlines.
  String get cacheKey => '$languageCode-$countryCode';

  String queryFor(String species) => queryBySpecies[species] ?? queryBySpecies['Altro']!;
}

/// Languages the app has news words for.
const pressLanguages = ['it', 'en', 'es', 'de', 'fr'];

/// Google News edition parameters for a language in a country. The language
/// the owner reads wins over the country's usual language (a Swiss owner
/// reading German gets `de-CH`, not French). Countries not listed fall back
/// to their language's main country, which is the only honest default.
({String hl, String gl, String ceid}) googleNewsEditionFor(String languageCode, String countryCode) {
  final country = countryCode.toUpperCase();
  switch (languageCode) {
    case 'it':
      return (hl: 'it', gl: 'IT', ceid: 'IT:it');
    case 'en':
      const known = {'GB', 'US', 'AU'};
      final target = known.contains(country) ? country : 'US';
      return (hl: 'en-$target', gl: target, ceid: '$target:en');
    case 'es':
      return (hl: 'es', gl: 'ES', ceid: 'ES:es');
    case 'de':
      const known = {'DE', 'AT', 'CH'};
      final target = known.contains(country) ? country : 'DE';
      return (hl: target == 'DE' ? 'de' : 'de-$target', gl: target, ceid: '$target:de');
    case 'fr':
      const known = {'FR', 'BE', 'CH'};
      final target = known.contains(country) ? country : 'FR';
      return (hl: target == 'FR' ? 'fr' : 'fr-$target', gl: target, ceid: '$target:fr');
    default:
      return (hl: 'it', gl: 'IT', ceid: 'IT:it');
  }
}

/// The edition for [languageCode] read in [countryCode]. An unknown language
/// gets the source language's edition (Italian) rather than a made-up one.
PetNewsEdition petNewsEditionFor(String languageCode, String countryCode) {
  final language = _wordsByLanguage[languageCode] != null ? languageCode : 'it';
  final words = _wordsByLanguage[language]!;
  final edition = googleNewsEditionFor(language, countryCode);
  return PetNewsEdition(
    languageCode: language,
    countryCode: edition.gl,
    hl: edition.hl,
    gl: edition.gl,
    ceid: edition.ceid,
    queryBySpecies: words.queries,
    blockedKeywords: words.blocked,
  );
}

class _Words {
  const _Words(this.queries, this.blocked);

  final Map<String, String> queries;
  final List<String> blocked;
}

// Every query excludes food, hunting and horoscope terms: several species are
// also ingredients or zodiac signs, and unfiltered searches surface
// recipe-style articles next to real animal news. The exclusion is a
// best-effort pass at query level; the `blocked` list is the second pass over
// the actual headlines.
const _itExclusions =
    '-ricetta -ricette -cucina -cucinare -forno -sagra -caccia -cacciatore -cacciatori -oroscopo';
const _enExclusions =
    '-recipe -recipes -cooking -cookery -barbecue -hunting -hunter -horoscope -menu';
const _esExclusions = '-receta -recetas -cocina -cocinar -horno -caza -cazador -horóscopo';
const _deExclusions = '-rezept -rezepte -kochen -backofen -jagd -jäger -horoskop';
const _frExclusions = '-recette -recettes -cuisine -cuisiner -four -chasse -chasseur -horoscope';

const _wordsByLanguage = <String, _Words>{
  'it': _Words(
    {
      'Cane': 'cane $_itExclusions',
      'Gatto': 'gatto $_itExclusions',
      // "Coniglio" is a common surname and "cavia" also means "human guinea
      // pig" in everyday Italian: positive bias plus experiment exclusions.
      'Piccoli mammiferi':
          '(coniglio OR cavia OR criceto OR furetto) (domestico OR animale OR veterinario OR appartamento) $_itExclusions -esperimento -esperimenti -sperimentazione',
      'Uccello':
          '(uccello OR pappagallo OR canarino OR cocorita) (domestico OR gabbia OR veterinario) $_itExclusions',
      // "Rana" collides with "rana pescatrice" (monkfish).
      'Rettili e anfibi':
          '(rettile OR anfibio OR rana OR salamandra OR tartaruga) (domestico OR terrario OR veterinario) $_itExclusions -pescatrice',
      // Bare "pesce" is food/fishing content: anchored on aquarium words.
      'Pesce':
          '(acquario OR acquariofilia OR "pesci d\'acquario" OR "pesce rosso") $_itExclusions',
      'Altro': 'animali domestici $_itExclusions',
      'Generale': 'animali domestici (fiera OR legge OR normativa) $_itExclusions',
    },
    [
      'ricetta',
      'ricette',
      'cucina',
      'cucinare',
      'cotto',
      'cottura',
      'arrosto',
      'spezzatino',
      'stufato',
      'brasato',
      'padella',
      'in forno',
      'al forno',
      'fritto',
      'fritti',
      'frittura',
      'bollit',
      'filetti',
      'selvaggina',
      'uccellagione',
      'chef',
      'piatto',
      'ricettar',
      'ingredienti',
      'gustoso',
      'sagra',
      'porchetta',
      'grigliata',
      'grigliato',
      'caccia',
      'cacciatore',
      'cacciatori',
      'cacciatora',
      'oroscopo',
      'tamagotchi',
      'tamaverse',
      'pescatrice',
      'cosce di rana',
      'rane fritte',
      'esperimento',
      'esperimenti',
      'sperimentazione',
    ],
  ),
  'en': _Words(
    {
      'Cane': '(dog OR puppy) (pet OR owner OR vet OR veterinary) $_enExclusions',
      'Gatto': '(cat OR kitten) (pet OR owner OR vet OR veterinary) $_enExclusions',
      'Piccoli mammiferi':
          '(rabbit OR "guinea pig" OR hamster OR ferret OR chinchilla) (pet OR vet OR veterinary OR housing) $_enExclusions -experiment -experiments -testing',
      'Uccello':
          '(parrot OR budgie OR canary OR cockatiel) (pet OR cage OR veterinary) $_enExclusions',
      'Rettili e anfibi':
          '(reptile OR amphibian OR tortoise OR gecko OR "bearded dragon") (pet OR terrarium OR veterinary) $_enExclusions',
      'Pesce': '(aquarium OR aquarist OR goldfish OR "tropical fish") $_enExclusions',
      'Altro': '"pet owners" OR "pet animals" $_enExclusions',
      'Generale': 'pets (law OR regulation OR show OR expo) $_enExclusions',
    },
    [
      'recipe',
      'recipes',
      'cooking',
      'cookery',
      'barbecue',
      'bbq',
      'roast',
      'stew',
      'ingredients',
      'delicious',
      'menu',
      'hunting',
      'hunter',
      'horoscope',
      'tamagotchi',
      'tamaverse',
      'experiment',
      'experiments',
    ],
  ),
  'es': _Words(
    {
      'Cane': '(perro OR cachorro) (mascota OR veterinario OR dueño) $_esExclusions',
      'Gatto': '(gato OR gatito) (mascota OR veterinario OR dueño) $_esExclusions',
      'Piccoli mammiferi':
          '(conejo OR cobaya OR hámster OR hurón) (mascota OR veterinario OR doméstico) $_esExclusions -experimento -experimentos',
      'Uccello': '(pájaro OR loro OR canario OR periquito) (mascota OR jaula OR veterinario) $_esExclusions',
      'Rettili e anfibi':
          '(reptil OR anfibio OR tortuga OR gecko OR rana) (mascota OR terrario OR veterinario) $_esExclusions',
      'Pesce': '(acuario OR acuarofilia OR "pez dorado" OR "peces tropicales") $_esExclusions',
      'Altro': '"animales de compañía" OR mascotas $_esExclusions',
      'Generale': 'mascotas (ley OR normativa OR feria OR exposición) $_esExclusions',
    },
    [
      'receta',
      'recetas',
      'cocina',
      'cocinar',
      'guiso',
      'asado',
      'al horno',
      'frito',
      'ingredientes',
      'delicioso',
      'caza',
      'cazador',
      'horóscopo',
      'tamagotchi',
      'experimento',
      'experimentos',
    ],
  ),
  'de': _Words(
    {
      'Cane': '(Hund OR Welpe) (Haustier OR Tierarzt OR Halter) $_deExclusions',
      'Gatto': '(Katze OR Kater OR Kitten) (Haustier OR Tierarzt OR Halter) $_deExclusions',
      'Piccoli mammiferi':
          '(Kaninchen OR Meerschweinchen OR Hamster OR Frettchen) (Haustier OR Tierarzt OR Haltung) $_deExclusions -tierversuch -tierversuche',
      'Uccello': '(Vogel OR Papagei OR Wellensittich OR Kanarienvogel) (Haustier OR Käfig OR Tierarzt) $_deExclusions',
      'Rettili e anfibi':
          '(Reptil OR Amphibie OR Schildkröte OR Gecko OR Frosch) (Haustier OR Terrarium OR Tierarzt) $_deExclusions',
      'Pesce': '(Aquarium OR Aquaristik OR Goldfisch OR Zierfisch) $_deExclusions',
      'Altro': 'Haustiere $_deExclusions',
      'Generale': 'Haustiere (Gesetz OR Verordnung OR Messe OR Ausstellung) $_deExclusions',
    },
    [
      'rezept',
      'rezepte',
      'kochen',
      'braten',
      'eintopf',
      'backofen',
      'zutaten',
      'lecker',
      'jagd',
      'jäger',
      'horoskop',
      'tamagotchi',
      'tierversuch',
      'tierversuche',
    ],
  ),
  'fr': _Words(
    {
      'Cane': '(chien OR chiot) (animal OR vétérinaire OR propriétaire) $_frExclusions',
      'Gatto': '(chat OR chaton) (animal OR vétérinaire OR propriétaire) $_frExclusions',
      'Piccoli mammiferi':
          '(lapin OR cochon d\'inde OR hamster OR furet) (animal OR vétérinaire OR domestique) $_frExclusions -expérience -expérimentation',
      'Uccello': '(oiseau OR perroquet OR canari OR perruche) (animal OR cage OR vétérinaire) $_frExclusions',
      'Rettili e anfibi':
          '(reptile OR amphibien OR tortue OR gecko OR grenouille) (animal OR terrarium OR vétérinaire) $_frExclusions',
      'Pesce': '(aquarium OR aquariophilie OR "poisson rouge" OR "poisson tropical") $_frExclusions',
      'Altro': '"animaux de compagnie" $_frExclusions',
      'Generale': 'animaux de compagnie (loi OR réglementation OR salon OR exposition) $_frExclusions',
    },
    [
      'recette',
      'recettes',
      'cuisine',
      'cuisiner',
      'mijoté',
      'rôti',
      'au four',
      'ingrédients',
      'délicieux',
      'chasse',
      'chasseur',
      'horoscope',
      'tamagotchi',
      'expérience',
      'expérimentation',
    ],
  ),
};

// Function words per language: enough to tell the language of a headline.
// Deliberately short, common words that rarely appear in another language's
// headlines.
const _stopwords = <String, Set<String>>{
  'it': {'il', 'lo', 'la', 'gli', 'le', 'un', 'una', 'di', 'del', 'della', 'dei', 'che', 'per', 'con', 'nel', 'nella', 'sono', 'è', 'come', 'anche', 'più', 'dal', 'dalla', 'cani', 'gatti'},
  'en': {'the', 'of', 'and', 'to', 'in', 'is', 'for', 'with', 'on', 'your', 'how', 'why', 'are', 'from', 'that', 'this', 'it', 'at', 'by', 'as', 'new'},
  'es': {'el', 'los', 'las', 'del', 'de', 'y', 'en', 'un', 'una', 'por', 'con', 'para', 'que', 'su', 'se', 'es', 'como', 'más', 'sobre'},
  'de': {'der', 'die', 'das', 'und', 'ein', 'eine', 'für', 'mit', 'von', 'zu', 'im', 'ist', 'den', 'dem', 'auf', 'nicht', 'wie', 'wird', 'bei', 'auch'},
  'fr': {'le', 'les', 'des', 'du', 'de', 'et', 'un', 'une', 'pour', 'dans', 'sur', 'avec', 'que', 'qui', 'est', 'au', 'aux', 'par', 'sont', 'ses'},
};

/// False when [title] is clearly written in a language other than
/// [languageCode]: another language's function words outnumber the app
/// language's, and there are at least two of them. Short or ambiguous titles
/// pass - the aim is to keep out whole foreign-language headlines (an Italian
/// article in an English feed), not to judge borderline ones.
bool headlineMatchesLanguage(String title, String languageCode) {
  final words = RegExp(r"[\p{L}']+", unicode: true)
      .allMatches(title.toLowerCase())
      .map((match) => match.group(0)!)
      .toList();
  int hits(String language) => words.where((w) => _stopwords[language]?.contains(w) ?? false).length;

  final own = hits(languageCode);
  for (final language in _stopwords.keys) {
    if (language == languageCode) continue;
    final other = hits(language);
    if (other >= 2 && other > own) return false;
  }
  return true;
}
