"""Does a retrieved source actually concern the owner's question?

Found 2026-10-06 in the test round: "perché il mio cane mastica le scarpe?"
came back with three documents about arthritis, EEG and blood counts —
the retrievers select by clinical domain and species, not by topic — and
the chat presented them as the basis of its answer. A source that shares
no topic word with the question is not evidence for it.

The check is lexical and deliberately conservative: a source passes when
at least one content term of the question (or its English counterpart —
the literature is in English, the owner writes Italian) appears in the
source's title or snippet. Words that only say which animal it is do not
count: every dog paper mentions dogs.
"""

from __future__ import annotations

import re
import unicodedata

from packages.core.domain.knowledge.models import EvidenceSource

STEM_LENGTH = 5
MIN_WORD_LENGTH = 4

_WORD = re.compile(r"[a-z]+")

# Words with no topic in them (Italian and English), kept short.
_STOPWORDS = frozenset(
    """
    alla alle allo anche ancora avere bene cane cani casa come cosa così dalla dalle dallo
    deve devo dopo dove ecco essere fare fatto gatto gatti gli hanno molto nella nelle nello
    non oggi ogni perché perche poco posso può puo quale quali quando quanto quante quanti
    questa queste questo quello sempre senza sono stato stata sulla sulle sullo tanto tutti
    tutto vero volta volte ieri oggi domani giorno giorni settimana settimane mese mesi anno
    anni spesso sembra sembrano penso credo forse magari mio mia miei mie suo sua loro
    about after also animal animals been being between both canine cats dogs feline from
    have into more most other over review should some study such than that their there
    these this those under using what when where which while with would your companion
    small large guidelines guideline approach assessment problems common
    """.split()
)

# A species word is not a topic.
_SPECIES_WORDS = frozenset(
    """
    cane cani cagna cucciolo cuccioli gatto gatti gatta gattino coniglio conigli criceto
    cavia pappagallo pappagallini cocorita geco tartaruga pesce pesci uccello uccelli
    dog dogs puppy puppies cat cats kitten rabbit rabbits hamster bird birds parrot gecko
    reptile reptiles fish turtle tortoise canine feline
    """.split()
)

# Italian topic words -> English words used in the literature. Values are
# matched as stems too, so "chew" also covers "chewing".
_BRIDGE: dict[str, tuple[str, ...]] = {
    "mastic": ("chew", "destruct"),
    "morde": ("bite", "biting"),
    "morso": ("bite",),
    "abbaia": ("bark",),
    "ansia": ("anxiety", "separation"),
    "paura": ("fear", "phobia"),
    "aggress": ("aggress",),
    "comport": ("behav",),
    "gioc": ("play", "toy", "enrich"),
    "arricch": ("enrich",),
    "noia": ("boredom", "enrich"),
    "annoia": ("boredom", "enrich"),
    "gabbia": ("cage", "enclosure", "housing"),
    "voliera": ("aviary", "enclosure"),
    "terrario": ("terrarium", "enclosure", "vivarium"),
    "acquar": ("aquarium", "tank", "water"),
    "vasca": ("tank", "aquarium"),
    "filtro": ("filter", "filtration"),
    "acqua": ("water",),
    "lampad": ("lamp", "light", "uvb"),
    "luce": ("light", "photoperiod"),
    "sole": ("sun", "sunlight", "uvb", "light"),
    "finestr": ("window", "glass", "uvb"),
    "vetro": ("glass", "uvb"),
    "riscald": ("heat", "thermal", "temperature"),
    "temper": ("temperature", "thermal"),
    "umidit": ("humidity",),
    "substr": ("substrate",),
    "mangia": ("feed", "food", "diet", "nutrition", "appetite"),
    "aliment": ("feed", "food", "diet", "nutrition"),
    "dieta": ("diet", "nutrition"),
    "cibo": ("food", "diet"),
    "crocch": ("kibble", "diet", "food"),
    "peso": ("weight", "obesity", "body condition"),
    "grasso": ("obesity", "weight"),
    "vomit": ("vomit", "emesis"),
    "diarre": ("diarrh",),
    "feci": ("stool", "feces", "faeces", "fecal"),
    "tosse": ("cough",),
    "tossis": ("cough",),
    "respir": ("respirat", "breath", "dyspn"),
    "starnut": ("sneez", "rhinitis"),
    "prurit": ("prurit", "itch", "derm"),
    "gratta": ("prurit", "itch", "scratch", "derm"),
    "pelle": ("skin", "derm"),
    "pelo": ("coat", "hair", "alopecia", "derm"),
    "orecch": ("ear", "otitis"),
    "occhi": ("eye", "ocular", "ophthalm"),
    "denti": ("dental", "teeth", "tooth", "periodont"),
    "bocca": ("oral", "mouth", "dental"),
    "zoppic": ("lameness", "limp", "orthop"),
    "artic": ("joint", "arthritis", "orthop"),
    "artros": ("osteoarthritis", "arthritis"),
    "rene": ("kidney", "renal"),
    "renal": ("kidney", "renal"),
    "reni": ("kidney", "renal"),
    "urin": ("urin", "bladder", "cystitis"),
    "pipi": ("urin", "bladder"),
    "lettiera": ("litter", "elimination", "urin"),
    "fegato": ("liver", "hepat"),
    "cuore": ("heart", "cardiac"),
    "sangue": ("blood", "hemat", "haemat"),
    "febbre": ("fever", "pyrexia"),
    "dolore": ("pain", "analges"),
    "vaccin": ("vaccin", "immuniz"),
    "antipar": ("parasit", "flea", "tick", "deworm"),
    "pulci": ("flea",),
    "zecch": ("tick",),
    "vermi": ("worm", "parasit", "helminth"),
    "parass": ("parasit",),
    "steril": ("neuter", "spay", "steriliz"),
    "castr": ("neuter", "castrat"),
    "anzian": ("senior", "geriatric", "aging", "ageing", "old"),
    "cucciol": ("puppy", "kitten", "juvenile", "growth"),
    "gravid": ("pregnan", "gestation"),
    "sbadigl": ("yawn",),
    "sonno": ("sleep",),
    "dorme": ("sleep",),
    "tumore": ("tumor", "tumour", "neoplas", "cancer"),
    "nodulo": ("nodule", "mass", "tumor"),
    "convuls": ("seizure", "epilep"),
    "avvelen": ("toxic", "poison"),
    "cioccol": ("chocolate", "theobromine", "toxic"),
    "muta": ("shed", "ecdysis"),
    "calcio": ("calcium", "metabolic bone"),
    "ciecotrof": ("cecotroph", "caecotroph"),
    "fieno": ("hay", "fiber", "fibre"),
}


def _normalize(text: str) -> str:
    stripped = unicodedata.normalize("NFKD", text.lower())
    return "".join(ch for ch in stripped if not unicodedata.combining(ch))


def _stem(word: str) -> str:
    return word[:STEM_LENGTH]


def topic_terms(text: str) -> set[str]:
    """Stems of the content words of `text`, plus their English
    counterparts: what the text is about, species words excluded."""
    terms: set[str] = set()
    for word in _WORD.findall(_normalize(text)):
        if len(word) < MIN_WORD_LENGTH or word in _STOPWORDS or word in _SPECIES_WORDS:
            continue
        terms.add(_stem(word))
        for italian, english in _BRIDGE.items():
            if word.startswith(italian):
                terms.update(_stem(_normalize(e)) for e in english)
    return terms


def is_relevant(source: EvidenceSource, query_terms: set[str]) -> bool:
    """True when the source's title or snippet shares a topic word with the
    question. With no question terms at all nothing can be judged, and the
    source is kept (the caller's other filters still apply)."""
    if not query_terms:
        return True
    source_text = f"{source.title} {source.snippet or ''} {source.clinical_domain}"
    source_terms = {
        _stem(word)
        for word in _WORD.findall(_normalize(source_text))
        if len(word) >= MIN_WORD_LENGTH and word not in _STOPWORDS and word not in _SPECIES_WORDS
    }
    # Multi-word bridge targets ("metabolic bone") contribute their words.
    return bool(query_terms & source_terms)


def relevant_sources(sources: list[EvidenceSource], query: str) -> list[EvidenceSource]:
    terms = topic_terms(query)
    return [source for source in sources if is_relevant(source, terms)]
