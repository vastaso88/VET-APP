"""The Mercatino sells things FOR animals, never animals (owner decision
2026-10-26, every country, Italy included).

A listing's title and description are checked, in it/en/es/de/fr, for words
that offer, give away or swap an animal. The rule is a short pipeline of
regular expressions on whole words so the very same pipeline can run in three
places and give the same answer: here (the backend decides), in the app
(``animal_policy_patterns.dart``, for an immediate message) and in Postgres
(``scripts/setup/marketplace_no_animals.sql``, for listings written before the
rule). ``scripts/maintenance/gen_animal_policy.py`` writes the last two from
the lists below; a test fails when they are out of date.

The pipeline, on text normalised to lowercase ascii words separated by single
spaces:

1. Drop every animal word that is only the *target of an accessory*: it comes
   right after a preposition ("per", "for", "pour"...) or right after an
   accessory noun, with at most one word in between ("cuccia per cuccioli",
   "trasportino per gatto", "guinzaglio cane", "dog bed").
2. In what is left, block when an animal word has an offer word ("vendo",
   "sell", "verkaufe"...) or a qualifier ("disponibili", "for sale",
   "pedigree"...) within three words; or a young-animal word is followed by
   "di/de/of/von" ("cuccioli di labrador"); or a young-animal word stands
   alone in a text that names no accessory; or an adoption phrase appears
   ("in adozione", "good home"...).

It is deliberately strict about the verbs and the animal words and forgiving
about everything else: an accessory that merely names the animal it is for
("guinzaglio cane") must pass.
"""

from __future__ import annotations

import re

ANIMAL_POLICY_MESSAGE = "Sul Mercatino si vendono solo oggetti per animali, non animali."

# --- normalisation (the same map in Dart and, as translate(), in SQL) --------

ACCENT_FROM = "àáâäãåèéêëìíîïòóôöõùúûüñç"
ACCENT_TO = "aaaaaaeeeeiiiiooooouuuunc"
_TRANSLATION = str.maketrans(ACCENT_FROM, ACCENT_TO)


def normalize_text(text: str) -> str:
    lowered = text.lower().translate(_TRANSLATION)
    return re.sub(r"[^a-z0-9]+", " ", lowered).strip()


# --- word lists (normalised: no accents, lowercase) --------------------------

# Young animals: a listing that shows one with no accessory around is a sale.
YOUNG_TERMS = (
    # it
    "cucciolo cucciola cuccioli cucciole cucciolata cagnolino cagnolina cagnolini gattino gattina "
    "gattini gattine micetto micetti pulcino pulcini leprotto leprotti "
    # en
    "puppy puppies pup pups kitten kittens bunny bunnies foal foals "
    # es
    "cachorro cachorra cachorros cachorras gatito gatita gatitos gatitas camada potro potros "
    # de
    "welpe welpen hundewelpe hundewelpen katzenbaby katzenbabys katzenbabies kitze fohlen "
    "kaninchenbaby "
    # fr
    "chiot chiots chiotte chaton chatons portee poulain poulains lapereau lapereaux"
).split()

ADULT_TERMS = (
    # it
    "cane cani cagnolone gatto gatta gatti gatte micio coniglio coniglia conigli criceto criceti "
    "furetto furetti cavia cavie porcellino pappagallo pappagalli cocorita cocorite canarino "
    "canarini cardellino tartaruga tartarughe serpente serpenti geco rettile rettili iguana pitone "
    "cavallo cavalli cavalla pony pesce pesci pesciolino criceto cincilla chinchilla degu gerbillo "
    "gerbilli pettirosso inseparabili calopsite calopsita "
    # en
    "dog dogs doggy cat cats rabbit rabbits hamster hamsters ferret ferrets parrot parrots budgie "
    "budgies canary canaries tortoise tortoises turtle turtles snake snakes lizard lizards gecko "
    "horse horses stallion goldfish fish kitty "
    # es
    "perro perros perra perras perrito perritos gato gatos gata gatas conejo conejos coneja "
    "huron hurones cobaya cobayas loro loros periquito periquitos canario canarios tortuga "
    "tortugas serpiente serpientes caballo caballos yegua pez peces "
    # de
    "hund hunde hundin katze katzen kater kaninchen hase hasen hamster frettchen meerschweinchen "
    "papagei papageien wellensittich wellensittiche kanarienvogel schildkrote schildkroten "
    "schlange schlangen pferd pferde stute hengst fisch fische "
    # fr
    "chien chiens chienne chiennes chat chats chatte chattes lapin lapins lapine hamster hamsters "
    "furet furets cochon perroquet perroquets perruche perruches canari canaris tortue tortues "
    "serpent serpents cheval chevaux jument poisson poissons"
).split()

# Breeds: a name used on its own for an animal, rarely for an accessory.
BREED_TERMS = (
    "labrador golden retriever beagle chihuahua bulldog husky rottweiler carlino pug bassotto "
    "dachshund barboncino poodle maltese yorkshire spitz cocker spaniel collie dobermann "
    "schnauzer pomerania pinscher akita shiba samoyed malamute terrier bichon labradoodle "
    "lagotto setter pointer bracco maremmano weimaraner dalmata levriero whippet greyhound "
    "corgi mastino persiano siamese ragdoll sphynx bengala bengal munchkin chartreux certosino"
).split() + [
    "maine coon",
    "jack russell",
    "pastore tedesco",
    "cane corso",
    "british shorthair",
    "border collie",
    "bovaro del bernese",
    "shih tzu",
    "golden retriever",
]

# Words that make a text an accessory listing.
OBJECT_TERMS = (
    # it
    "guinzaglio guinzagli collare collari pettorina pettorine cuccia cucce cuccetta trasportino "
    "trasportini gabbia gabbie voliera voliere ciotola ciotole lettiera lettiere acquario "
    "acquari terrario cappotto cappottino cappottini impermeabile gioco giochi pallina palline "
    "osso ossa tiragraffi cesta cesto cestino lettino cuscino cuscini tappetino museruola "
    "spazzola spazzole shampoo crocchette croccantini cibo biscotti snack antipulci recinto "
    "recinti box scatola borsa zaino passeggino rampa scaletta casetta canile fontanella "
    "abbigliamento vestito vestitino maglione felpa mantella accessori accessorio mangiatoia "
    "abbeveratoio filtro pompa riscaldatore illuminazione fieno truciolo lettiere sellino "
    "sella bardatura museruole striscia tira medicinale integratore "
    # en
    "leash lead collar collars harness bed beds crate crates carrier carriers cage cages bowl "
    "bowls tank aquarium terrarium vivarium coat jacket jumper sweater raincoat toy toys ball "
    "bone scratcher scratching scratch cushion mat muzzle brush shampoo food treats kennel pen "
    "playpen bag backpack stroller ramp stairs house tree litter cover clothes clothing "
    "pad pads training accessories accessory feeder filter pump heater lamp hay saddle bridle "
    "blanket "
    # es
    "correa collar collares arnes cama camas transportin transportines jaula jaulas comedero "
    "bebedero arenero acuario abrigo juguete juguetes pelota hueso rascador cojin bozal "
    "cepillo champu comida pienso golosinas caseta parque bolso mochila cochecito rampa ropa "
    "accesorios accesorio filtro bomba calentador heno silla manta "
    # de
    "leine halsband halsbander geschirr korb bett hundebett katzenbett transportbox "
    "transporttasche kafig napf futternapf katzenklo streu aquarium terrarium mantel "
    "spielzeug knochen kratzbaum kissen maulkorb burste futter leckerli hutte gehege tasche "
    "rucksack kinderwagen rampe treppe kleidung zubehor pullover decke sattel fressnapf "
    "filter pumpe heizung heu "
    # fr
    "laisse collier colliers harnais panier paniers caisse cage cages gamelle litiere "
    "aquarium terrarium manteau imper jouet jouets balle os griffoir coussin muselière "
    "museliere brosse shampoing nourriture croquettes friandises niche enclos sac poussette "
    "rampe vetement vetements accessoires accessoire filtre pompe chauffage foin selle "
    "couverture"
).split()

# Prepositions that turn the next animal word into the target of an accessory.
PREPOSITIONS = (
    # it
    "per da di del della dei degli delle dal dalla senza al alla ai agli nel nella "
    # en (not "of": "litter of puppies" is an offer)
    "for without fits suits "
    # es
    "para por sin "
    # de
    "fur fuer ohne zum zur "
    # fr
    "pour sans au aux"
).split()

OFFER_TERMS = (
    # it
    "vendo vendesi vendiamo vendono cedo cedesi cediamo cedono regalo regalasi regaliamo "
    "offro scambio scambiasi adozione adotta adottare adottabile adottabili "
    # en
    "sell selling sale giveaway rehome rehoming adopt adoption "
    # es
    "vendemos vendo regalamos regalo cedemos adopcion adoptar adoptable "
    # de
    "verkaufe verkaufen verkauf abzugeben abgabe verschenke verschenken vermittle "
    "vermittlung abgeben "
    # fr
    "vends vendons vendre vente donne donnons donner cede cedons adoption adopter"
).split()

# Phrases that, next to an animal word, offer it.
QUALIFIERS = [
    # it
    "disponibile",
    "disponibili",
    "disponible",
    "in vendita",
    "in regalo",
    "con pedigree",
    "pedigree",
    "libretto sanitario",
    "figli di",
    "nati il",
    "nate il",
    "svezzati",
    "svezzate",
    "pronti alla consegna",
    "pronte alla consegna",
    "da adottare",
    "in adozione",
    "cerca casa",
    "cercano casa",
    "cerco casa",
    # en
    "available",
    "for sale",
    "for adoption",
    "to rehome",
    "kc registered",
    "ready to go",
    "good home",
    "free to a good home",
    "looking for a home",
    # es
    "disponibles",
    "en venta",
    "en adopcion",
    "en regalo",
    "con pedigri",
    "pedigri",
    "busca hogar",
    "buscan hogar",
    "listos para entregar",
    "buen hogar",
    # de
    "verfugbar",
    "zu verkaufen",
    "zu verschenken",
    "abzugeben",
    "stammbaum",
    "mit stammbaum",
    "sucht ein zuhause",
    "suchen ein zuhause",
    "gutes zuhause",
    # fr
    "a vendre",
    "a donner",
    "en adoption",
    "lof",
    "cherche famille",
    "cherchent famille",
    "bon foyer",
]

# These fire on their own, without an animal word next to them.
ADOPTION_PHRASES = [
    "in adozione",
    "cerco casa",
    "cerca casa",
    "cercano casa",
    "cherche famille",
    "cherchent famille",
    "for adoption",
    "good home",
    "free to a good home",
    "en adopcion",
    "busca hogar",
    "buen hogar",
    "zu verschenken tier",
    "gutes zuhause",
    "en adoption",
    "bon foyer",
    "a donner chiot",
    "a donner chaton",
]

# A young-animal word followed by one of these is "puppies of ...".
OF_WORDS = ["di", "de", "of", "von", "vom", "du", "d", "del", "della"]

ARTICLES = (
    "un uno una il lo la i gli le the a an el los las une les der die das den dem ein eine einen"
).split()

CONJUNCTIONS = "e ed o od and or y u und oder et ou".split()

WINDOW = 3  # words between an animal word and an offer word / qualifier
NEAR_WINDOW = 1  # the same, in a text that also names an accessory


def _alternation(words: list[str]) -> str:
    unique = sorted({w for w in words if w}, key=lambda w: (-len(w), w))
    return "|".join(unique)


def _animals() -> list[str]:
    return [*YOUNG_TERMS, *ADULT_TERMS, *BREED_TERMS]


def _build_patterns() -> dict[str, str]:
    """The regular expressions, with ``<B>``/``</B>`` where a word starts/ends.

    Python turns them into ``\\b``; Postgres into ``\\m``/``\\M``; Dart into
    ``\\b``.
    """
    animal = f"<B>(?:{_alternation(_animals())})</B>"
    young = f"<B>(?:{_alternation(YOUNG_TERMS)})</B>"
    obj = f"<B>(?:{_alternation(OBJECT_TERMS)})</B>"
    prep = f"<B>(?:{_alternation(PREPOSITIONS)})</B>"
    offer = f"<B>(?:{_alternation(OFFER_TERMS)})</B>"
    qualifier = f"<B>(?:{_alternation(QUALIFIERS)})</B>"
    adoption = f"<B>(?:{_alternation(ADOPTION_PHRASES)})</B>"
    of_words = f"<B>(?:{_alternation(OF_WORDS)})</B>"
    article = f"<B>(?:{_alternation(ARTICLES)})</B>"
    conj = f"<B>(?:{_alternation(CONJUNCTIONS)})</B>"
    gap = f"(?: [a-z0-9]+){{0,{WINDOW}}} "
    near = f"(?: [a-z0-9]+){{0,{NEAR_WINDOW}}} "
    return {
        # Step 1: an animal word that only names what an accessory is for
        # ("per gatto", "trasportino per un gatto", "dog bed", "guinzaglio cane").
        "object_target": (
            f"(?:{prep}(?: {article})? {animal}|{obj}(?: [a-z0-9]+)? {animal})"
            f"(?: {conj}(?: {article})? {animal})*"
            f"|{animal} {obj}"
        ),
        "animal_then_offer": f"{animal}{gap}(?:{offer}|{qualifier})",
        "offer_then_animal": f"(?:{offer}|{qualifier}){gap}{animal}",
        # In a text about an accessory the offer must sit right next to the
        # animal ("vendo cane"), not merely nearby ("vendo ... perché il cucciolo").
        "animal_then_offer_near": f"{animal}{near}(?:{offer}|{qualifier})",
        "offer_then_animal_near": f"(?:{offer}|{qualifier}){near}{animal}",
        "animal_adjacent_offer": (
            f"(?:{offer}|{qualifier}) {animal}|{animal} (?:{offer}|{qualifier})"
        ),
        "young_of": f"{young} {of_words} ",
        "young": young,
        "object": obj,
        "adoption": adoption,
    }


PATTERN_SOURCES = _build_patterns()


def _python_regex(source: str) -> re.Pattern[str]:
    return re.compile(source.replace("<B>", r"\b").replace("</B>", r"\b"))


_OBJECT_TARGET = _python_regex(PATTERN_SOURCES["object_target"])
_ANIMAL_THEN_OFFER = _python_regex(PATTERN_SOURCES["animal_then_offer"])
_OFFER_THEN_ANIMAL = _python_regex(PATTERN_SOURCES["offer_then_animal"])
_ANIMAL_ADJACENT_OFFER = _python_regex(PATTERN_SOURCES["animal_adjacent_offer"])
_ANIMAL_THEN_OFFER_NEAR = _python_regex(PATTERN_SOURCES["animal_then_offer_near"])
_OFFER_THEN_ANIMAL_NEAR = _python_regex(PATTERN_SOURCES["offer_then_animal_near"])
_YOUNG_OF = _python_regex(PATTERN_SOURCES["young_of"])
_YOUNG = _python_regex(PATTERN_SOURCES["young"])
_OBJECT = _python_regex(PATTERN_SOURCES["object"])
_ADOPTION = _python_regex(PATTERN_SOURCES["adoption"])


def offers_animals(*texts: str | None) -> bool:
    """True when the title and/or description offer, give away or swap an
    animal. Each text is judged on its own (a long description cannot hide a
    title and the other way round, and a word at the end of one never pairs
    with a word at the start of the next); only the lone-young-animal check
    ("Cuccioli" alone) looks at all of them together to know whether the ad
    is about an accessory."""
    present = [text for text in texts if text]
    about_accessory = bool(_OBJECT.search(normalize_text(" ".join(present)) + " "))
    return any(_offers_animals(text, about_accessory) for text in present)


def _offers_animals(text: str, about_accessory: bool) -> bool:
    # Pad with a space so that "... animale" at the end still has its gap.
    normalized = f"{normalize_text(text)} "
    if not normalized.strip():
        return False
    # Sentences are not split: the three-word window is the locality.
    left = _OBJECT_TARGET.sub(" ", f" {normalized}")
    left = re.sub(r" +", " ", left)

    if _ADOPTION.search(left):
        return True
    # A text that itself names an accessory must have the offer right next to
    # the animal; one that does not may have a few words in between.
    own_accessory = bool(_OBJECT.search(normalized))
    then_offer = _ANIMAL_THEN_OFFER_NEAR if own_accessory else _ANIMAL_THEN_OFFER
    offer_then = _OFFER_THEN_ANIMAL_NEAR if own_accessory else _OFFER_THEN_ANIMAL
    if _ANIMAL_ADJACENT_OFFER.search(left) or then_offer.search(left) or offer_then.search(left):
        return True
    if _YOUNG_OF.search(left):
        return True
    return bool(_YOUNG.search(left) and not about_accessory)
